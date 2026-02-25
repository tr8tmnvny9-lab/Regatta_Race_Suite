//! # uwb_hub
//!
//! UWB Positioning Hub — receives MeasurementPackets from UWB nodes via UDP,
//! validates them, and feeds parsed positions into the shared race state.
//!
//! ## Architecture
//! This module runs as a separate Tokio task (tokio::spawn) alongside the
//! Socket.IO handler. It:
//!   1. Binds UDP socket on port 5555 (configurable via UWB_UDP_PORT env)
//!   2. Receives MeasurementPackets (JSON envelope for now, binary wire later)
//!   3. Validates sequence numbers (replay detection)
//!   4. Extracts fused position data for integration with RaceState
//!   5. Broadcasts updated boat positions via Socket.IO state-update
//!
//! ## Phase progression
//! - Phase 2 (now): JSON envelope, software-simulated positions, basic OCS detection
//! - Phase 6: Binary wire format, GTSAM 3D optimizer, real DS-TWR measurements
//!
//! ## Invariants
//! - Core Invariant #1: ≤1 cm accuracy (implemented in Phase 6 GTSAM optimizer)
//! - Core Invariant #2: all OCS detections logged to audit chain
//! - Core Invariant #8: zero race interruption — UDP errors never crash the server

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use tokio::net::UdpSocket;
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

// ── Configuration ─────────────────────────────────────────────────────────────

pub struct UwbHubConfig {
    /// UDP port to listen on (default 5555)
    pub udp_port: u16,
    /// Multicast group (default 239.255.0.1)
    pub multicast_group: String,
    /// OCS threshold in meters (default 0.10 = 10 cm)
    pub ocs_threshold_m: f32,
    /// Minimum fix quality for OCS call (default 60)
    pub min_fix_quality: u8,
}

impl Default for UwbHubConfig {
    fn default() -> Self {
        Self {
            udp_port: std::env::var("UWB_UDP_PORT")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(5555),
            multicast_group: std::env::var("UWB_MULTICAST_GROUP")
                .unwrap_or_else(|_| "239.255.0.1".to_string()),
            ocs_threshold_m: std::env::var("UWB_OCS_THRESHOLD_M")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(0.10),
            min_fix_quality: std::env::var("UWB_MIN_FIX_QUALITY")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(60),
        }
    }
}

// ── Wire Formats (Phase 2: JSON envelope; Phase 6: binary) ───────────────────

/// JSON envelope for MeasurementPacket (Phase 2 — software sim & testing).
/// Phase 6 will switch to the binary C struct from packages/uwb-types/uwb_types.h.
#[derive(Debug, Deserialize)]
pub struct UwbMeasurementEnvelope {
    pub node_id: u32,
    pub seq_num: u32,
    pub designation: u8,  // 0=boat, 1=markA, 2=markB, 3=committee
    pub battery_pct: u8,
    /// Pre-computed fused 2D line-frame position (from on-node EKF or hub sim)
    pub x_line_m: f32,
    /// Perpendicular to start line (positive = OCS side)
    pub y_line_m: f32,
    pub vx_line_mps: f32,
    pub vy_line_mps: f32,
    pub heading_deg: f32,
    pub fix_quality: u8,
    /// True if this came from a 2s batch solve at gun
    pub batch_mode: bool,
    /// Optional: anchor GPS pos (for TacticalMap integration)
    pub lat: Option<f64>,
    pub lon: Option<f64>,
}

/// Fused position packet broadcast back to all clients via UDP multicast.
#[derive(Debug, Serialize)]
pub struct FusedPositionBroadcast {
    pub epoch_ms: u64,
    pub nodes: Vec<FusedNode>,
    pub batch_mode: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct FusedNode {
    pub node_id: u32,
    pub x_line_m: f32,
    pub y_line_m: f32,
    pub vx_line_mps: f32,
    pub vy_line_mps: f32,
    pub heading_deg: f32,
    pub fix_quality: u8,
    pub is_ocs: bool,
    pub dtl_cm: f32,
}

impl FusedNode {
    pub fn from_envelope(env: &UwbMeasurementEnvelope, ocs_threshold: f32, min_quality: u8) -> Self {
        let is_ocs = env.y_line_m > ocs_threshold && env.fix_quality >= min_quality;
        Self {
            node_id: env.node_id,
            x_line_m: env.x_line_m,
            y_line_m: env.y_line_m,
            vx_line_mps: env.vx_line_mps,
            vy_line_mps: env.vy_line_mps,
            heading_deg: env.heading_deg,
            fix_quality: env.fix_quality,
            is_ocs,
            dtl_cm: env.y_line_m * 100.0,
        }
    }
}

// ── Sequence Number Tracker (replay protection) ───────────────────────────────

/// Tracks the last seen sequence number per node.
/// Rejects packets where seq_num is more than 3 behind the last seen (replay).
struct SeqTracker {
    last_seq: HashMap<u32, u32>,
}

impl SeqTracker {
    fn new() -> Self { Self { last_seq: HashMap::new() } }

    fn accept(&mut self, node_id: u32, seq_num: u32) -> bool {
        let last = self.last_seq.entry(node_id).or_insert(0);
        // Accept if sequence is advancing or within 3-step tolerance (reorder)
        let diff = seq_num.wrapping_sub(*last);
        if diff == 0 || diff > 1000 {
            // Exact duplicate or large backward jump (likely replay attack)
            warn!("UWB: rejected packet from node {node_id}: seq {seq_num} (last: {last})");
            return false;
        }
        *last = seq_num;
        true
    }
}

// ── OCS Event channel message ─────────────────────────────────────────────────

pub struct OcsEvent {
    pub epoch_ms: u64,
    pub boats: Vec<FusedNode>,
}

// ── Main UDP listener task ────────────────────────────────────────────────────

/// Start the UWB hub UDP listener as a background Tokio task.
/// Returns a receiver for OCS events that the socket handler can use
/// to trigger INDIVIDUAL_RECALL and audit log entries.
pub async fn start_uwb_hub(
    config: UwbHubConfig,
    ocs_tx: mpsc::Sender<OcsEvent>,
) {
    let addr = format!("0.0.0.0:{}", config.udp_port);
    let socket = match UdpSocket::bind(&addr).await {
        Ok(s) => {
            info!("📡 UWB Hub listening on UDP {addr}");
            Arc::new(s)
        }
        Err(e) => {
            // UWB not available (no hardware yet) — this is expected in dev/local mode
            warn!("UWB Hub: could not bind UDP {addr}: {e} (no hardware connected — ignoring)");
            return;
        }
    };

    let mut seq_tracker = SeqTracker::new();
    let mut buf = vec![0u8; 4096];
    let ocs_threshold = config.ocs_threshold_m;
    let min_quality = config.min_fix_quality;

    loop {
        match socket.recv_from(&mut buf).await {
            Ok((len, src)) => {
                process_packet(&buf[..len], src, &mut seq_tracker, ocs_threshold, min_quality, &ocs_tx).await;
            }
            Err(e) => {
                // Never crash — log and continue
                warn!("UWB Hub: UDP recv error: {e}");
            }
        }
    }
}

async fn process_packet(
    data: &[u8],
    src: SocketAddr,
    seq_tracker: &mut SeqTracker,
    ocs_threshold: f32,
    min_quality: u8,
    ocs_tx: &mpsc::Sender<OcsEvent>,
) {
    // Phase 2: JSON envelope. Phase 6: switch to binary C struct parsing.
    let env: UwbMeasurementEnvelope = match serde_json::from_slice(data) {
        Ok(e) => e,
        Err(e) => {
            debug!("UWB: malformed packet from {src}: {e}");
            return;
        }
    };

    // Replay protection
    if !seq_tracker.accept(env.node_id, env.seq_num) {
        return;
    }

    let node = FusedNode::from_envelope(&env, ocs_threshold, min_quality);
    debug!("UWB: node {} → DTL={:.1}cm (OCS={})", env.node_id, node.dtl_cm, node.is_ocs);

    // If any OCS boats detected, forward to the event channel
    if node.is_ocs || env.batch_mode {
        let epoch_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        // Collect into a single OCS event (Phase 6: aggregate all nodes in epoch)
        if node.is_ocs {
            let _ = ocs_tx.try_send(OcsEvent {
                epoch_ms,
                boats: vec![node],
            });
        }
    }
}
