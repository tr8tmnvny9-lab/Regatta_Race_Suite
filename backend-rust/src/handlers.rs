use std::collections::HashSet;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};
use socketioxide::extract::{Data, SocketRef};
use tokio::sync::RwLock;
use tracing::{info, warn, error};

use crate::persistence::save_state;
use crate::procedure_engine::ProcedureEngine;
use crate::state::{
    BoatState, CourseState, DefaultLocation, ImuData, LatLon, LogCategory, LogEntry,
    Penalty, PenaltyType, PrepFlag, ProcedureGraph, RaceState, RaceStatus,
    SequenceInfo, SoundSignal, VelocityData, WindState,
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
        protest_flagged: None,
        jury_notes: None,
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

// ─── Built-in Standard Procedure Graphs (RRS 26 compliant) ──────────────────

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
                sound: SoundSignal::None,
                sound_on_remove: SoundSignal::None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("IDLE".into()),
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
                sound: SoundSignal::OneShort,           // 1 sound at flag raise
                sound_on_remove: SoundSignal::None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("WARNING".into()),
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
                sound: SoundSignal::OneShort,           // 1 sound at prep flag raise
                sound_on_remove: SoundSignal::OneLong,  // 1 long sound when prep flag removed
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("PREPARATORY".into()),
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
                sound: SoundSignal::OneLong,            // 1 long sound (prep flag down)
                sound_on_remove: SoundSignal::None,
                wait_for_user_trigger: false,
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("ONE_MINUTE".into()),
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
                sound: SoundSignal::OneShort,            // 1 sound (start gun)
                sound_on_remove: SoundSignal::None,
                wait_for_user_trigger: false,             // Auto-transition to Racing
                action_label: None,
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("RACING".into()),
            },
        },
        ProcedureNode {
            id: "5".into(),
            node_type: "state".into(),
            position: None,
            data: ProcedureNodeData {
                label: "Racing".into(),
                flags: vec![],
                duration: 0.0,
                sound: SoundSignal::None,
                sound_on_remove: SoundSignal::None,
                wait_for_user_trigger: true,
                action_label: Some("FINISH RACE — End racing".into()),
                post_trigger_duration: 0.0,
                post_trigger_flags: vec![],
                race_status: Some("RACING".into()),
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
        auto_restart: false,
    }
}

// ─── Main Connection Handler ──────────────────────────────────────────────────

pub async fn on_connect(
    socket: SocketRef,
    shared: SharedState,
    engine: SharedEngine,
    dead_boats: DeadBoats,
    auth: std::sync::Arc<crate::auth::AuthEngine>,
) {
    let socket_id = socket.id.to_string();
    info!("Client connected: {socket_id}");
    
    // Cleanup on disconnect
    socket.on_disconnect({
        let auth = auth.clone();
        let sid = socket_id.clone();
        move |_: SocketRef| async move {
            auth.remove_role(&sid).await;
            info!("Client disconnected, roles cleaned: {sid}");
        }
    });

    // ── register ──────────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let auth = auth.clone();
        socket.on("register", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let auth = auth.clone();
            async move {
                let token = data["type"].as_str().unwrap_or("unknown");
                
                let mut client_type = "unknown".to_string();
                
                // 1) First attempt cryptographically secure Supabase JWT validation
                if let Some(claims) = crate::auth::AuthEngine::verify_supabase_token(token) {
                    client_type = claims.role.unwrap_or_else(|| {
                        // Fallback: check app_metadata for custom roles
                        if let Some(app_meta) = &claims.app_metadata {
                            if let Some(r) = app_meta.get("role").and_then(|v| v.as_str()) {
                                return r.to_string();
                            }
                        }
                        // Default authenticated users form Supabase to "tracker"
                        "tracker".to_string()
                    });
                } else {
                    // 2) Fallback to insecure legacy/mock tokens for the web dashboard transition window
                    client_type = match token {
                        "director123" => "director".to_string(),
                        "jury123" => "jury".to_string(),
                        "media123" => "media".to_string(),
                        "tracker123" => "tracker".to_string(),
                        "director" => "director".to_string(),
                        "jury" => "jury".to_string(),
                        "media" => "media".to_string(),
                        "tracker" => "tracker".to_string(),
                        _ => "unknown".to_string(),
                    };
                }

                if client_type == "unknown" {
                    warn!("Client {}: rejected, invalid or unknown authentication token", s.id);
                    let _ = s.disconnect();
                    return;
                }

                auth.set_role(&s.id.to_string(), &client_type).await;
                info!("Client {}: registered and authenticated securely as Role: {}", s.id, client_type);

                let _ = s.join(client_type.to_string());

                let state = shared.read().await;
                let _ = s.emit("init-state", &*state);
            }
        });
    }

    // ── latency-ping ──────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        socket.on("latency-ping", move |s: SocketRef, Data::<Value>(data)| {
            async move {
                let _ = s.emit("latency-pong", &data);
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

                // Simulation data
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
                    
                    let hist = state.fleet_history.entry(boat_id.clone()).or_insert_with(Vec::new);
                    if hist.is_empty() || timestamp - hist.last().unwrap().timestamp > 5000 {
                        hist.push(crate::state::HistoricalPing {
                            timestamp,
                            lat: pos.lat,
                            lon: pos.lon,
                        });
                        if hist.len() > 360 {
                            hist.remove(0);
                        }
                    }

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

                        drop(state);
                        if sim_started {
                            emit_log(&shared, &s, LogCategory::Boat, boat_id.clone(), "Simulation started".to_string(), Some(json!({ "speed": speed_setting })), true).await;
                        } else if sim_stopped {
                            emit_log(&shared, &s, LogCategory::Boat, boat_id.clone(), "Simulation stopped".to_string(), None, false).await;
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
        let auth = auth.clone();
        socket.on("start-sequence", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized starting sequence attempt by: {}", s.id);
                    return;
                }
                
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
                let status = eng.current_race_status();
                drop(eng);

                {
                    let mut state = shared.write().await;
                    state.status = status;
                    state.current_procedure = Some(graph);
                    state.ocs_boats.clear();
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

                emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(), "Started sequence".to_string(), None, false).await;
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
                // Accept both bare string ("P") and object ({ flag: "P" })
                let flag_str = data.as_str()
                    .or_else(|| data["flag"].as_str())
                    .unwrap_or("P");
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

    // ── procedure-action (RRS Race Management) ────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        let auth = auth.clone();
        socket.on("procedure-action", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized procedure action attempt by: {}", s.id);
                    return;
                }
                
                let action = data["action"].as_str().unwrap_or("");
                info!("Procedure action: {action}");

                match action {
                    // ── POSTPONE (AP flag + 2 sounds) ─────────────────────
                    "POSTPONE" => {
                        engine.write().await.stop();
                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::Postponed;
                            state.current_sequence = Some(SequenceInfo {
                                event: "Postponed".to_string(),
                                flags: vec!["AP".to_string()],
                            });
                            state.sequence_time_remaining = None;
                            state.waiting_for_trigger = false;
                            state.action_label = None;

                            let _ = s.broadcast().emit("state-update", &*state);
                            let _ = s.emit("state-update", &*state);
                        }

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "Race postponed — AP flag raised, 2 sounds".to_string(),
                            Some(json!({ "signal": "AP", "sounds": 2 })), false).await;

                        // Auto-resume: spawn a task that waits 60s then starts new Warning
                        let shared_r = shared.clone();
                        let engine_r = engine.clone();
                        let s_r = s.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(Duration::from_secs(60)).await;
                            
                            // Only resume if still postponed (RC may have manually changed)
                            let is_still_postponed = shared_r.read().await.status == RaceStatus::Postponed;
                            if !is_still_postponed { return; }

                            info!("AP lowered — resuming with new Warning in 1 min");
                            
                            // Restart the engine
                            let mut eng = engine_r.write().await;
                            let update = eng.start();
                            let status = eng.current_race_status();
                            drop(eng);

                            {
                                let mut state = shared_r.write().await;
                                state.status = status;
                                if let Some(upd) = &update {
                                    state.current_sequence = Some(upd.current_sequence.clone());
                                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                                }
                            }

                            if let Some(upd) = update {
                                let _ = s_r.broadcast().emit("sequence-update", &upd);
                                let _ = s_r.emit("sequence-update", &upd);
                            }

                            let state = shared_r.read().await;
                            let _ = s_r.broadcast().emit("state-update", &*state);
                            let _ = s_r.emit("state-update", &*state);

                            emit_log(&shared_r, &s_r, LogCategory::Procedure, "Director".to_string(),
                                "AP lowered — new Warning signal, 1 sound".to_string(),
                                Some(json!({ "signal": "AP_DOWN", "sounds": 1 })), false).await;
                        });
                    }

                    // ── INDIVIDUAL RECALL (X flag + 1 sound) ──────────────
                    "INDIVIDUAL_RECALL" => {
                        // Don't stop the engine — racing continues
                        let ocs_boats: Vec<String> = data["boats"].as_array()
                            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
                            .unwrap_or_default();
                        
                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::IndividualRecall;
                            state.ocs_boats = ocs_boats.clone();
                            state.current_sequence = Some(SequenceInfo {
                                event: "Individual Recall".to_string(),
                                flags: vec!["X".to_string()],
                            });

                            let _ = s.broadcast().emit("state-update", &*state);
                            let _ = s.emit("state-update", &*state);
                        }

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            format!("Individual Recall — X flag raised, OCS: {}", if ocs_boats.is_empty() { "none identified".to_string() } else { ocs_boats.join(", ") }),
                            Some(json!({ "signal": "X", "sounds": 1, "ocsBoats": ocs_boats })), false).await;

                        // Auto-clear X flag after 5 minutes (DNS default)
                        let shared_r = shared.clone();
                        let s_r = s.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(Duration::from_secs(300)).await; // 5 min
                            
                            let is_still_recall = shared_r.read().await.status == RaceStatus::IndividualRecall;
                            if !is_still_recall { return; }

                            info!("X flag auto-lowered after 5 minutes");
                            {
                                let mut state = shared_r.write().await;
                                state.status = RaceStatus::Racing;
                                state.current_sequence = Some(SequenceInfo {
                                    event: "Racing".to_string(),
                                    flags: vec![],
                                });

                                // Issue DNS to OCS boats
                                let ocs_list = state.ocs_boats.clone();
                                for boat_id in &ocs_list {
                                    state.penalties.push(Penalty {
                                        boat_id: boat_id.clone(),
                                        penalty_type: PenaltyType::Dns,
                                        timestamp: now_ms(),
                                    });
                                }
                                state.ocs_boats.clear();

                                let _ = s_r.broadcast().emit("state-update", &*state);
                                let _ = s_r.emit("state-update", &*state);
                            }

                            emit_log(&shared_r, &s_r, LogCategory::Procedure, "Director".to_string(),
                                "X flag lowered — DNS applied to OCS boats".to_string(), None, false).await;
                        });
                    }

                    // ── GENERAL RECALL (1st Substitute + 2 sounds) ────────
                    "GENERAL_RECALL" => {
                        engine.write().await.stop();
                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::GeneralRecall;
                            state.current_sequence = Some(SequenceInfo {
                                event: "General Recall".to_string(),
                                flags: vec!["FIRST_SUB".to_string()],
                            });
                            state.sequence_time_remaining = None;
                            state.waiting_for_trigger = false;
                            state.action_label = None;

                            let _ = s.broadcast().emit("state-update", &*state);
                            let _ = s.emit("state-update", &*state);
                        }

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "General Recall — 1st Substitute raised, 2 sounds".to_string(),
                            Some(json!({ "signal": "FIRST_SUB", "sounds": 2 })), false).await;

                        // Auto: 1st Sub down + 1 sound, new Warning 1 min later
                        let shared_r = shared.clone();
                        let engine_r = engine.clone();
                        let s_r = s.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(Duration::from_secs(60)).await;

                            let is_still_recall = shared_r.read().await.status == RaceStatus::GeneralRecall;
                            if !is_still_recall { return; }

                            info!("1st Substitute lowered — new Warning sequence starting");

                            let mut eng = engine_r.write().await;
                            let update = eng.start();
                            let status = eng.current_race_status();
                            drop(eng);

                            {
                                let mut state = shared_r.write().await;
                                state.status = status;
                                if let Some(upd) = &update {
                                    state.current_sequence = Some(upd.current_sequence.clone());
                                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                                }
                            }

                            if let Some(upd) = update {
                                let _ = s_r.broadcast().emit("sequence-update", &upd);
                                let _ = s_r.emit("sequence-update", &upd);
                            }

                            let state = shared_r.read().await;
                            let _ = s_r.broadcast().emit("state-update", &*state);
                            let _ = s_r.emit("state-update", &*state);

                            emit_log(&shared_r, &s_r, LogCategory::Procedure, "Director".to_string(),
                                "1st Substitute lowered — new Warning signal, 1 sound".to_string(),
                                Some(json!({ "signal": "FIRST_SUB_DOWN", "sounds": 1 })), false).await;
                        });
                    }

                    // ── ABANDON (N flag + 3 sounds) ───────────────────────
                    "ABANDON" => {
                        engine.write().await.stop();
                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::Abandoned;
                            state.current_sequence = Some(SequenceInfo {
                                event: "Abandoned".to_string(),
                                flags: vec!["N".to_string()],
                            });
                            state.sequence_time_remaining = None;
                            state.waiting_for_trigger = false;
                            state.action_label = None;
                            state.ocs_boats.clear();

                            let _ = s.broadcast().emit("state-update", &*state);
                            let _ = s.emit("state-update", &*state);
                        }

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "Race abandoned — N flag raised, 3 sounds".to_string(),
                            Some(json!({ "signal": "N", "sounds": 3 })), false).await;
                    }

                    // ── SHORTEN COURSE (S flag + 2 sounds) ────────────────
                    "SHORTEN_COURSE" => {
                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "Shorten Course — S flag raised, 2 sounds".to_string(),
                            Some(json!({ "signal": "S", "sounds": 2 })), false).await;
                    }

                    // ── COURSE CHANGE (C flag + repetitive sounds) ────────
                    "COURSE_CHANGE" => {
                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "Course Change — C flag raised, repetitive sounds".to_string(),
                            Some(json!({ "signal": "C", "sounds": "repetitive" })), false).await;
                    }

                    // ── RESET TO IDLE ──────────────────────────────────────
                    "RESET" => {
                        engine.write().await.stop();
                        {
                            let mut state = shared.write().await;
                            state.status = RaceStatus::Idle;
                            state.current_sequence = None;
                            state.sequence_time_remaining = None;
                            state.start_time = None;
                            state.waiting_for_trigger = false;
                            state.action_label = None;
                            state.is_post_trigger = false;
                            state.ocs_boats.clear();

                            let _ = s.broadcast().emit("state-update", &*state);
                            let _ = s.emit("state-update", &*state);
                        }

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            "Race reset to Idle".to_string(), None, false).await;
                    }

                    _ => {
                        warn!("Unknown procedure action: {action}");
                    }
                }
            }
        });
    }

    // ── save-procedure ────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        let auth = auth.clone();
        socket.on("save-procedure", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized save-procedure attempt by: {}", s.id);
                    return;
                }
                
                match serde_json::from_value::<ProcedureGraph>(data) {
                    Ok(graph) => {
                        let mut eng = engine.write().await;
                        eng.load_procedure(graph.clone());
                        let update = eng.start();
                        let status = eng.current_race_status();
                        drop(eng);

                        {
                            let mut state = shared.write().await;
                            state.status = status;
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

                        emit_log(&shared, &s, LogCategory::Procedure, "Architect".to_string(),
                            "Custom procedure deployed and started".to_string(), None, false).await;
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
        let auth = auth.clone();
        socket.on("trigger-node", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized node trigger attempt by: {}", s.id);
                    return;
                }
                
                if let Some(node_id) = data["nodeId"].as_str() {
                    let update = engine.write().await.jump_to_node(node_id);
                    if let Some(upd) = update {
                        let mut state = shared.write().await;
                        state.current_sequence = Some(upd.current_sequence.clone());
                        state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                        let _ = s.broadcast().emit("sequence-update", &upd);
                        let _ = s.emit("sequence-update", &upd);

                        emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                            format!("Triggered procedure node: {node_id}"), None, false).await;
                    }
                }
            }
        });
    }

    // ── mutate-future-node ───────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        let auth = auth.clone();
        socket.on("mutate-future-node", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized mutate-future-node attempt by: {}", s.id);
                    return;
                }
                
                let node_id = match data["nodeId"].as_str() {
                    Some(id) => id,
                    None => return,
                };
                let new_duration = match data["duration"].as_f64() {
                    Some(d) => d,
                    None => return,
                };

                let mut eng = engine.write().await;
                eng.update_node_duration(node_id, new_duration);
                let update = eng.build_update();
                let graph = eng.graph.clone();
                drop(eng);

                {
                    let mut state = shared.write().await;
                    if let Some(g) = graph {
                        state.current_procedure = Some(g);
                    }
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
            }
        });
    }

    // ── resume-sequence ───────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let engine = engine.clone();
        let auth = auth.clone();
        socket.on("resume-sequence", move |s: SocketRef, Data::<Value>(_data)| {
            let shared = shared.clone();
            let engine = engine.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized sequence resume attempt by: {}", s.id);
                    return;
                }
                
                let mut eng = engine.write().await;
                let update = eng.resume_sequence();
                let status = eng.current_race_status();
                drop(eng);

                if let Some(upd) = update {
                    let mut state = shared.write().await;
                    state.status = status;
                    state.current_sequence = Some(upd.current_sequence.clone());
                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                    let _ = s.broadcast().emit("sequence-update", &upd);
                    let _ = s.emit("sequence-update", &upd);

                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);

                    emit_log(&shared, &s, LogCategory::Procedure, "Director".to_string(),
                        "Resumed sequence manually".to_string(), None, false).await;
                }
            }
        });
    }

    // ── update-course ─────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let auth = auth.clone();
        socket.on("update-course", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized course update attempt by: {}", s.id);
                    return;
                }
                
                match serde_json::from_value::<CourseState>(data.clone()) {
                    Ok(course) => {
                        let mut state = shared.write().await;
                        state.course = course;
                        let _ = save_state(&state).await;
                        let _ = s.broadcast().emit("course-updated", &state.course);
                        let _ = s.emit("course-updated", &state.course);

                        drop(state);
                        emit_log(&shared, &s, LogCategory::Course, "Director".to_string(),
                            "Course layout updated".to_string(), None, false).await;
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
        let auth = auth.clone();
        socket.on("update-course-boundary", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let auth = auth.clone();
            async move {
                if auth.get_role(&s.id.to_string()).await.as_deref() != Some("director") {
                    warn!("Unauthorized boundary update attempt by: {}", s.id);
                    return;
                }
                
                if data.is_null() {
                    let mut state = shared.write().await;
                    state.course.course_boundary = None;
                    let _ = save_state(&state).await;
                    let _ = s.broadcast().emit("course-updated", &state.course);
                    let _ = s.emit("course-updated", &state.course);

                    drop(state);
                    emit_log(&shared, &s, LogCategory::Course, "Director".to_string(),
                        "Course boundary cleared".to_string(), None, false).await;
                } else if let Ok(boundary) = serde_json::from_value::<Vec<LatLon>>(data.clone()) {
                    let mut state = shared.write().await;
                    state.course.course_boundary = Some(boundary);
                    let _ = save_state(&state).await;
                    let _ = s.broadcast().emit("course-updated", &state.course);
                    let _ = s.emit("course-updated", &state.course);

                    drop(state);
                    emit_log(&shared, &s, LogCategory::Course, "Director".to_string(),
                        "Course boundary redefined".to_string(), None, false).await;
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
                match serde_json::from_value::<WindState>(data.clone()) {
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
                match serde_json::from_value::<DefaultLocation>(data.clone()) {
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
                        "WARNING" => RaceStatus::Warning,
                        "PREPARATORY" => RaceStatus::Preparatory,
                        "ONE_MINUTE" => RaceStatus::OneMinute,
                        "RACING" => RaceStatus::Racing,
                        "FINISHED" => RaceStatus::Finished,
                        "POSTPONED" => RaceStatus::Postponed,
                        "INDIVIDUAL_RECALL" => RaceStatus::IndividualRecall,
                        "GENERAL_RECALL" => RaceStatus::GeneralRecall,
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

    // ── issue-penalty (RRS + Appendix UF umpire signals) ──────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("issue-penalty", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let boat_id = data["boatId"].as_str().unwrap_or("").to_string();
                let penalty_type_str = data["type"].as_str().unwrap_or("UMPIRE_PENALTY");
                let penalty_type = match penalty_type_str {
                    "OCS" => PenaltyType::Ocs,
                    "DSQ" => PenaltyType::Dsq,
                    "DNF" => PenaltyType::Dnf,
                    "DNS" => PenaltyType::Dns,
                    "TLE" => PenaltyType::Tle,
                    "TURN_360" => PenaltyType::Turn360,
                    "UMPIRE_NO_ACTION" => PenaltyType::UmpireNoAction,
                    "UMPIRE_DSQ" => PenaltyType::UmpireDsq,
                    _ => PenaltyType::UmpirePenalty,
                };

                let penalty = Penalty {
                    boat_id: boat_id.clone(),
                    penalty_type: penalty_type.clone(),
                    timestamp: data["timestamp"].as_i64().unwrap_or_else(now_ms),
                };
                info!("Penalty: {:?} on {}", penalty.penalty_type, penalty.boat_id);

                // Determine umpire signal flags + sounds
                let (signal, flag, sounds) = match &penalty.penalty_type {
                    PenaltyType::UmpireNoAction => ("Umpire: No penalty", "GREEN_WHITE", "1 long"),
                    PenaltyType::UmpirePenalty | PenaltyType::Turn360 => ("Umpire: Penalty imposed", "RED", "1 long"),
                    PenaltyType::UmpireDsq => ("Umpire: DSQ — leave course", "BLACK_UMPIRE", "1 long"),
                    _ => ("Penalty", "", ""),
                };

                {
                    let mut state = shared.write().await;
                    state.penalties.push(penalty.clone());
                }
                let _ = s.broadcast().emit("penalty-issued", &penalty);
                let _ = s.emit("penalty-issued", &penalty);

                emit_log(&shared, &s, LogCategory::Jury, "Chief Umpire".to_string(),
                    format!("{}: {} on {}", signal, penalty_type_str, boat_id),
                    Some(json!({ "boatId": boat_id, "type": penalty_type_str, "flag": flag, "sounds": sounds })),
                    false).await;
            }
        });
    }

    // ── update-log (Jury/Director Annotations) ────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-log", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(updated_log) = serde_json::from_value::<crate::state::LogEntry>(data) {
                    let mut state = shared.write().await;
                    if let Some(log) = state.logs.iter_mut().find(|l| l.id == updated_log.id) {
                        log.protest_flagged = updated_log.protest_flagged;
                        log.jury_notes = updated_log.jury_notes.clone();
                        info!("Log {} updated with Protest/Notes", log.id);
                        
                        let _ = s.broadcast().emit("log-updated", &log);
                        let _ = s.emit("log-updated", &log);
                    }
                }
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

    // ── register-team ─────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("register-team", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(team) = serde_json::from_value::<crate::state::Team>(data.clone()) {
                    {
                        let mut state = shared.write().await;
                        state.teams.insert(team.id.clone(), team);
                        let _ = save_state(&state).await;
                    }
                    let state = shared.read().await;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                } else {
                    warn!("Failed to parse register-team payload: {}", data);
                }
            }
        });
    }

    // ── delete-team ───────────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("delete-team", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Some(team_id) = data.as_str() {
                    {
                        let mut state = shared.write().await;
                        state.teams.remove(team_id);
                        // Also remove pairings for that team
                        state.pairings.retain(|p| p.team_id != team_id);
                        let _ = save_state(&state).await;
                    }
                    let state = shared.read().await;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                }
            }
        });
    }

    // ── register-flight ───────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("register-flight", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(flight) = serde_json::from_value::<crate::state::Flight>(data.clone()) {
                    {
                        let mut state = shared.write().await;
                        state.flights.insert(flight.id.clone(), flight);
                        let _ = save_state(&state).await;
                    }
                    let state = shared.read().await;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                } else {
                    warn!("Failed to parse register-flight payload: {}", data);
                }
            }
        });
    }

    // ── update-pairings ───────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-pairings", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(pairings) = serde_json::from_value::<Vec<crate::state::Pairing>>(data.clone()) {
                    {
                        let mut state = shared.write().await;
                        state.pairings = pairings;
                        let _ = save_state(&state).await;
                    }
                    let state = shared.read().await;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                } else {
                    warn!("Failed to parse update-pairings payload: {}", data);
                }
            }
        });
    }

    // ── set-active-flight ─────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        let auth = auth.clone();
        socket.on("set-active-flight", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            let auth = auth.clone();
            async move {
                // No strict role check — any authenticated director can set the active flight
                // Accept both bare string (flight id) and null/empty (to clear)
                let flight_id = if data.is_null() || data.as_str().map(|s| s.is_empty()).unwrap_or(false) {
                    None
                } else {
                    data.as_str().map(|s| s.to_string())
                };
                
                {
                    let mut state = shared.write().await;
                    state.active_flight_id = flight_id;
                    let _ = save_state(&state).await;
                }
                
                let state = shared.read().await;
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);
            }
        });
    }

    // ── generate-flights ──────────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("generate-flights", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                let target_races = data["targetRaces"].as_u64().unwrap_or(15) as u32;
                let boats = data["boats"].as_u64().unwrap_or(6) as u32;
                
                let (flights, pairings) = {
                    let state = shared.read().await;
                    let teams: Vec<crate::state::Team> = state.teams.values().cloned().collect();
                    crate::flight_engine::FlightEngine::generate_rotation_schedule(teams, boats, target_races)
                };
                
                if flights.is_empty() {
                    warn!("Flight generation aborted: Not enough teams or boats (0 flights).");
                    return;
                }
                
                {
                    let mut state = shared.write().await;
                    
                    // Atomically replace the existing schedule
                    state.flights.clear();
                    state.pairings.clear();
                    
                    for f in flights {
                        state.flights.insert(f.id.clone(), f);
                    }
                    state.pairings = pairings;
                    
                    let _ = save_state(&state).await;
                }
                
                let state = shared.read().await;
                let _ = s.broadcast().emit("state-update", &*state);
                let _ = s.emit("state-update", &*state);
                
                info!("Generated new fair rotation schedule spanning {} flights.", state.flights.len());
            }
        });
    }

    // ── update-fleet-settings ─────────────────────────────────────────────────
    {
        let socket = socket.clone();
        let shared = shared.clone();
        socket.on("update-fleet-settings", move |s: SocketRef, Data::<Value>(data)| {
            let shared = shared.clone();
            async move {
                if let Ok(settings) = serde_json::from_value::<crate::state::FleetSettings>(data.clone()) {
                    {
                        let mut state = shared.write().await;
                        state.fleet_settings = Some(settings);
                        let _ = save_state(&state).await;
                    }
                    let state = shared.read().await;
                    let _ = s.broadcast().emit("state-update", &*state);
                    let _ = s.emit("state-update", &*state);
                } else {
                    warn!("Failed to parse update-fleet-settings payload: {}", data);
                }
            }
        });
    }

    // ── signal (WebRTC relay) ─────────────────────────────────────────────────
    {
        let socket = socket.clone();
        socket.on("signal", move |s: SocketRef, Data::<Value>(data)| {
            async move {
                let _ = s.broadcast().emit("signal", &data);
            }
        });
    }

    info!("All handlers registered for socket {socket_id}");
}
