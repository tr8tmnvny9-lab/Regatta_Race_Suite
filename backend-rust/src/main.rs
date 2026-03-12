mod handlers;
mod persistence;
mod auth;
mod procedure_engine;
mod state;
mod flight_engine;
mod audit;
mod uwb_hub;
mod trilateration;
mod auto_director;
mod ranking_engine;
pub mod cloud_sync;
pub mod edge_network;

use std::collections::HashSet;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use axum::routing::get;
use axum::Router;
use serde_json::json;
use socketioxide::SocketIo;
use tokio::sync::RwLock;
use tower_http::cors::{Any, CorsLayer};
use axum::http::HeaderValue;
use tracing::{info, warn};

use auth::AuthEngine;
use audit::AuditLogger;
use handlers::{on_connect, DeadBoats, SharedEngine, SharedState};
use persistence::load_state;
use procedure_engine::{ProcedureEngine, TickResult};
use state::{RaceStatus, SequenceInfo};
use uwb_hub::{start_uwb_hub, UwbHubConfig};
use auto_director::start_auto_director;
use ranking_engine::start_ranking_engine;

// ─── Global startup time (for uptime reporting) ──────────────────────────────
static STARTUP_MS: AtomicU64 = AtomicU64::new(0);

// ─── Time Sync Endpoint ───────────────────────────────────────────────────────

async fn time_sync() -> axum::Json<serde_json::Value> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    axum::Json(json!({ "serverTime": now }))
}

// ─── Health Endpoint (required by Fly.io + cloud deployment) ─────────────────
// GET /health → { status, version, mode, uptimeSecs }
// Fly.io restarts the instance if this returns non-200.
async fn health_check() -> axum::Json<serde_json::Value> {
    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    let startup = STARTUP_MS.load(Ordering::Relaxed);
    let uptime_secs = if startup > 0 { (now_ms - startup) / 1000 } else { 0 };
    let mode = std::env::var("BACKEND_MODE").unwrap_or_else(|_| "local".into());
    axum::Json(json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION"),
        "mode": mode,
        "uptimeSecs": uptime_secs,
    }))
}

// ─── Procedure Engine Tick Task ───────────────────────────────────────────────

async fn run_engine_tick(
    engine: SharedEngine,
    shared: SharedState,
    io: SocketIo,
    ocs_tx: tokio::sync::mpsc::Sender<uwb_hub::OcsEvent>,
) {
    let mut interval = tokio::time::interval(Duration::from_millis(200)); // 5Hz
    loop {
        interval.tick().await;

        let mut eng = engine.write().await;
        if !eng.is_running() {
            continue;
        }

        let result = eng.tick();
        drop(eng);

        match result {
            TickResult::Idle => {}
            TickResult::Update(upd) => {
                // Sync race status from engine's node-level mapping
                let eng = engine.read().await;
                let engine_status = eng.current_race_status();
                drop(eng);

                {
                    let mut state = shared.write().await;
                    state.status = engine_status;
                    state.current_sequence = Some(upd.current_sequence.clone());
                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                    state.current_node_id = Some(upd.current_node_id.clone());
                    state.waiting_for_trigger = upd.waiting_for_trigger;
                    state.action_label = upd.action_label.clone();
                    state.is_post_trigger = upd.is_post_trigger;
                }
                let _ = io.emit("sequence-update", &upd);
            }
            TickResult::GunFired(upd) => {
                info!("🏁 T-0 GUN FIRED: Transition to RACING state!");

                // Sync race status
                let eng = engine.read().await;
                let engine_status = eng.current_race_status();
                drop(eng);
                
                {
                    let mut state = shared.write().await;
                    state.status = engine_status;
                    state.current_sequence = Some(upd.current_sequence.clone());
                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                    state.current_node_id = Some(upd.current_node_id.clone());
                    state.action_label = upd.action_label.clone();
                }
                
                // Trigger the UWB Concurrent Batch Solve for sub-cm OCS Detection
                uwb_hub::trigger_batch_solve(&ocs_tx).await;
                
                let _ = io.emit("sequence-update", &upd);
            }
            TickResult::SequenceComplete => {
                info!("Sequence complete — race finished");
                let finish_time = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;

                {
                    let mut state = shared.write().await;
                    state.status = RaceStatus::Finished;
                    state.current_sequence = Some(SequenceInfo {
                        event: "FINISHED".to_string(),
                        flags: vec![],
                    });
                    state.sequence_time_remaining = Some(0.0);
                }

                let state = shared.read().await;
                let _ = io.emit("race-finished", &json!({ "finishTime": finish_time }));
                let _ = io.emit("state-update", &*state);
            }
        }
    }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    // Record startup time for uptime reporting
    let startup_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    STARTUP_MS.store(startup_ms, Ordering::Relaxed);

    // Logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "regatta_backend=info,socketioxide=warn".into()),
        )
        .init();

    // Log backend mode (local file persistence vs cloud Supabase)
    let backend_mode = std::env::var("BACKEND_MODE").unwrap_or_else(|_| "local".into());
    info!("🏁 Regatta Pro Backend (Rust) v{} starting — mode: {backend_mode}",
        env!("CARGO_PKG_VERSION"));
        
    // Phase 3: SNPN-to-Starlink Routing (Edge Configuration)
    if backend_mode == "edge" {
        info!("📡 Nokia SNPN Edge Mode detected. Configuring Starlink Uplink Routing...");
        if let Err(e) = edge_network::configure_starlink_routing().await {
            warn!("Failed to configure Starlink routing override: {e}");
        } else {
            info!("✅ Outbound Media & Telemetry bound to Starlink tunnel.");
        }
    }

    // Load persisted state
    let race_state = load_state().await;
    let shared: SharedState = Arc::new(RwLock::new(race_state));
    let engine: SharedEngine = Arc::new(RwLock::new(ProcedureEngine::new()));
    let dead_boats: DeadBoats = Arc::new(RwLock::new(HashSet::new()));
    
    // Auth Engine
    let auth_engine = AuthEngine::new();
    let auth_clone = auth_engine.clone();
    tokio::spawn(async move {
        auth_clone.refresh_apple_keys().await;
        let mut interval = tokio::time::interval(Duration::from_secs(86400));
        loop {
            interval.tick().await;
            auth_clone.refresh_apple_keys().await;
        }
    });

    // Audit Logger (SHA-256 chained, satisfies Invariant #2)
    let audit_logger = AuditLogger::new();
    audit_logger.log_session_event("server_start", Some(serde_json::json!({
        "version": env!("CARGO_PKG_VERSION"),
        "mode": backend_mode,
    }))).await;

    // UWB Hub (UDP listener on :5555, satisfies Invariant #1 path)
    let (ocs_tx, _ocs_rx) = tokio::sync::mpsc::channel::<uwb_hub::OcsEvent>(64);
    let uwb_config = UwbHubConfig::default();
    
    // We clone the sender so the engine tick can use it too
    let ocs_tx_tick = ocs_tx.clone();
    tokio::spawn(start_uwb_hub(uwb_config, ocs_tx));

    // Build Socket.IO layer
    let (socket_layer, io) = SocketIo::builder().build_layer();

    // Clone refs for socket handler
    let shared_sock = shared.clone();
    let engine_sock = engine.clone();
    let dead_sock = dead_boats.clone();
    let auth_sock = auth_engine.clone();

    io.ns("/", move |socket: socketioxide::extract::SocketRef| {
        let shared = shared_sock.clone();
        let engine = engine_sock.clone();
        let dead_boats = dead_sock.clone();
        let auth_engine = auth_sock.clone();
        async move {
            on_connect(socket, shared, engine, dead_boats, auth_engine).await;
        }
    });

    // Start execution task loops
    tokio::spawn(run_engine_tick(engine.clone(), shared.clone(), io.clone(), ocs_tx_tick));
    tokio::spawn(start_auto_director(shared.clone(), io.clone()));
    tokio::spawn(start_ranking_engine(shared.clone(), io.clone()));

    // Phase 1: AWS Aurora Cloud Sync (Heartbeat & State Mirroring)
    if let Ok(db_url) = std::env::var("AURORA_DB_URL") {
        info!("AWS Setup: Activating CloudSyncManager for Aurora integration.");
        let redis_url = std::env::var("REDIS_URL").ok();
        let session_id = "default".to_string(); // In a full app, generate/fetch this dynamically
        if let Ok(cloud_sync) = cloud_sync::CloudSyncManager::connect(&db_url, redis_url, session_id).await {
            let sync_arc = Arc::new(cloud_sync);
            
            // Wire AuditLogger to Aurora DB
            audit_logger.attach_cloud_sync(sync_arc.clone()).await;

            // Spawn cloud sync background tasks
            tokio::spawn(sync_arc.clone().run_heartbeat_loop());
            tokio::spawn(sync_arc.run_state_sync_loop(shared.clone()));
        } else {
            warn!("Failed to connect to Aurora Database. Proceeding in Local-Only mode.");
        }
    }

    // CORS — local dev: http://localhost:3000; cloud: set CORS_ORIGINS=*
    // Fly.io env sets CORS_ORIGINS=* so native Mac apps, iOS apps, and
    // browsers from any origin can connect (secure via JWT auth layer).
    let cors_origins_env = std::env::var("CORS_ORIGINS")
        .unwrap_or_else(|_| "http://localhost:3000,http://localhost:5173".to_string());

    let cors = if cors_origins_env.trim() == "*" {
        CorsLayer::new()
            .allow_origin(tower_http::cors::Any)
            .allow_methods(Any)
            .allow_headers(Any)
    } else {
        let origins: Vec<HeaderValue> = cors_origins_env
            .split(',')
            .filter_map(|o| o.trim().parse::<HeaderValue>().ok())
            .collect();
        CorsLayer::new()
            .allow_origin(origins)
            .allow_methods(Any)
            .allow_headers(Any)
    };

    // Build Axum router
    let app = Router::new()
        .route("/health", get(health_check))   // Fly.io health check
        .route("/sync", get(time_sync))
        .layer(socket_layer)
        .layer(cors);

    let port = std::env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let addr = format!("0.0.0.0:{port}");
    info!("🚀 Listening on {addr}");

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();

}
