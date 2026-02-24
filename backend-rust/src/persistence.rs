use anyhow::Result;
use std::path::Path;
use tokio::fs;
use tracing::{info, warn};

use crate::state::RaceState;

const STATE_FILE: &str = "state.json";

/// Load persisted state from disk. Returns default if file missing or corrupt.
pub async fn load_state() -> RaceState {
    if !Path::new(STATE_FILE).exists() {
        info!("No state.json found, using default state");
        return RaceState::default();
    }

    match fs::read_to_string(STATE_FILE).await {
        Ok(data) => match serde_json::from_str::<RaceState>(&data) {
            Ok(mut state) => {
                // Reset ephemeral runtime fields on load
                state.boats.clear();
                state.status = crate::state::RaceStatus::Idle;
                state.current_sequence = None;
                state.sequence_time_remaining = None;
                state.start_time = None;
                info!("Loaded state from disk (course: {} marks, wind: {}kn {}°)",
                    state.course.marks.len(),
                    state.wind.speed,
                    state.wind.direction
                );
                state
            }
            Err(e) => {
                warn!("Failed to parse state.json: {e}, using default state");
                RaceState::default()
            }
        },
        Err(e) => {
            warn!("Failed to read state.json: {e}, using default state");
            RaceState::default()
        }
    }
}

/// Save the persistent parts of state to disk. Strips ephemeral fields.
pub async fn save_state(state: &RaceState) -> Result<()> {
    // Build a saveable copy — omit ephemeral boat telemetry
    let save = RaceState {
        status: crate::state::RaceStatus::Idle,
        current_sequence: None,
        sequence_time_remaining: None,
        start_time: None,
        boats: std::collections::HashMap::new(),
        penalties: Vec::new(),
        ..state.clone()
    };

    let json = serde_json::to_string_pretty(&save)?;
    fs::write(STATE_FILE, json).await?;
    Ok(())
}
