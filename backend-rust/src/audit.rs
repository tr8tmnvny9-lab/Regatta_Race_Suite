//! # audit
//!
//! SHA-256 chained immutable audit log.
//!
//! Every critical race event (gun signal, OCS detection, race status change, UWB batch solve)
//! is appended as a block where each block hashes the previous block's hash.
//! Tampering with any block breaks the chain — detectable by ProtestReplayEngine.
//!
//! ## Invariant
//! This module satisfies Core Invariant #2: "Protest-proof auditability —
//! every critical event (gun, OCS, position) must be logged with SHA-256 chain"

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fmt::Write as FmtWrite;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::fs::OpenOptions;
use tokio::io::AsyncWriteExt;
use tracing::{info, warn};

// ── Audit Event Types ─────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AuditEventType {
    /// Race procedure status change (gun, recall, postpone, abandon)
    RaceStatusChange,
    /// OCS boat detected at gun signal
    OcsDetected,
    /// UWB batch solve result (2s window at gun)
    UwbGunSolve,
    /// UWB raw measurement batch (periodic, every 5s)
    UwbMeasurementBatch,
    /// Session created or director reconnected
    SessionEvent,
    /// Protest replay query executed
    ProtestReplay,
}

impl std::fmt::Display for AuditEventType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = serde_json::to_string(self).unwrap_or_default();
        write!(f, "{}", s.trim_matches('"'))
    }
}

// ── Audit Block ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditBlock {
    /// Monotonically increasing per-session block sequence number
    pub block_seq: u64,
    /// Session ID this block belongs to
    pub session_id: String,
    /// Wall-clock timestamp in milliseconds
    pub timestamp_ms: u64,
    /// SHA-256 hash of the previous block (hex string).
    /// Genesis block: prev_hash = "0000...0000" (64 zeros)
    pub prev_hash: String,
    /// Event type being logged
    pub event_type: AuditEventType,
    /// JSON-serialized event payload (race status, OCS list, etc.)
    pub payload_json: String,
    /// SHA-256 of (prev_hash || timestamp_ms || event_type || payload_json)
    pub block_hash: String,
}

impl AuditBlock {
    fn compute_hash(
        prev_hash: &str,
        timestamp_ms: u64,
        event_type: &AuditEventType,
        payload_json: &str,
    ) -> String {
        let mut hasher = Sha256::new();
        hasher.update(prev_hash.as_bytes());
        hasher.update(timestamp_ms.to_le_bytes());
        hasher.update(event_type.to_string().as_bytes());
        hasher.update(payload_json.as_bytes());
        let result = hasher.finalize();
        let mut hex = String::with_capacity(64);
        for byte in result {
            let _ = write!(hex, "{byte:02x}");
        }
        hex
    }

    pub fn new(
        block_seq: u64,
        session_id: String,
        timestamp_ms: u64,
        prev_hash: String,
        event_type: AuditEventType,
        payload_json: String,
    ) -> Self {
        let block_hash = Self::compute_hash(&prev_hash, timestamp_ms, &event_type, &payload_json);
        Self {
            block_seq,
            session_id,
            timestamp_ms,
            prev_hash,
            event_type,
            payload_json,
            block_hash,
        }
    }

    /// Verify this block's hash is internally consistent
    pub fn verify(&self) -> bool {
        let expected = Self::compute_hash(
            &self.prev_hash,
            self.timestamp_ms,
            &self.event_type,
            &self.payload_json,
        );
        expected == self.block_hash
    }
}

// ── Audit Logger ──────────────────────────────────────────────────────────────

const GENESIS_HASH: &str = "0000000000000000000000000000000000000000000000000000000000000000";
const AUDIT_LOG_PATH: &str = "/data/audit.jsonl";

#[derive(Default)]
struct AuditState {
    block_seq: u64,
    last_hash: String,
}

/// Thread-safe, append-only SHA-256 chained audit logger.
/// Writes to /data/audit.jsonl (persistent Fly.io volume) as JSON lines.
#[derive(Clone)]
pub struct AuditLogger {
    state: Arc<RwLock<AuditState>>,
    session_id: Arc<RwLock<String>>,
}

impl AuditLogger {
    pub fn new() -> Self {
        let initial_state = AuditState {
            block_seq: 0,
            last_hash: GENESIS_HASH.to_string(),
        };
        Self {
            state: Arc::new(RwLock::new(initial_state)),
            session_id: Arc::new(RwLock::new("default".to_string())),
        }
    }

    pub async fn set_session(&self, id: String) {
        *self.session_id.write().await = id;
    }

    /// Append one audit block. This is the single write path.
    /// Non-blocking in normal operation — failures are logged but don't crash the race.
    pub async fn append(&self, event_type: AuditEventType, payload: serde_json::Value) {
        let timestamp_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let payload_json = payload.to_string();
        let session_id = self.session_id.read().await.clone();

        let block = {
            let mut state = self.state.write().await;
            let block = AuditBlock::new(
                state.block_seq,
                session_id,
                timestamp_ms,
                state.last_hash.clone(),
                event_type,
                payload_json,
            );
            state.last_hash = block.block_hash.clone();
            state.block_seq += 1;
            block
        };

        // Verify immediately (should always pass — defensive check)
        debug_assert!(block.verify(), "AuditBlock hash mismatch immediately after creation");

        // Write to append-only file (JSON line)
        let line = match serde_json::to_string(&block) {
            Ok(l) => format!("{l}\n"),
            Err(e) => {
                warn!("Audit: failed to serialize block: {e}");
                return;
            }
        };

        match OpenOptions::new()
            .create(true)
            .append(true)
            .open(AUDIT_LOG_PATH)
            .await
        {
            Ok(mut f) => {
                if let Err(e) = f.write_all(line.as_bytes()).await {
                    warn!("Audit: write failed: {e}");
                }
            }
            Err(e) => {
                // /data/ not available (local mode) — log to stdout only
                info!("Audit[{}]: {} — {}", block.block_seq, block.event_type, block.block_hash);
                if !e.kind().eq(&std::io::ErrorKind::NotFound) {
                    warn!("Audit: could not open {AUDIT_LOG_PATH}: {e}");
                }
            }
        }
    }

    /// Log a race status change (gun, recall, postpone, etc.)
    pub async fn log_race_status_change(&self, from: &str, to: &str, reason: Option<&str>) {
        self.append(
            AuditEventType::RaceStatusChange,
            serde_json::json!({
                "from": from,
                "to": to,
                "reason": reason,
            }),
        ).await;
    }

    /// Log OCS detection at gun signal
    pub async fn log_ocs_detected(&self, ocs_boats: &[serde_json::Value]) {
        self.append(
            AuditEventType::OcsDetected,
            serde_json::json!({
                "count": ocs_boats.len(),
                "boats": ocs_boats,
            }),
        ).await;
    }

    /// Log a session event (director join, takeover, etc.)
    pub async fn log_session_event(&self, event: &str, detail: Option<serde_json::Value>) {
        self.append(
            AuditEventType::SessionEvent,
            serde_json::json!({
                "event": event,
                "detail": detail,
            }),
        ).await;
    }
}
