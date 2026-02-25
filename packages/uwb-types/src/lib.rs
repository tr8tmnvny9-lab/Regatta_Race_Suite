//! # uwb-types
//!
//! Shared UWB packet structures for the Regatta Suite hive positioning system.
//!
//! These types are used by:
//! - `backend-rust`: receiving and parsing MeasurementPackets from UWB nodes
//! - `apps/uwb-firmware`: producing MeasurementPackets on the hardware node
//! - Swift bridge: C header generated from these structs for iOS/Mac BLE GATT
//!
//! ## Coordinate Conventions
//!
//! - **Body frame**: right-hand, X = bow, Y = port, Z = up
//! - **World frame**: local ENU (East-North-Up) Cartesian
//! - **Line frame**: X = along start line (MarkA→MarkB), Y = perpendicular (OCS side positive)
//!
//! ## Invariants (from validation_protocol.json)
//! - σ_pos_horizontal ≤ 1 cm at gun (batch mode, ≥100 edges/node)
//! - σ_pos_horizontal ≤ 5 cm live (iSAM2 incremental)
//! - All packets AES-128-CCM authenticated; replay-protection via seqNum + STS
//! - Full raw packet stream logged to SHA-256 chained audit log

use serde::{Deserialize, Serialize};

// ── Node Designation ──────────────────────────────────────────────────────────

/// Software designation of a node — changeable mid-race by race officer.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum NodeDesignation {
    /// Regular racing boat
    Boat = 0,
    /// Start line mark A (defines one end of the line)
    MarkA = 1,
    /// Start line mark B (defines the other end of the line)
    MarkB = 2,
    /// Race committee boat (hub host)
    Committee = 3,
}

impl NodeDesignation {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::MarkA,
            2 => Self::MarkB,
            3 => Self::Committee,
            _ => Self::Boat,
        }
    }
}

// ── 3D Vector & Quaternion ────────────────────────────────────────────────────

/// 3D vector (meters)
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

/// 2D vector (meters, in line-frame projection)
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

/// Orientation quaternion (IMU output, normalized)
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Quat {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub w: f32,
}

impl Default for Quat {
    fn default() -> Self {
        Self { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
    }
}

impl Quat {
    /// Convert quaternion to 3×3 rotation matrix (row-major)
    pub fn to_rotation_matrix(&self) -> [[f32; 3]; 3] {
        let (x, y, z, w) = (self.x, self.y, self.z, self.w);
        [
            [1.0 - 2.0*(y*y + z*z), 2.0*(x*y - w*z),       2.0*(x*z + w*y)],
            [2.0*(x*y + w*z),        1.0 - 2.0*(x*x + z*z), 2.0*(y*z - w*x)],
            [2.0*(x*z - w*y),        2.0*(y*z + w*x),       1.0 - 2.0*(x*x + y*y)],
        ]
    }

    /// Apply tilt compensation: rotate body-frame antenna offset to world frame
    /// p_ant_world = p_cog_world + R(q) * o_body
    pub fn rotate_vec3(&self, v: Vec3) -> Vec3 {
        let r = self.to_rotation_matrix();
        Vec3 {
            x: r[0][0]*v.x + r[0][1]*v.y + r[0][2]*v.z,
            y: r[1][0]*v.x + r[1][1]*v.y + r[1][2]*v.z,
            z: r[2][0]*v.x + r[2][1]*v.y + r[2][2]*v.z,
        }
    }
}

// ── Per-Peer Ranging Report ───────────────────────────────────────────────────

/// One DS-TWR + PDoA measurement to a single peer.
/// 28 bytes on wire (matches C struct layout for direct DMA transfer).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct PeerReport {
    /// Peer node ID
    pub peer_id: u32,
    /// Raw Euclidean range from DS-TWR, in millimeters.
    /// σ ≈ 5–10 mm after first-path CIR correction.
    pub range_mm: i32,
    /// PDoA horizontal azimuth × 10 (e.g. 154 = 15.4°)
    pub azimuth_deg10: i16,
    /// PDoA vertical elevation × 10
    pub elevation_deg10: i16,
    /// CIR SNR × 10 (used to set measurement covariance Σ_r)
    pub cir_snr_db10: u16,
    /// First-path index from CIR (NLOS detection; high fp_index = NLOS)
    pub fp_index: u8,
    /// Bit flags: bit0=NLOS, bit1=multipath, bit2=STS_fail, bit3=replay_suspected
    pub quality_flags: u8,
}

impl PeerReport {
    pub fn is_nlos(&self) -> bool { self.quality_flags & 0x01 != 0 }
    pub fn is_multipath(&self) -> bool { self.quality_flags & 0x02 != 0 }
    pub fn sts_failed(&self) -> bool { self.quality_flags & 0x04 != 0 }

    /// Measurement covariance σ_r (meters) — inflated for poor CIR quality or NLOS
    pub fn sigma_range_m(&self) -> f32 {
        let base = if self.is_nlos() { 0.20 } else { 0.07 }; // 7 cm normal, 20 cm NLOS
        let snr_factor = (100.0 - (self.cir_snr_db10 as f32 / 10.0)).max(0.0) / 100.0;
        base + snr_factor * 0.30
    }

    /// Range in meters
    pub fn range_m(&self) -> f32 { self.range_mm as f32 / 1000.0 }
}

// ── UWB Measurement Packet ────────────────────────────────────────────────────

/// Primary packet broadcast by every UWB node every 50ms epoch.
///
/// Wire format: AES-128-CCM encrypted, 192–384 bytes max.
/// Matches `MeasurementPacket` C struct in uwb-firmware.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeasurementPacket {
    /// Globally unique node ID (provisioned at manufacture)
    pub node_id: u32,
    /// Transmission timestamp in nanoseconds (synchronized clock)
    pub tx_timestamp_ns: u64,
    /// Monotonically increasing per-node sequence number.
    /// Hub rejects if delta > 3 (replay/stale detection).
    pub seq_num: u32,
    /// Node role for this epoch (can change mid-race via `set-mark-designation`)
    pub designation: NodeDesignation,
    /// Battery voltage in millivolts
    pub battery_mv: u16,
    /// Node-level flags: bit0=low_batt, bit1=sd_full, bit2=wifi_lost
    pub node_flags: u8,
    /// Current IMU orientation (quaternion from 6-DoF EKF)
    pub orientation: Quat,
    /// Antenna phase centre offset from CoG in body frame (meters).
    /// Pre-configured per mounting position (deck, mast, etc).
    /// Applied as: p_ant = p_cog + R(q) * ant_offset_body
    pub ant_offset_body: Vec3,
    /// Per-peer DS-TWR + PDoA measurements. Max 24 per epoch.
    pub reports: Vec<PeerReport>,
    /// CRC32 of all preceding bytes (verified before any processing)
    pub crc32: u32,
}

impl MeasurementPacket {
    /// Compute world-frame antenna position given current CoG position.
    /// This is the tilt-compensation step — eliminates heel-induced ranging error.
    pub fn antenna_world_pos(&self, cog_world: Vec3) -> Vec3 {
        let rotated_offset = self.orientation.rotate_vec3(self.ant_offset_body);
        Vec3 {
            x: cog_world.x + rotated_offset.x,
            y: cog_world.y + rotated_offset.y,
            z: cog_world.z + rotated_offset.z,
        }
    }
}

// ── Fused Position (Hub → All Clients) ───────────────────────────────────────

/// Per-node 2D position in the live start-line frame.
/// Positive y_line_m = over the start line (OCS).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct NodePosition2D {
    pub node_id: u32,
    /// Signed distance along the start line (MarkA→MarkB direction), meters
    pub x_line_m: f32,
    /// Perpendicular distance from start line (positive = OCS side), meters
    pub y_line_m: f32,
    /// Velocity along line, m/s
    pub vx_line_mps: f32,
    /// Velocity perpendicular to line, m/s
    pub vy_line_mps: f32,
    /// True heading, degrees (0 = north)
    pub heading_deg: f32,
    /// Fix quality 0–100. OCS call only made when ≥ 60.
    pub fix_quality: u8,
    /// Whether this position was computed in batch (gun) mode (1 cm) vs incremental (3–5 cm)
    pub batch_mode: bool,
}

impl NodePosition2D {
    /// Returns true if this boat is over the start line (OCS condition).
    /// Threshold: 10 cm over line AND fix quality ≥ 60.
    pub fn is_ocs(&self) -> bool {
        self.y_line_m > 0.10 && self.fix_quality >= 60
    }

    /// Distance to line in centimeters (signed, for HUD display)
    pub fn dtl_cm(&self) -> f32 { self.y_line_m * 100.0 }
}

/// Multicast packet sent by hub to all clients every epoch (UDP :5555).
/// 96 bytes max. Also bridged to WebSocket `state-update` for iOS/browser clients.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FusedPositionPacket {
    /// Hub wall-clock epoch timestamp (milliseconds)
    pub epoch_ms: u64,
    /// MarkA world position (3D, for audit trail)
    pub mark_a_pos: Vec3,
    /// MarkB world position (3D, for audit trail)
    pub mark_b_pos: Vec3,
    /// Start line midpoint (2D projected)
    pub line_origin: Vec2,
    /// Normalized start line direction unit vector (MarkA → MarkB)
    pub line_dir_unit: Vec2,
    /// Whether this was a batch solve (gun) or incremental solve
    pub batch_mode: bool,
    /// All boat positions in the line frame
    pub nodes: Vec<NodePosition2D>,
}

impl FusedPositionPacket {
    /// Returns all nodes with OCS condition (y_line > 10 cm, quality ≥ 60)
    pub fn ocs_nodes(&self) -> Vec<&NodePosition2D> {
        self.nodes.iter().filter(|n| n.is_ocs()).collect()
    }
}

// ── Audit Log Entry (SHA-256 chained) ────────────────────────────────────────

/// One block in the immutable SHA-256 chained audit log.
/// Stored in Supabase `audit_log` + per-node microSD.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditBlock {
    /// Block sequence number (monotonically increasing per session)
    pub block_seq: u64,
    /// Session ID this block belongs to
    pub session_id: String,
    /// Wall-clock timestamp (milliseconds)
    pub timestamp_ms: u64,
    /// SHA-256 hash of the previous block (hex string)
    /// Genesis block has prev_hash = "0" * 64
    pub prev_hash: String,
    /// Type of auditable event
    pub event_type: AuditEventType,
    /// Raw serialized payload (MeasurementPacket batch, FusedPositionPacket, etc.)
    pub payload_json: String,
    /// SHA-256 hash of (prev_hash + timestamp + event_type + payload)
    /// Computed by hub, verified by ProtestReplayEngine
    pub block_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AuditEventType {
    /// Raw UWB measurement batch (every 5s)
    MeasurementBatch,
    /// Fused position at gun (batch mode result)
    GunSolveResult,
    /// OCS detection event  
    OcsDetected,
    /// Race status change (gun, recall, postpone, etc.)
    RaceStatusChange,
    /// Factor graph snapshot (every 60s)
    GraphSnapshot,
}
