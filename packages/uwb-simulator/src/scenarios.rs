//! scenarios.rs — Injectable fault scenarios for the UWB simulator
//!
//! Each scenario tests a specific real-world failure mode or edge case.
//! Scenarios are toggleable at runtime via the WebSocket control API.
//!
//! validation_protocol.json:
//! - Invariant #8: every scenario must be recoverable (no permanent state corruption)
//! - Invariant #1: scenarios demonstrate the accuracy floor under adversity

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ScenarioType {
    /// Force specific boats to cross the start line (OCS) at T-0
    OCSBoat,
    /// Randomly silence a node's transmissions (hardware dropout)
    NodeDropout,
    /// Increase NLOS rate to 40% (crowded fleet, many boat bodies in path)
    HighNlos,
    /// 2× wave amplitude — stresses lever-arm compensation
    RoughSea,
    /// Trigger batch solve mode at gun (this is the default expected behavior)
    BatchGun,
    /// Move MarkB by a small amount (drift anchor, tests anchor health monitor)
    MarkDrift,
    /// Inject a clock slip in one node (+5ms, tests DS-TWR resilience)
    ClockSlip,
    /// Disconnect the committee boat node (tests OCS w/o committee anchor)
    CommitteeDropout,
    /// All nodes: reduce fix quality to < 60 (should suppress OCS calls)
    LowFixQuality,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScenarioConfig {
    pub active: Vec<ScenarioType>,
    pub ocs_boat_ids: Vec<u32>,
    pub ocs_offset_m: f32,       // how far across the line
    pub dropout_node_ids: Vec<u32>,
    pub dropout_duration_epochs: u32,
    pub mark_drift_node_id: u32, // node_id of the drifting mark (2=MarkB)
    pub mark_drift_m: f32,
    pub clock_slip_node_id: u32,
    pub clock_slip_ms: f32,
}

impl Default for ScenarioConfig {
    fn default() -> Self {
        Self {
            active: vec![ScenarioType::BatchGun],
            ocs_boat_ids: vec![],
            ocs_offset_m: 0.15,
            dropout_node_ids: vec![],
            dropout_duration_epochs: 3,
            mark_drift_node_id: 255,
            mark_drift_m: 0.0,
            clock_slip_node_id: 255,
            clock_slip_ms: 0.0,
        }
    }
}

impl ScenarioConfig {
    pub fn has(&self, s: &ScenarioType) -> bool {
        self.active.contains(s)
    }

    pub fn is_node_dropped(&self, node_id: u32, epoch_counter: u32) -> bool {
        if !self.has(&ScenarioType::NodeDropout) { return false; }
        if !self.dropout_node_ids.contains(&node_id) { return false; }
        epoch_counter % (self.dropout_duration_epochs + 10) < self.dropout_duration_epochs
    }

    /// NLOS multiplier for HighNlos scenario
    pub fn nlos_multiplier(&self) -> f64 {
        if self.has(&ScenarioType::HighNlos) { 3.5 } else { 1.0 }
    }

    /// Wave amplitude multiplier for RoughSea
    pub fn wave_multiplier(&self) -> f64 {
        if self.has(&ScenarioType::RoughSea) { 2.0 } else { 1.0 }
    }
}

/// Predefined scenario presets that can be selected from the web UI
pub fn preset_ocs_scenario(n_boats: u32) -> ScenarioConfig {
    ScenarioConfig {
        active: vec![ScenarioType::OCSBoat, ScenarioType::BatchGun],
        ocs_boat_ids: vec![10, 10 + n_boats / 3],  // boats 1 and ~midfleet
        ocs_offset_m: 0.15,
        ..Default::default()
    }
}

pub fn preset_high_nlos() -> ScenarioConfig {
    ScenarioConfig {
        active: vec![ScenarioType::HighNlos, ScenarioType::BatchGun],
        ..Default::default()
    }
}

pub fn preset_rough_sea() -> ScenarioConfig {
    ScenarioConfig {
        active: vec![ScenarioType::RoughSea, ScenarioType::BatchGun],
        ..Default::default()
    }
}

pub fn preset_node_dropout() -> ScenarioConfig {
    ScenarioConfig {
        active: vec![ScenarioType::NodeDropout, ScenarioType::BatchGun],
        dropout_node_ids: vec![13, 17],   // 2 random boats drop out
        dropout_duration_epochs: 3,
        ..Default::default()
    }
}

pub fn preset_mark_drift() -> ScenarioConfig {
    ScenarioConfig {
        active: vec![ScenarioType::MarkDrift, ScenarioType::BatchGun],
        mark_drift_node_id: 2,   // MarkB slowly drifts
        mark_drift_m: 0.50,
        ..Default::default()
    }
}
