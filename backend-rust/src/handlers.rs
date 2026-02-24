use std::collections::HashSet;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};
use socketioxide::extract::{Data, SocketRef};
use tokio::sync::RwLock;
use tracing::{info, warn};

use crate::persistence::save_state;
use crate::procedure_engine::ProcedureEngine;
use crate::state::{
    BoatState, ImuData, LatLon, LogCategory, LogEntry, Penalty, PrepFlag, ProcedureGraph,
    RaceState, RaceStatus, SequenceInfo, VelocityData,
};

// ─── Shared State Types ───────────────────────────────────────────────────────

pub type SharedState = Arc<RwLock<RaceState>>;
pub type SharedEngine = Arc<RwLock<ProcedureEngine>>;
pub type DeadBoats = Arc<RwLock<HashSet<String>>>;

// ─── Helper: get unix ms ─────────────────────────────────────────────────────

pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

pub async fn emit_log(
    shared: &SharedState,
    socket: &SocketRef,
    category: LogCategory,
    source: String,
    message: String,
    data: Option<Value>,
    is_active: bool,
) {
    let log = LogEntry {
        id: format!("log-{}", now_ms()),
        timestamp: now_ms(),
        category,
        source,
        message,
        data,
        is_active,
    };

    {
        let mut state = shared.write().await;
        state.logs.push(log.clone());
        // Keep logs at a reasonable size
        if state.logs.len() > 100 {
            state.logs.remove(0);
        }
    }

    let _ = socket.broadcast().emit("new-log", &log);
    let _ = socket.emit("new-log", &log);
}

// ─── Built-in Standard Procedure Graph ───────────────────────────────────────

pub fn standard_procedure(minutes: u64, prep_flag: &str) -> ProcedureGraph {
    use crate::state::{ProcedureEdge, ProcedureNode, ProcedureNodeData};

    let (warn_dur, prep_dur, one_min_dur) = if minutes == 3 {
        (60.0, 60.0, 60.0)
    } else {
        (60.0, 180.0, 60.0) // 5-minute RRS 26
    };

    let nodes = vec![
        ProcedureNode {
            id: "0".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Idle".into(),
                flags: vec![],
                duration: 0.0,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
        ProcedureNode {
            id: "1".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Warning Signal".into(),
                flags: vec!["CLASS".into()],
                duration: warn_dur,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
        ProcedureNode {
            id: "2".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Preparatory Signal".into(),
                flags: vec!["CLASS".into(), prep_flag.to_string()],
                duration: prep_dur,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
        ProcedureNode {
            id: "3".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "One-Minute".into(),
                flags: vec!["CLASS".into()],
                duration: one_min_dur,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
        ProcedureNode {
            id: "4".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Start".into(),
                flags: vec![],
                duration: 0.0,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
        ProcedureNode {
            id: "5".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Racing".into(),
                flags: vec![],
                duration: 3600.0,
                sound: None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
            },
        },
    ];

    let edges = vec![
        ProcedureEdge { id: "e0-1".into(), source: "0".into(), target: "1".into(), animated: Some(true) },
        ProcedureEdge { id: "e1-2".into(), source: "1".into(), target: "2".into(), animated: Some(true) },
        ProcedureEdge { id: "e2-3".into(), source: "2".into(), target: "3".into(), animated: Some(true) },
        ProcedureEdge { id: "e3-4".into(), source: "3".into(), target: "4".into(), animated: Some(true) },
        ProcedureEdge { id: "e4-5".into(), source: "4".into(), target: "5".into(), animated: Some(true) },
    ];

    ProcedureGraph {
        id: format!("standard-{minutes}min"),
        nodes,
        edges,
    }
}

// ─── Main Connection Handler ──────────────────────────────────────────────────

pub async fn on_connect(
    socket: SocketRef,
    shared: SharedState,
    engine: SharedEngine,
    dead_boats: DeadBoats,
) {
    let socket_id = socket.id.to_string();
    info!("Client connected: {socket_id}");

    // ── register ──────────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("register", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let client_type = data["type"].as_str().unwrap_or("unknown");
                info!("Client {}: registered as {client_type}", s.id);

                let _ = s.join(client_type.to_string());

                let state = shared.read().await;
                let _ = s.emit("init-state", &*state);
            }
        });
    }

    // ── track-update ──────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let dead_boats = dead_boats.clone();
        socket.on("track-update", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let dead_boats = dead_boats.clone();
            async move {
                let boat_id = match data["boatId"].as_str() {
                    Some(id) => id.to_string(),
                    None => return,
                };

                // Check blacklist
                if dead_boats.read().await.contains(&boat_id) {
                    let _ = s.emit("kill-simulation", &json!({ "id": boat_id }));
                    return;
                }

                let pos = LatLon {
                    lat: data["pos"]["lat"].as_f64().unwrap_or(0.0),
                    lon: data["pos"]["lon"].as_f64().unwrap_or(0.0),
                };
                let imu = ImuData {
                    heading: data["imu"]["heading"].as_f64().unwrap_or(0.0),
                    roll: data["imu"]["roll"].as_f64(),
                    pitch: data["imu"]["pitch"].as_f64(),
                };
                let velocity = VelocityData {
                    speed: data["velocity"]["speed"].as_f64().unwrap_or(0.0),
                    dir: data["velocity"]["dir"].as_f64(),
                };
                let dtl = data["dtl"].as_f64().unwrap_or(0.0);
                let timestamp = data["timestamp"].as_i64().unwrap_or_else(now_ms);

                // Simulation data (optional, only sent if it's a simulation update or high-fidelity sync)
                let sim_path = data["simulationPath"].as_array().map(|arr| {
                    arr.iter().filter_map(|v| {
                        Some(LatLon {
                            lat: v["lat"].as_f64()?,
                            lon: v["lon"].as_f64()?,
                        })
                    }).collect::<Vec<LatLon>>()
                });

                let is_simulating = data["isSimulating"].as_bool();
                let speed_setting = data["speedSetting"].as_f64();
                let path_progress = data["pathProgress"].as_f64();

                {
                    let mut state = shared.write().await;
                    if let Some(existing) = state.boats.get_mut(&boat_id) {
                        existing.pos = pos;
                        existing.imu = imu;
                        existing.velocity = velocity;
                        existing.dtl = dtl;
                        existing.timestamp = timestamp;
                        
                        if let Some(path) = sim_path { existing.simulation_path = path; }
                        if let Some(sim) = is_simulating { existing.is_simulating = sim; }
                        if let Some(speed) = speed_setting { existing.speed_setting = speed; }
                        if let Some(prog) = path_progress { existing.path_progress = prog; }
                    } else {
                        // Create new boat if doesn't exist
                        let boat = BoatState {
                            boat_id: boat_id.clone(),
                            pos,
                            imu,
                            velocity,
                            dtl,
                            timestamp,
                            simulation_path: sim_path.unwrap_or_default(),
                            is_simulating: is_simulating.unwrap_or(false),
                            speed_setting: speed_setting.unwrap_or(8.0),
                            path_progress: path_progress.unwrap_or(0.0),
                        };
                        state.boats.insert(boat_id.clone(), boat);
                    }
                }

                let state = shared.read().await;
                if let Some(boat) = state.boats.get(&boat_id) {
                    let _ = s.broadcast().emit("boat-update", &boat);
                    let _ = s.broadcast().emit("media-boat-update", &boat);
                    let _ = s.to("media").emit("media-boat-update", &boat);
                }
            }
        });
    }

    // ── update-tracker-simulation ─────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-tracker-simulation", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let boat_id = match data["boatId"].as_str() {
                    Some(id) => id.to_string(),
                    None => return,
                };

                let sim_path = data["simulationPath"].as_array().map(|arr| {
                    arr.iter().filter_map(|v| {
                        Some(LatLon {
                            lat: v["lat"].as_f64()?,
                            lon: v["lon"].as_f64()?,
                        })
                    }).collect::<Vec<LatLon>>()
                }).unwrap_or_default();

                let is_simulating = data["isSimulating"].as_bool().unwrap_or(false);
                let speed_setting = data["speedSetting"].as_f64().unwrap_or(8.0);
                let path_progress = data["pathProgress"].as_f64().unwrap_or(0.0);

                {
                    let mut state = shared.write().await;
                    if let Some(boat) = state.boats.get_mut(&boat_id) {
                        let sim_started = !boat.is_simulating && is_simulating;
                        let sim_stopped = boat.is_simulating && !is_simulating;

                        boat.simulation_path = sim_path;
                        boat.is_simulating = is_simulating;
                        boat.speed_setting = speed_setting;
                        boat.path_progress = path_progress;
                        
                        let _ = s.broadcast().emit("boat-update", &*boat);
                        let _ = s.emit("boat-update", &*boat);

                        // Global Log
                        drop(state);
                        if sim_started {
                            emit_log(
                                &shared,
                                &s,
                                LogCategory::Boat,
                                boat_id.clone(),
                                "Simulation started".to_string(),
                                Some(json!({ "speed": speed_setting })),
                                true,
                            ).await;
                        } else if sim_stopped {
                            emit_log(
                                &shared,
                                &s,
                                LogCategory::Boat,
                                boat_id.clone(),
                                "Simulation stopped".to_string(),
                                None,
                                false,
                            ).await;
                        }
                    }
                }
            }
        });
    }

    // ── start-sequence ────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        socket.on("start-sequence", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            async move {
                let prep_flag_str = data["prepFlag"].as_str().unwrap_or("P");

                let mut eng = engine.write().await;
                
                // Keep the deployed graph if present, otherwise load standard
                let graph = if let Some(g) = &eng.graph {
                    g.clone()
                } else {
                    let minutes = data["minutes"].as_u64().unwrap_or(5);
                    let g = standard_procedure(minutes, prep_flag_str);
                    eng.load_procedure(g.clone());
                    g
                };

                let update = eng.start();
                drop(eng);

                {
                    let mut state = shared.write().await;
                    state.status = RaceStatus::PreStart;
                    state.current_procedure = Some(graph);
                    state.prep_flag = match prep_flag_str {
                        "I" => PrepFlag::I,
                        "Z" => PrepFlag::Z,
                        "U" => PrepFlag::U,
                        "BLACK" => PrepFlag::Black,
                        _ => PrepFlag::P,
                    };
                    if let Some(upd) = &update {
                        state.current_sequence = Some(upd.current_sequence.clone());
                        state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                    }
                }

                if let Some(upd) = update {
                    let _ = s.broadcast().emit("sequence-update", &upd);
                    let _ = s.emit("sequence-update", &upd);
                }

                let state = shared.read().await;
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);

                emit_log(
                    &shared,
                    &s,
                    LogCategory::Procedure,
                    "Director".to_string(),
                    "Started 5-Minute Sequence".to_string(),
                    None,
                    false,
                ).await;
            }
        });
    }

    // ── set-prep-flag ─────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("set-prep-flag", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let flag_str = data["flag"].as_str().unwrap_or("P");
                let mut state = shared.write().await;
                state.prep_flag = match flag_str {
                    "I" => PrepFlag::I,
                    "Z" => PrepFlag::Z,
                    "U" => PrepFlag::U,
                    "BLACK" => PrepFlag::Black,
                    _ => PrepFlag::P,
                };
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);
            }
        });
    }

    // ── procedure-action ──────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        socket.on("procedure-action", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            async move {
                let action = data["action"].as_str().unwrap_or("");
                info!("Procedure action: {action}");

                let (new_status, seq_event, seq_flags): (RaceStatus, &str, Vec<&str>) = match action {
                    "POSTPONE" => (RaceStatus::Postponed, "Postpone", vec!["AP"]),
                    "INDIVIDUAL_RECALL" => (RaceStatus::Recall, "Individual Recall", vec!["X"]),
                    "GENERAL_RECALL" => (RaceStatus::Recall, "General Recall", vec!["FIRST_SUB"]),
                    "ABANDON" => (RaceStatus::Abandoned, "Abandon", vec!["N"]),
                    _ => {
                        warn!("Unknown procedure action: {action}");
                        return;
                    }
                };

                // Stop the engine
                engine.write().await.stop();

                {
                    let mut state = shared.write().await;
                    state.status = new_status;
                    state.current_sequence = Some(SequenceInfo {
                        event: seq_event.to_string(),
                        flags: seq_flags.iter().map(|f| f.to_string()).collect(),
                    });
                    state.sequence_time_remaining = None;

                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                }

                // Global Log
                emit_log(
                    &shared,
                    &s,
                    LogCategory::Procedure,
                    "Director".to_string(),
                    format!("Manual Procedure Action: {action}"),
                    None,
                    false,
                ).await;
            }
        });
    }

    // ── save-procedure ────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        socket.on("save-procedure", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            async move {
                match serde_json::from_value::<ProcedureGraph>(data) {
                    Ok(graph) => {
                        let mut eng = engine.write().await;
                        eng.load_procedure(graph.clone());
                        let update = eng.start();
                        drop(eng);

                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::PreStart;
                            state.current_procedure = Some(graph);
                            if let Some(upd) = &update {
                                state.current_sequence = Some(upd.current_sequence.clone());
                                state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                            }
                            let _ = save_state(&state).await;
                        }

                        if let Some(upd) = update {
                            let _ = s.broadcast().emit("sequence-update", &upd);
                            let _ = s.emit("sequence-update", &upd);
                        }
                        let state = shared.read().await;
                        let _ = s.broadcast().emit("state-update", &*state);
                        let _ = s.emit("state-update", &*state);

                        // Global Log
                        emit_log(
                            &shared,
                            &s,
                            LogCategory::Procedure,
                            "Architect".to_string(),
                            "Custom procedure deployed and started".to_string(),
                            None,
                            false,
                        ).await;
                    }
                    Err(e) => warn!("Failed to parse procedure: {e}"),
                }
            }
        });
    }

    // ── trigger-node ──────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        socket.on("trigger-node", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            async move {
                if let Some(node_id) = data["nodeId"].as_str() {
                    let update = engine.write().await.jump_to_node(node_id);
                    if let Some(upd) = update {
                        let mut state = shared.write().await;
                        state.current_sequence = Some(upd.current_sequence.clone());
                        state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                        let _ = s.broadcast().emit("sequence-update", &upd);
                        let _ = s.emit("sequence-update", &upd);

                        // Global Log
                        emit_log(
                            &shared,
                            &s,
                            LogCategory::Procedure,
                            "Director".to_string(),
                            format!("Triggered procedure node: {node_id}"),
                            None,
                            false,
                        ).await;
                    }
                }
            }
        });
    }

    // ── resume-sequence ───────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        socket.on("resume-sequence", move |s: SocketRef, Data::<Value>(_data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            async move {
                let update = engine.write().await.resume_sequence();
                if let Some(upd) = update {
                    let mut state = shared.write().await;
                    state.current_sequence = Some(upd.current_sequence.clone());
                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                    let _ = s.broadcast().emit("sequence-update", &upd);
                    let _ = s.emit("sequence-update", &upd);

                    // Global Log
                    emit_log(
                        &shared,
                        &s,
                        LogCategory::Procedure,
                        "Director".to_string(),
                        "Resumed sequence manually".to_string(),
                        None,
                        false,
                    ).await;
                }
            }
        });
    }

    // ── update-course ─────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-course", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                match serde_json::from_value(data) {
                    Ok(course) => {
                        let mut state = shared.write().await;
                        state.course = course;
                        let _ = save_state(&state).await;
                        let _ = s.broadcast().emit("course-updated", &state.course);
                        let _ = s.emit("course-updated", &state.course);

                        // Global Log
                        drop(state);
                        emit_log(
                            &shared,
                            &s,
                            LogCategory::Course,
                            "Director".to_string(),
                            "Course layout updated".to_string(),
                            None,
                            false,
                        ).await;
                    }
                    Err(e) => error!("Failed to parse course payload from frontend! Error: {e} | Raw Data: {}", data),
                }
            }
        });
    }

    // ── update-course-boundary ────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-course-boundary", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(boundary) = serde_json::from_value::<Vec<LatLon>>(data) {
                    let mut state = shared.write().await;
                    state.course.course_boundary = Some(boundary);
                    let _ = save_state(&state).await;
                    let _ = s.broadcast().emit("course-updated", &state.course);
                    let _ = s.emit("course-updated", &state.course);

                    // Global Log
                    drop(state);
                    emit_log(
                        &shared,
                        &s, // Use the local socket reference s
                        LogCategory::Course,
                        "Director".to_string(),
                        "Course boundary redefined".to_string(),
                        None,
                        false,
                    ).await;
                } else {
                    error!("Failed to parse course boundary from frontend! Raw Data: {}", data);
                }
            }
        });
    }

    // ── update-wind ───────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-wind", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                match serde_json::from_value(data) {
                    Ok(wind) => {
                        let mut state = shared.write().await;
                        state.wind = wind;
                        let _ = save_state(&state).await;
                        let _ = s.broadcast().emit("wind-updated", &state.wind);
                        let _ = s.emit("wind-updated", &state.wind);
                    }
                    Err(e) => error!("Failed to parse wind payload from frontend! Error: {e} | Raw Data: {}", data),
                }
            }
        });
    }

    // ── update-default-location ───────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-default-location", move |_s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                match serde_json::from_value(data) {
                    Ok(loc) => {
                        let mut state = shared.write().await;
                        state.default_location = Some(loc);
                        let _ = save_state(&state).await;
                        info!("Default location saved");
                    }
                    Err(e) => error!("Failed to parse location payload from frontend! Error: {e} | Raw Data: {}", data),
                }
            }
        });
    }

    // ── set-race-status ───────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("set-race-status", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Some(status_str) = data["status"].as_str() {
                    let new_status = match status_str {
                        "PRE_START" => RaceStatus::PreStart,
                        "RACING" => RaceStatus::Racing,
                        "FINISHED" => RaceStatus::Finished,
                        "POSTPONED" => RaceStatus::Postponed,
                        "RECALL" => RaceStatus::Recall,
                        "ABANDONED" => RaceStatus::Abandoned,
                        _ => RaceStatus::Idle,
                    };
                    let mut state = shared.write().await;
                    state.status = new_status;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                }
            }
        });
    }

    // ── issue-penalty ─────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("issue-penalty", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let penalty = Penalty {
                    boat_id: data["boatId"].as_str().unwrap_or("").to_string(),
                    penalty_type: data["type"].as_str().unwrap_or("UNKNOWN").to_string(),
                    timestamp: data["timestamp"].as_i64().unwrap_or_else(now_ms),
                };
                info!("Penalty: {:?} on {}", penalty.penalty_type, penalty.boat_id);
                {
                    let mut state = shared.write().await;
                    state.penalties.push(penalty.clone());
                }
                let _ = s.broadcast().emit("penalty-issued", &penalty);
                let _ = s.emit("penalty-issued", &penalty);

                // Global Log
                emit_log(
                    &shared,
                    &s,
                    LogCategory::Jury,
                    "Chief Umpire".to_string(),
                    format!("Penalty Issued: {} on {}", penalty.penalty_type, penalty.boat_id),
                    Some(json!({ "boatId": penalty.boat_id, "type": penalty.penalty_type })),
                    false,
                ).await;
            }
        });
    }

    // ── kill-tracker ──────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let dead_boats = dead_boats.clone();
        socket.on("kill-tracker", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let dead_boats = dead_boats.clone();
            async move {
                let id = match data.as_str() {
                    Some(id) => id.to_string(),
                    None => match data["id"].as_str() {
                        Some(id) => id.to_string(),
                        None => return,
                    },
                };
                info!("Killing tracker: {id}");

                dead_boats.write().await.insert(id.clone());

                {
                    let mut state = shared.write().await;
                    state.boats.remove(&id);
                }

                let _ = s.broadcast().emit("kill-simulation", &json!({ "id": id }));
                let _ = s.emit("kill-simulation", &json!({ "id": id }));

                let state = shared.read().await;
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);

                // Auto-expire blacklist entry after 30s
                let dead_boats_clone = dead_boats.clone();
                let id_clone = id.clone();
                tokio::spawn(async move {
                    tokio::time::sleep(Duration::from_secs(30)).await;
                    dead_boats_clone.write().await.remove(&id_clone);
                });
            }
        });
    }

    // ── clear-fleet ───────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("clear-fleet", move |s: SocketRef, Data::<Value>(_data)| {
            let shared = shared.clone();
            async move {
                info!("Clearing all fleet trackers");
                {
                    let mut state = shared.write().await;
                    state.boats.clear();
                    let _ = save_state(&state).await;
                }
                let _ = s.broadcast().emit("kill-simulation", &json!({ "id": "all" }));
                let _ = s.emit("kill-simulation", &json!({ "id": "all" }));

                let state = shared.read().await;
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);
            }
        });
    }

    // ── signal (WebRTC relay) ─────────────────────────────────────────────────
    {
        let socket = socket.clone();
        socket.on("signal", move |s: SocketRef, Data::<Value>(data)| {
            async move {
                // Relay signal to target socket (pass-through)
                let _ = s.broadcast().emit("signal", &data);
            }
        });
    }

    info!("All handlers registered for socket {socket_id}");
}
