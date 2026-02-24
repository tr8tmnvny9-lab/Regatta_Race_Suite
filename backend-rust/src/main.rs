mod handlers;
mod persistence;
mod procedure_engine;
mod state;

use std::collections::HashSet;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use axum::routing::get;
use axum::Router;
use serde_json::json;
use socketioxide::SocketIo;
use tokio::sync::RwLock;
use tower_http::cors::{Any, CorsLayer};
use tracing::info;

use handlers::{on_connect, DeadBoats, SharedEngine, SharedState};
use persistence::load_state;
use procedure_engine::{ProcedureEngine, TickResult};
use state::{RaceStatus, SequenceInfo};

// ─── Time Sync Endpoint ───────────────────────────────────────────────────────

async fn time_sync() -> axum::Json<serde_json::Value> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    axum::Json(json!({ "serverTime": now }))
}

// ─── Procedure Engine Tick Task ───────────────────────────────────────────────

async fn run_engine_tick(
    engine: SharedEngine,
    shared: SharedState,
    io: SocketIo,
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
                // Update shared state
                {
                    let mut state = shared.write().await;
                    state.current_sequence = Some(upd.current_sequence.clone());
                    state.sequence_time_remaining = Some(upd.sequence_time_remaining);
                }
                let _ = io.emit("sequence-update", &upd);
            }
            TickResult::SequenceComplete => {
                info!("Sequence complete — transitioning to RACING");
                let start_time = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;

                {
                    let mut state = shared.write().await;
                    state.status = RaceStatus::Racing;
                    state.start_time = Some(start_time);
                    state.current_sequence = Some(SequenceInfo {
                        event: "STARTED".to_string(),
                        flags: vec![],
                    });
                    state.sequence_time_remaining = Some(0.0);
                }

                let state = shared.read().await;
                let _ = io.emit("race-started", &json!({ "startTime": start_time }));
                let _ = io.emit("state-update", &*state);
            }
        }
    }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    // Logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "regatta_backend=info,socketioxide=warn".into()),
        )
        .init();

    info!("🏁 Regatta Pro Backend (Rust) starting...");

    // Load persisted state
    let race_state = load_state().await;
    let shared: SharedState = Arc::new(RwLock::new(race_state));
    let engine: SharedEngine = Arc::new(RwLock::new(ProcedureEngine::new()));
    let dead_boats: DeadBoats = Arc::new(RwLock::new(HashSet::new()));

    // Build Socket.IO layer
    let (socket_layer, io) = SocketIo::builder().build_layer();

    // Clone refs for socket handler
    let shared_sock = shared.clone();
    let engine_sock = engine.clone();
    let dead_sock = dead_boats.clone();

    io.ns("/", move |socket: socketioxide::extract::SocketRef| {
        let shared = shared_sock.clone();
        let engine = engine_sock.clone();
        let dead_boats = dead_sock.clone();
        async move {
            on_connect(socket, shared, engine, dead_boats).await;
        }
    });

    // Start engine tick loop
    tokio::spawn(run_engine_tick(engine.clone(), shared.clone(), io.clone()));

    // CORS — allow all origins (keeps parity with TypeScript backend)
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build Axum router
    let app = Router::new()
        .route("/sync", get(time_sync))
        .layer(socket_layer)
        .layer(cors);

    let port = std::env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let addr = format!("0.0.0.0:{port}");
    info!("🚀 Listening on {addr}");

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
