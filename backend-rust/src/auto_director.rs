use std::time::Duration;
use socketioxide::SocketIo;
use tokio::time::interval;
use tracing::info;
use serde_json::json;

use crate::handlers::SharedState;

pub async fn start_auto_director(shared: SharedState, io: SocketIo) {
    let mut ticker = interval(Duration::from_secs(2)); // Evaluate every 2 seconds
    
    info!("🎬 SRS Auto-Director started.");
    
    loop {
        ticker.tick().await;
        
        // 1. Snapshot the current fleet telemetry
        let state = shared.read().await;
        let mut boats: Vec<(String, f64)> = Vec::new(); // (BoatId, Score)
        
        for (boat_id, telemetry) in &state.boats {
            let mut score = 0.0;
            
            // Heuristic 1: Speed (faster = more exciting = higher score)
            score += telemetry.velocity.speed * 2.0;
            
            // Heuristic 2: Proximity to Mark / Startline (Lower DTL = higher score)
            // If they are within 50 meters (5000 cm) of a mark, aggressively boost score
            let dtl = telemetry.dtl;
            if dtl < 5000.0 && dtl > 0.0 {
                score += (5000.0 - dtl) / 100.0; 
            }
            
            // Tie-breaking jitter
            score += boat_id.len() as f64 * 0.01;
            
            boats.push((boat_id.clone(), score));
        }
        
        drop(state);
        
        if boats.is_empty() {
            continue;
        }
        
        // 2. Rank & Select Top 4
        // Sort descending by score
        boats.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        
        let focus_limit = 4;
        let top_boats: Vec<String> = boats.into_iter()
            .take(focus_limit)
            .map(|(id, _)| id)
            .collect();
            
        // 3. Emit the target list via WebSockets
        let payload = json!({
            "focus_boats": top_boats,
            "timestamp": std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()
        });
        
        // Broadcast to all connected clients (React Media Suite & iOS Trackers)
        io.emit("focus_boats_changed", &payload).ok();
    }
}
