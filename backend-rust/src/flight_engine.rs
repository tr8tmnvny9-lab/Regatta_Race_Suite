use crate::state::{Flight, FlightStatus, Pairing, Team};
use uuid::Uuid;

pub struct FlightEngine;

impl FlightEngine {
    /// Generates a fair rotation schedule for League racing.
    /// 
    /// Features:
    /// - Equitable distribution of opponents via cyclical rotation.
    /// - Boat retention optimization for back-to-back races.
    /// - Supports fractional races per flight (e.g. 16 teams / 6 boats = 3 races, with 4 teams in the last race).
    pub fn generate_rotation_schedule(
        teams: Vec<Team>,
        boat_count: u32,
        flight_count: u32,
    ) -> (Vec<Flight>, Vec<Pairing>) {
        let mut flights = Vec::new();
        let mut pairings = Vec::new();
        
        let num_teams = teams.len();
        if num_teams == 0 || boat_count == 0 || flight_count == 0 {
            return (flights, pairings);
        }
        
        // Calculate races per flight
        let races_per_flight = (num_teams as f64 / boat_count as f64).ceil() as u32;
        
        // 1. Generate core rotation
        for f in 0..flight_count {
            let flight_id = Uuid::new_v4().to_string();
            let flight = Flight {
                id: flight_id.clone(),
                flight_number: f + 1,
                group_label: format!("Flight {}", f + 1),
                status: FlightStatus::Scheduled,
            };
            flights.push(flight);
            
            // Cyclical rotation offset to mix opponents effectively
            let shift = (f as usize * 7) % num_teams;
            
            // Linear assignment: Every team in the rotated list gets exactly one slot in this flight
            let boat_shift = (f as u32) % boat_count;
            for i in 0..num_teams {
                let r = (i as u32) / boat_count;
                let b = ((i as u32) + boat_shift) % boat_count;
                
                let team_idx = (i + shift) % num_teams;
                let team = &teams[team_idx];
                
                pairings.push(Pairing {
                    id: Uuid::new_v4().to_string(),
                    flight_id: flight_id.clone(),
                    team_id: team.id.clone(),
                    boat_id: (b + 1).to_string(),
                    race_index: r,
                });
            }
        }
        
        // 2. Post-process: Boat Retention Optimization
        // Logic: If a team finishes the last race of flight N and starts the first race of flight N+1,
        // we swap their boat assignment in flight N+1 to match flight N.
        if flight_count > 1 {
            for f in 0..(flight_count - 1) {
                let current_flight_id = &flights[f as usize].id;
                let next_flight_id = &flights[(f + 1) as usize].id;
                
                // Max race index in current flight
                let max_race_idx = pairings.iter()
                    .filter(|p| &p.flight_id == current_flight_id)
                    .map(|p| p.race_index)
                    .max()
                    .unwrap_or(0);
                
                // Teams in the final race of current flight
                let finishers: Vec<_> = pairings.iter()
                    .filter(|p| &p.flight_id == current_flight_id && p.race_index == max_race_idx)
                    .cloned()
                    .collect();
                
                // Pairings for the first race of the next flight
                let mut next_race0_indices: Vec<usize> = pairings.iter()
                    .enumerate()
                    .filter(|(_, p)| &p.flight_id == next_flight_id && p.race_index == 0)
                    .map(|(i, _)| i)
                    .collect();
                
                for next_idx in next_race0_indices.clone() {
                    let team_id = &pairings[next_idx].team_id.clone();
                    
                    if let Some(prev_p) = finishers.iter().find(|p| &p.team_id == team_id) {
                        let target_boat_id = &prev_p.boat_id;
                        let current_boat_id = &pairings[next_idx].boat_id.clone();
                        
                        if target_boat_id != current_boat_id {
                            // Find the pairing in the same race (f+1, r0) that currently has the target_boat_id
                            if let Some(swap_with_idx) = pairings.iter().position(|p| {
                                &p.flight_id == next_flight_id && 
                                p.race_index == 0 && 
                                &p.boat_id == target_boat_id
                            }) {
                                // Swap Boat IDs
                                let temp_boat = pairings[next_idx].boat_id.clone();
                                pairings[next_idx].boat_id = pairings[swap_with_idx].boat_id.clone();
                                pairings[swap_with_idx].boat_id = temp_boat;
                            }
                        }
                    }
                }
            }
        }
        
        (flights, pairings)
    }
}
