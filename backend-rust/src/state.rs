use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// ─── Geographic Types ────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LatLon {
    pub lat: f64,
    pub lon: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefaultLocation {
    pub lat: f64,
    pub lon: f64,
    pub zoom: f64,
}

// ─── Race Status ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum RaceStatus {
    #[default]
    Idle,
    PreStart,
    Racing,
    Finished,
    Postponed,
    Recall,
    Abandoned,
}

// ─── Flags ───────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub enum PrepFlag {
    #[default]
    P,
    I,
    Z,
    U,
    #[serde(rename = "BLACK")]
    Black,
}

// ─── Course Elements ─────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BuoyType {
    Mark,
    Start,
    Finish,
    Gate,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Rounding {
    Port,
    Starboard,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BuoyDesign {
    Pole,
    Buoy,
    Tube,
    Marksetbot,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Buoy {
    pub id: String,
    #[serde(rename = "type")]
    pub buoy_type: BuoyType,
    pub name: String,
    pub pos: LatLon,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rounding: Option<Rounding>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pair_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gate_direction: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub design: Option<BuoyDesign>,
    #[serde(default)]
    pub disable_laylines: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct CourseLine {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p1: Option<LatLon>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p2: Option<LatLon>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct CourseState {
    pub marks: Vec<Buoy>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_line: Option<CourseLine>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub finish_line: Option<CourseLine>,
    pub course_boundary: Vec<LatLon>,
}

// ─── Wind ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct WindState {
    pub direction: f64,
    pub speed: f64,
}

// ─── Boat Telemetry ───────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ImuData {
    pub heading: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub roll: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pitch: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct VelocityData {
    pub speed: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dir: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct BoatState {
    pub boat_id: String,
    pub pos: LatLon,
    pub imu: ImuData,
    pub velocity: VelocityData,
    pub dtl: f64,
    pub timestamp: i64,
    // Simulation Persistence
    #[serde(default)]
    pub simulation_path: Vec<LatLon>,
    #[serde(default)]
    pub is_simulating: bool,
    #[serde(default)]
    pub speed_setting: f64,
    #[serde(default)]
    pub path_progress: f64,
}

// ─── Penalty ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Penalty {
    pub boat_id: String,
    #[serde(rename = "type")]
    pub penalty_type: String,
    pub timestamp: i64,
}

// ─── Sequence / Procedure ─────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SequenceInfo {
    pub event: String,
    pub flags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcedureNodeData {
    pub label: String,
    #[serde(default)]
    pub flags: Vec<String>,
    #[serde(default)]
    pub duration: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sound: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcedureNode {
    pub id: String,
    #[serde(rename = "type")]
    pub node_type: String,
    pub data: ProcedureNodeData,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub position: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcedureEdge {
    pub id: String,
    pub source: String,
    pub target: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub animated: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcedureGraph {
    pub id: String,
    pub nodes: Vec<ProcedureNode>,
    pub edges: Vec<ProcedureEdge>,
}

// ─── Sequence Update (broadcast payload) ─────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SequenceUpdate {
    pub status: String,
    pub current_sequence: SequenceInfo,
    pub sequence_time_remaining: f64,
    pub node_time_remaining: f64,
    pub current_node_id: String,
}

// ─── Logging ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "UPPERCASE")]
pub enum LogCategory {
    Boat,     // Tracker/Simulation activity
    Course,   // Mark movements/settings
    Procedure,// Start logic, node triggers
    Jury,     // Penalties
    System,   // Server-level events
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LogEntry {
    pub id: String,
    pub timestamp: i64,
    pub category: LogCategory,
    pub source: String, // e.g., "Tracker 01", "Director", "Jury UI"
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
    pub is_active: bool, // true for "moving/constantly changing", false for one-offs
}

// ─── Full Race State ──────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RaceState {
    pub status: RaceStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_sequence: Option<SequenceInfo>,
    pub prep_flag: PrepFlag,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sequence_time_remaining: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_time: Option<i64>,
    pub wind: WindState,
    pub course: CourseState,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_procedure: Option<ProcedureGraph>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_location: Option<DefaultLocation>,
    // Ephemeral — populated at runtime, not persisted
    #[serde(default)]
    pub boats: HashMap<String, BoatState>,
    #[serde(default)]
    pub penalties: Vec<Penalty>,
    #[serde(default)]
    pub logs: Vec<LogEntry>,
}

impl Default for RaceState {
    fn default() -> Self {
        Self {
            status: RaceStatus::Idle,
            current_sequence: None,
            prep_flag: PrepFlag::P,
            sequence_time_remaining: None,
            start_time: None,
            wind: WindState {
                direction: 180.0,
                speed: 12.0,
            },
            course: CourseState::default(),
            current_procedure: None,
            default_location: None,
            boats: HashMap::new(),
            penalties: Vec::new(),
            logs: Vec::new(),
        }
    }
}
