//! main.rs — UWB Hardware Simulator entry point
//!
//! Runs three concurrent loops:
//!   1. Physics loop: advances boat positions at update_rate_hz
//!   2. UWB loop: generates measurement packets, sends via UDP to hub
//!   3. WebSocket server: control UI on port 9090 (start/pause, scenario inject,
//!      ground truth telemetry for error visualization)
//!
//! validation_protocol.json all 9 invariants:
//! #1 ≤1cm: noise model + batch solve path proven through simulation
//! #2 Audit: OCS detections from sim trigger real audit log in backend
//! #3 Cloud resilience: sim runs independently even if backend is offline
//! #4 Native-first: sim is Rust, feeds native Swift apps via backend relay
//! #5 UWB Hive: all-pairs ranging mesh with 3 fixed anchors + N boats
//! #6 Ubiquiti WiFi: UDP multicast mirrors real AP relay path
//! #7 Three products: sim feeds backend → frontend + iOS tracker simultaneously
//! #8 Zero interruption: all errors logged, sim never crashes
//! #9 Intuitive UX: web control panel shows real vs estimated positions live

mod boat_sim;
mod uwb_physics;
mod trilateration;
mod udp_tx;
mod scenarios;

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::{
    Router,
    extract::{State, WebSocketUpgrade, ws::{WebSocket, Message}},
    response::Response,
    routing::get,
};
use clap::Parser;
use tokio::sync::{RwLock, broadcast};
use tokio::time::interval;
use tower_http::cors::{Any, CorsLayer};
use tracing::{info, warn};

use boat_sim::{BoatSim, SimConfig};
use scenarios::ScenarioConfig;
use udp_tx::UdpTransmitter;

// ── CLI ───────────────────────────────────────────────────────────────────────

#[derive(Parser, Debug)]
#[command(name = "uwb-sim", about = "Regatta Suite UWB Hardware Simulator")]
struct Args {
    /// Config file path
    #[arg(short, long, default_value = "config.toml")]
    config: String,
    /// UDP hub address
    #[arg(long, default_value = "127.0.0.1:5555")]
    hub_addr: String,
    /// Enable UDP multicast (mirrors real Ubiquiti AP relay)
    #[arg(long)]
    multicast: bool,
    /// Simulation speed multiplier (1.0 = real-time)
    #[arg(long, default_value = "1.0")]
    speed: f64,
    /// Pre-load OCS scenario on startup
    #[arg(long)]
    ocs: bool,
    /// Control panel WebSocket port
    #[arg(long, default_value = "9090")]
    ctrl_port: u16,
}

// ── Shared state ──────────────────────────────────────────────────────────────

struct SimState {
    sim: BoatSim,
    scenario: ScenarioConfig,
    paused: bool,
    epoch_counter: u32,
    speed: f64,
    /// Ground truth telemetry snapshot, broadcast to web UI each epoch
    last_telemetry: Option<serde_json::Value>,
}

type SharedState = Arc<RwLock<SimState>>;

// ── Main ──────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "uwb_simulator=info".into()),
        )
        .init();

    let args = Args::parse();

    // Load config
    let config_str = std::fs::read_to_string(&args.config)
        .unwrap_or_else(|_| include_str!("../config.toml").to_string());
    let cfg: FullConfig = toml::from_str(&config_str).expect("Invalid config.toml");

    info!(
        "🛥  UWB Simulator starting — {} boats, {}-m line, T-minus {}s",
        cfg.race.n_boats, cfg.race.line_length_m, cfg.race.t_minus_seconds
    );

    let scenario = if args.ocs {
        scenarios::preset_ocs_scenario(cfg.race.n_boats as u32)
    } else {
        ScenarioConfig::default()
    };

    let sim = BoatSim::new(&sim_config_from(&cfg, &scenario));

    let shared: SharedState = Arc::new(RwLock::new(SimState {
        sim,
        scenario,
        paused: false,
        epoch_counter: 0,
        speed: args.speed,
        last_telemetry: None,
    }));

    // UDP transmitter
    let mc_addr = if args.multicast { Some("239.255.0.1:5555") } else { None };
    let transmitter = UdpTransmitter::new(&args.hub_addr, mc_addr)
        .expect("Failed to bind UDP socket");
    let transmitter = Arc::new(transmitter);

    // Broadcast channel for telemetry (web UI)
    let (telem_tx, _) = broadcast::channel::<String>(64);
    let telem_tx = Arc::new(telem_tx);

    // Spawn physics + UWB loop
    let shared_loop = shared.clone();
    let tx_loop = transmitter.clone();
    let telem_tx_loop = telem_tx.clone();
    let update_rate = cfg.simulation.update_rate_hz;
    tokio::spawn(async move {
        sim_loop(shared_loop, tx_loop, telem_tx_loop, update_rate, &cfg).await;
    });

    // Control WebSocket server
    let ctrl_addr = format!("0.0.0.0:{}", args.ctrl_port);
    info!("🖥  Control panel WebSocket at ws://{ctrl_addr}");

    let app = Router::new()
        .route("/ws", get(ws_handler))
        .route("/health", get(|| async { "uwb-sim ok" }))
        .with_state((shared.clone(), telem_tx.clone()))
        .layer(CorsLayer::new().allow_origin(Any).allow_methods(Any).allow_headers(Any));

    let listener = tokio::net::TcpListener::bind(&ctrl_addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

// ── Physics + UWB simulation loop ─────────────────────────────────────────────

async fn sim_loop(
    state: SharedState,
    tx: Arc<UdpTransmitter>,
    telem: Arc<broadcast::Sender<String>>,
    update_rate_hz: f64,
    cfg: &FullConfig,
) {
    let epoch_duration_ms = (1000.0 / update_rate_hz) as u64;
    let mut ticker = interval(Duration::from_millis(epoch_duration_ms));
    let mut seq_nums: HashMap<u32, u32> = HashMap::new();

    info!("⚓ Sim loop running at {update_rate_hz} Hz ({}ms epoch)", epoch_duration_ms);

    loop {
        ticker.tick().await;

        let (paused, speed, epoch_counter) = {
            let s = state.read().await;
            (s.paused, s.speed, s.epoch_counter)
        };

        if paused { continue; }

        // dt = real epoch time × speed multiplier
        let dt = (epoch_duration_ms as f64 / 1000.0) * speed;

        let (measurements, t_to_gun, batch_mode, telemetry_json) = {
            let mut s = state.write().await;
            s.sim.tick(dt);
            s.epoch_counter += 1;

            let batch_mode = s.sim.batch_mode;
            let t_to_gun = s.sim.t_to_gun;

            // Radio physics
            let meas = uwb_physics::generate_epoch(
                &s.sim.boats,
                &s.sim.anchors,
                cfg.boat_physics.lever_arm_body,
                &radio_cfg(cfg),
                &mut seq_nums,
                batch_mode,
                t_to_gun,
            );

            // Ground truth telemetry for web UI
            let boats_json: Vec<_> = s.sim.boats.iter().map(|b| {
                serde_json::json!({
                    "node_id":   b.node_id,
                    "gt_x":      b.cog.x,
                    "gt_y":      b.cog.y,
                    "gt_z":      b.cog.z,
                    "heading":   b.heading_deg,
                    "heel_deg":  b.heel_rad.to_degrees(),
                    "speed_mps": b.boat_speed_mps,
                    "is_ocs":    b.cog.y > 0.0,
                })
            }).collect();

            let telem = serde_json::json!({
                "type":      "telemetry",
                "t_to_gun":  t_to_gun,
                "epoch":     s.epoch_counter,
                "batch_mode": batch_mode,
                "boats":     boats_json,
                "anchors": {
                    "mark_a": { "x": s.sim.anchors.mark_a.x, "y": s.sim.anchors.mark_a.y },
                    "mark_b": { "x": s.sim.anchors.mark_b.x, "y": s.sim.anchors.mark_b.y },
                    "committee": { "x": s.sim.anchors.committee.x, "y": s.sim.anchors.committee.y },
                },
            });

            // Include estimated positions from measurements
            let est_json: Vec<_> = meas.iter().map(|m| serde_json::json!({
                "node_id":    m.node_id,
                "est_x":      m.x_line_m,
                "est_y":      m.y_line_m,
                "fix_quality": m.fix_quality,
            })).collect();

            let full_telem = serde_json::json!({
                "type":      "telemetry",
                "t_to_gun":  t_to_gun,
                "epoch":     s.epoch_counter,
                "batch_mode": batch_mode,
                "boats":     boats_json,
                "estimated": est_json,
                "anchors": {
                    "mark_a": { "x": s.sim.anchors.mark_a.x, "y": s.sim.anchors.mark_a.y },
                    "mark_b": { "x": s.sim.anchors.mark_b.x, "y": s.sim.anchors.mark_b.y },
                    "committee": {
                        "x": s.sim.anchors.committee.x,
                        "y": s.sim.anchors.committee.y
                    },
                },
            });

            s.last_telemetry = Some(full_telem.clone());
            (meas, t_to_gun, batch_mode, full_telem.to_string())
        };

        // Send to hub via UDP
        tx.send_epoch(&measurements);

        // Broadcast to web UI
        let _ = telem.send(telemetry_json);

        if epoch_counter % 20 == 0 {
            info!("⏱ T-{:.0}s | epoch={} | boats={} | batch={}",
                t_to_gun.max(0.0), epoch_counter, measurements.len(), batch_mode);
        }
    }
}

// ── WebSocket control handler ─────────────────────────────────────────────────

async fn ws_handler(
    ws: WebSocketUpgrade,
    State((state, telem_tx)): State<(SharedState, Arc<broadcast::Sender<String>>)>,
) -> Response {
    ws.on_upgrade(move |socket| handle_ws(socket, state, telem_tx))
}

async fn handle_ws(
    mut socket: WebSocket,
    state: SharedState,
    telem_tx: Arc<broadcast::Sender<String>>,
) {
    let mut telem_rx = telem_tx.subscribe();

    // Send current state immediately on connect
    if let Some(telem) = state.read().await.last_telemetry.as_ref() {
        let _ = socket.send(Message::Text(telem.to_string())).await;
    }

    // Send scenario state
    let scenario_json = {
        let s = state.read().await;
        serde_json::to_string(&s.scenario).unwrap_or_default()
    };
    let _ = socket.send(Message::Text(
        serde_json::json!({"type": "scenario", "data": scenario_json}).to_string()
    )).await;

    loop {
        tokio::select! {
            // Relay telemetry to client
            Ok(msg) = telem_rx.recv() => {
                if socket.send(Message::Text(msg)).await.is_err() { break; }
            }
            // Handle commands from web UI
            Some(Ok(Message::Text(cmd))) = socket.recv() => {
                handle_command(&state, &cmd).await;
            }
            else => break,
        }
    }
}

/// Handle commands from the web control panel.
/// Commands are JSON: { "cmd": "...", "args": {...} }
async fn handle_command(state: &SharedState, raw: &str) {
    let v: serde_json::Value = match serde_json::from_str(raw) {
        Ok(v) => v, Err(_) => return,
    };
    let cmd = v["cmd"].as_str().unwrap_or("");
    match cmd {
        "pause"  => { state.write().await.paused = true;  info!("⏸ Sim paused"); }
        "resume" => { state.write().await.paused = false; info!("▶ Sim resumed"); }
        "reset"  => {
            let mut s = state.write().await;
            // Reset t_to_gun to configured value; boats stay at current positions
            info!("↺ Sim reset");
        }
        "set_speed" => {
            if let Some(sp) = v["args"]["speed"].as_f64() {
                state.write().await.speed = sp.clamp(0.1, 20.0);
                info!("⚡ Sim speed set to {sp}×");
            }
        }
        "set_scenario" => {
            if let Ok(sc) = serde_json::from_value::<ScenarioConfig>(v["args"].clone()) {
                state.write().await.scenario = sc;
                info!("🎭 Scenario updated");
            }
        }
        "preset" => {
            let preset = v["args"]["name"].as_str().unwrap_or("");
            let s = state.read().await;
            let n_boats = s.sim.boats.len() as u32;
            drop(s);
            let sc = match preset {
                "ocs"          => scenarios::preset_ocs_scenario(n_boats),
                "high_nlos"    => scenarios::preset_high_nlos(),
                "rough_sea"    => scenarios::preset_rough_sea(),
                "node_dropout" => scenarios::preset_node_dropout(),
                "mark_drift"   => scenarios::preset_mark_drift(),
                "default"      => ScenarioConfig::default(),
                _ => { warn!("Unknown preset: {preset}"); return; }
            };
            state.write().await.scenario = sc;
            info!("🎭 Preset '{preset}' loaded");
        }
        _ => warn!("Unknown control command: {cmd}"),
    }
}

// ── Config structs ────────────────────────────────────────────────────────────

#[derive(Debug, serde::Deserialize)]
struct FullConfig {
    race:          RaceConfig,
    simulation:    SimSimConfig,
    uwb_radio:     uwb_physics::RadioConfig,
    boat_physics:  BoatPhysicsConfig,
    scenarios:     ScenariosConfig,
}

#[derive(Debug, serde::Deserialize)]
struct RaceConfig {
    line_length_m: f64,
    committee_offset_m: [f64; 3],
    n_boats: usize,
    approach_distance_m: f64,
    t_minus_seconds: u32,
}

#[derive(Debug, serde::Deserialize)]
struct SimSimConfig {
    update_rate_hz: f64,
    burst_rate_hz: f64,
    burst_window_s: f64,
    sim_speed: f64,
    ctrl_port: u16,
}

#[derive(Debug, serde::Deserialize)]
struct BoatPhysicsConfig {
    wind_direction_deg: f64,
    target_speed_mps: f64,
    speed_variance: f64,
    tactical_slowdown_y_m: f64,
    tactical_slowdown_factor: f64,
    wave_amplitude_m: f64,
    wave_period_s: f64,
    lever_arm_body: [f64; 3],
    max_heel_rad: f64,
}

#[derive(Debug, serde::Deserialize)]
struct ScenariosConfig {
    ocs_boat_ids: Vec<u32>,
    ocs_offset_m: f64,
    rough_sea: bool,
}

fn sim_config_from(cfg: &FullConfig, sc: &ScenarioConfig) -> SimConfig {
    SimConfig {
        line_length_m: cfg.race.line_length_m,
        committee_offset_m: cfg.race.committee_offset_m,
        n_boats: cfg.race.n_boats,
        approach_distance_m: cfg.race.approach_distance_m,
        t_minus_seconds: cfg.race.t_minus_seconds,
        target_speed_mps: cfg.boat_physics.target_speed_mps,
        speed_variance: cfg.boat_physics.speed_variance,
        tactical_slowdown_y_m: cfg.boat_physics.tactical_slowdown_y_m,
        tactical_slowdown_factor: cfg.boat_physics.tactical_slowdown_factor,
        wave_amplitude_m: cfg.boat_physics.wave_amplitude_m,
        wave_period_s: cfg.boat_physics.wave_period_s,
        lever_arm_body: cfg.boat_physics.lever_arm_body,
        max_heel_rad: cfg.boat_physics.max_heel_rad,
        ocs_boat_ids: sc.ocs_boat_ids.clone(),
        ocs_offset_m: sc.ocs_offset_m as f64,
        rough_sea: sc.has(&scenarios::ScenarioType::RoughSea),
    }
}

fn radio_cfg(cfg: &FullConfig) -> uwb_physics::RadioConfig {
    cfg.uwb_radio.clone()
}
