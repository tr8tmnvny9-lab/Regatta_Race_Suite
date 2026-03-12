use socketioxide::SocketIo;
use std::time::Duration;
use tokio::time::interval;
use tracing::{debug, info, warn};
use serde_json::json;

use crate::handlers::SharedState;
use crate::state::{BoatState, CourseElement, CourseElementType, LatLon};

// Earth radius in meters
const R: f64 = 6371000.0;

/// Haversine distance between two points in meters
pub fn haversine_distance(p1: &LatLon, p2: &LatLon) -> f64 {
    let d_lat = (p2.lat - p1.lat).to_radians();
    let d_lon = (p2.lon - p1.lon).to_radians();
    
    let lat1 = p1.lat.to_radians();
    let lat2 = p2.lat.to_radians();
    
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.cos() * lat2.cos() * (d_lon / 2.0).sin().powi(2);
        
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    R * c
}

/// Bearing from p1 to p2 in degrees (0 = North, 90 = East)
pub fn bearing(p1: &LatLon, p2: &LatLon) -> f64 {
    let lat1 = p1.lat.to_radians();
    let lat2 = p2.lat.to_radians();
    let d_lon = (p2.lon - p1.lon).to_radians();
    
    let y = d_lon.sin() * lat2.cos();
    let x = lat1.cos() * lat2.sin() - lat1.sin() * lat2.cos() * d_lon.cos();
    
    let brng = y.atan2(x).to_degrees();
    (brng + 360.0) % 360.0
}

/// Helper: find centroid of a list of marks (useful for gates/lines)
fn get_centroid(mark_ids: &[String], state: &crate::state::RaceState) -> Option<LatLon> {
    if mark_ids.is_empty() { return None; }
    let mut sum_lat = 0.0;
    let mut sum_lon = 0.0;
    let mut count = 0;
    
    for id in mark_ids {
        if let Some(mark) = state.course.marks.iter().find(|m| m.id == *id) {
            sum_lat += mark.pos.lat;
            sum_lon += mark.pos.lon;
            count += 1;
        }
    }
    
    if count == 0 { return None; }
    Some(LatLon {
        lat: sum_lat / count as f64,
        lon: sum_lon / count as f64,
    })
}

// Check if line segment A-B intersects C-D.
// Used for detecting when a boat (A=prev, B=curr) crosses a line/gate (C, D).
fn segments_intersect(a: &LatLon, b: &LatLon, c: &LatLon, d: &LatLon) -> bool {
    let ccw = |p1: &LatLon, p2: &LatLon, p3: &LatLon| {
        (p3.lat - p1.lat) * (p2.lon - p1.lon) > (p2.lat - p1.lat) * (p3.lon - p1.lon)
    };
    ccw(a, c, d) != ccw(b, c, d) && ccw(a, b, c) != ccw(a, b, d)
}

/// The main ranking algorithm
pub async fn start_ranking_engine(shared: SharedState, io: SocketIo) {
    let mut ticker = interval(Duration::from_millis(1000)); // Update once per second
    info!("🏆 Ranking Engine started (1Hz DTF / DMG loop).");
    
    loop {
        ticker.tick().await;
        
        // Block to read the state
        let mut state = shared.write().await;
        
        let course_order = match &state.active_course_order {
            Some(order) if !order.is_empty() => order.clone(),
            _ => {
                // No active course order, skipping evaluation.
                continue;
            }
        };
        
        let twd = state.wind.direction;
        
        // Re-calculate the pre-computed leg distances.
        // For N elements, there are N-1 legs.
        // leg_distances[i] = length of leg i (from element i to i+1).
        let n_elements = course_order.len();
        let mut element_centroids = Vec::with_capacity(n_elements);
        for el in &course_order {
            element_centroids.push(get_centroid(&el.marks, &state));
        }
        
        let mut rhumb_distances = vec![0.0; n_elements.saturating_sub(1)];
        let mut total_course_length = 0.0;
        
        for i in 0..n_elements.saturating_sub(1) {
            if let (Some(c1), Some(c2)) = (&element_centroids[i], &element_centroids[i+1]) {
                let d = haversine_distance(c1, c2);
                rhumb_distances[i] = d;
                total_course_length += d;
            }
        }
        
        // Create an array to collect scores for ranking
        let mut fleet_scores = Vec::new();
        
        // Evaluate each boat
        for (boat_id, boat) in state.boats.iter_mut() {
            // 1. Advance Leg if they crossed the next mark/element
            let current_leg = boat.leg_index as usize;
            
            // Check if they advanced (passed element current_leg + 1)
            let mut just_advanced = false;
            if current_leg + 1 < n_elements {
                let target_element = &course_order[current_leg + 1];
                let is_passed = match target_element.element_type {
                    CourseElementType::StartLine | CourseElementType::FinishLine | CourseElementType::Gate => {
                        // Check segment intersection
                        if target_element.marks.len() >= 2 {
                            // We need the boat's previous position to do a segment intersect. 
                            // We will approximate passing by simply checking if they are within a radius and moving away, 
                            // Alternatively, if they have simulation_path, use the last 2 points.
                            // For now, simple proximity check for the gate center.
                            if let Some(c) = &element_centroids[current_leg + 1] {
                                if haversine_distance(&boat.pos, c) < 20.0 {
                                    just_advanced = true;
                                }
                            }
                        }
                    },
                    CourseElementType::Mark => {
                        // Simple proximity check for roundings (e.g. within 15 meters)
                        if let Some(c) = &element_centroids[current_leg + 1] {
                            if haversine_distance(&boat.pos, c) < 15.0 {
                                just_advanced = true;
                            }
                        }
                    }
                };
                
                if just_advanced {
                    boat.leg_index += 1;
                }
            }
            
            let current_leg = boat.leg_index as usize;
            let mut dtf = 0.0;
            
            if current_leg >= n_elements - 1 {
                // Finished!
                dtf = 0.0;
            } else if let (Some(start_c), Some(end_c)) = (&element_centroids[current_leg], &element_centroids[current_leg + 1]) {
                // Calculate Distance Made Good (DMG) for the current leg
                let leg_bearing = bearing(start_c, end_c);
                let boat_to_mark_dist = haversine_distance(&boat.pos, end_c);
                
                // Determine if this is an upwind/downwind leg or reaching leg.
                // We compare the leg_bearing to the wind direction.
                let mut wind_diff = (leg_bearing - twd).abs();
                if wind_diff > 180.0 { wind_diff = 360.0 - wind_diff; }
                
                let is_upwind_downwind = wind_diff <= 45.0 || wind_diff >= 135.0;
                
                if is_upwind_downwind {
                    // Orthogonal projection onto the wind axis (TWD).
                    // We calculate the difference in position along the wind vector from the mark to the boat.
                    // Effectively: Distance * cos(angle_between_boat_to_mark_and_wind)
                    let boat_bearing = bearing(end_c, &boat.pos);
                    let mut angle = (boat_bearing - twd).abs();
                    if angle > 180.0 { angle = 360.0 - angle; }
                    
                    // If upwind, we project onto TWD. If downwind, we project onto TWD+180.
                    // Simplest approach: Use the cosine of the angle to the wind axis.
                    if wind_diff >= 135.0 {
                        // Upwind
                        dtf += boat_to_mark_dist * angle.to_radians().cos().abs();
                    } else {
                        // Downwind
                        dtf += boat_to_mark_dist * angle.to_radians().cos().abs();
                    }
                } else {
                    // Orthogonal projection onto the rhumb line (reaching)
                    let boat_to_mark_bearing = bearing(&boat.pos, end_c);
                    let mut angle = (boat_to_mark_bearing - leg_bearing).abs();
                    if angle > 180.0 { angle = 360.0 - angle; }
                    
                    dtf += boat_to_mark_dist * angle.to_radians().cos().abs();
                }
                
                // Add the absolute distances of all remaining legs
                for i in (current_leg + 1)..rhumb_distances.len() {
                    dtf += rhumb_distances[i];
                }
            } else {
                dtf = 99999.0;
            }
            
            boat.dtf_m = dtf;
            
            fleet_scores.push((boat_id.clone(), boat.leg_index, boat.dtf_m));
        }
        
        // Rank the fleet
        // Primary sort: highest leg_index first (descending)
        // Secondary sort: smallest dtf_m first (ascending)
        fleet_scores.sort_unstable_by(|a, b| {
            b.1.cmp(&a.1).then_with(|| a.2.partial_cmp(&b.2).unwrap_or(std::cmp::Ordering::Equal))
        });
        
        let mut telemetry_update_map = serde_json::Map::new();
        
        for (i, (boat_id, _, _)) in fleet_scores.iter().enumerate() {
            let rank = (i + 1) as u32;
            if let Some(boat) = state.boats.get_mut(boat_id) {
                boat.rank = rank;
                
                // Construct the broadcast object
                let payload = json!({
                    "lat": boat.pos.lat,
                    "lng": boat.pos.lon,
                    "speedKnots": boat.velocity.speed,
                    "course": boat.imu.heading,
                    "rank": boat.rank,
                    "dtf_m": boat.dtf_m,
                    "leg_index": boat.leg_index,
                });
                telemetry_update_map.insert(boat_id.clone(), payload);
            }
        }
        
        // Emitting the update here as a consolidated payload. 
        // This is sent down to the clients.
        if !telemetry_update_map.is_empty() {
            io.emit("telemetry-update", &telemetry_update_map).ok();
            io.emit("leaderboard-update", &telemetry_update_map).ok();
        }
    }
}
