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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoricalPing {
    pub timestamp: i64,
    pub lat: f64,
    pub lon: f64,
}

// ─── Race Status (RRS-compliant state machine) ───────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum RaceStatus {
    #[default]
    Idle,
    Warning,            // T-5:00 → T-4:00 (class flag up, 1 sound)
    Preparatory,        // T-4:00 → T-1:00 (prep flag up, 1 sound)
    OneMinute,          // T-1:00 → T-0:00 (prep flag down, 1 long sound)
    Racing,             // After start signal
    Finished,
    Postponed,          // AP flag + 2 sounds
    IndividualRecall,   // X flag + 1 sound (transient, returns to Racing)
    GeneralRecall,      // 1st Substitute + 2 sounds (resets to new Warning)
    Abandoned,          // N flag + 3 sounds
}

// ─── Sound Signals ───────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SoundSignal {
    #[default]
    None,
    OneShort,       // 1 short sound
    OneLong,        // 1 long sound
    TwoShort,       // 2 short sounds
    ThreeShort,     // 3 short sounds
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
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub course_boundary: Option<Vec<LatLon>>,
}

// ─── Wind & Weather ───────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct WindState {
    pub direction: f64,
    pub speed: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum WeatherProvider {
    Manual,
    Openmeteo,
    Noaa,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WeatherReport {
    pub timestamp: i64,
    pub wind_direction: f64,
    pub wind_speed: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gusts: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub temperature: Option<f64>,
    pub provider: WeatherProvider,
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

// ─── Penalty (RRS + Appendix UF) ─────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum PenaltyType {
    Ocs,                // On Course Side at start
    Dsq,                // Disqualified (Black flag / rule breach)
    Dnf,                // Did Not Finish
    Dns,                // Did Not Start
    Tle,                // Time Limit Expired
    Turn360,            // Umpire: 360° turn penalty
    UmpireNoAction,     // Umpire: Green+White (no penalty)
    UmpirePenalty,      // Umpire: Red flag penalty
    UmpireDsq,          // Umpire: Black flag DSQ
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Penalty {
    pub boat_id: String,
    #[serde(rename = "type")]
    pub penalty_type: PenaltyType,
    pub timestamp: i64,
}

// ─── Time Limits ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct TimeLimits {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mark1_limit_secs: Option<f64>,       // Abandon if no boat at mark 1
    #[serde(skip_serializing_if = "Option::is_none")]
    pub finish_window_secs: Option<f64>,     // Time after first finisher
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tle_scoring: Option<String>,         // e.g. "LAST+2"
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
    #[serde(default)]
    pub sound: SoundSignal,
    #[serde(rename = "soundOnRemove", default)]
    pub sound_on_remove: SoundSignal,
    #[serde(rename = "waitForUserTrigger", default)]
    pub wait_for_user_trigger: bool,
    #[serde(rename = "actionLabel", skip_serializing_if = "Option::is_none")]
    pub action_label: Option<String>,
    #[serde(rename = "postTriggerDuration", default)]
    pub post_trigger_duration: f64,
    #[serde(rename = "postTriggerFlags", default)]
    pub post_trigger_flags: Vec<String>,
    // Map this node to a specific RaceStatus (optional override)
    #[serde(rename = "raceStatus", skip_serializing_if = "Option::is_none")]
    pub race_status: Option<String>,
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
    #[serde(rename = "autoRestart", default)]
    pub auto_restart: bool,
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
    #[serde(default)]
    pub waiting_for_trigger: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub action_label: Option<String>,
    #[serde(default)]
    pub is_post_trigger: bool,
    #[serde(default)]
    pub sound: SoundSignal,
}

// ─── Logging ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "UPPERCASE")]
pub enum LogCategory {
    Boat,      // Tracker/Simulation activity
    Course,    // Mark movements/settings
    Procedure, // Start logic, node triggers
    Jury,      // Penalties
    System,    // Server-level events
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub protest_flagged: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jury_notes: Option<String>,
}

// ─── Full Race State ──────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RaceState {
    pub status: RaceStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub global_override: Option<String>, // "AP", "N", "GENERAL_RECALL", "INDIVIDUAL_RECALL"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_sequence: Option<SequenceInfo>,
    pub prep_flag: PrepFlag,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sequence_time_remaining: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_time: Option<i64>,
    pub wind: WindState,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub weather: Option<WeatherReport>,
    pub course: CourseState,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_procedure: Option<ProcedureGraph>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_location: Option<DefaultLocation>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_node_id: Option<String>,
    #[serde(default)]
    pub waiting_for_trigger: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub action_label: Option<String>,
    #[serde(default)]
    pub is_post_trigger: bool,
    // Time limits configuration
    #[serde(default)]
    pub time_limits: TimeLimits,
    // OCS boat list (boats on course side at start)
    #[serde(default)]
    pub ocs_boats: Vec<String>,
    // Ephemeral — populated at runtime, not persisted
    #[serde(default)]
    pub boats: HashMap<String, BoatState>,
    #[serde(default)]
    pub penalties: Vec<Penalty>,
    #[serde(default)]
    pub logs: Vec<LogEntry>,
    #[serde(default)]
    pub fleet_history: HashMap<String, Vec<HistoricalPing>>,
}

impl Default for RaceState {
    fn default() -> Self {
        Self {
            status: RaceStatus::Idle,
            global_override: None,
            current_sequence: None,
            prep_flag: PrepFlag::P,
            sequence_time_remaining: None,
            start_time: None,
            wind: WindState {
                direction: 180.0,
                speed: 12.0,
            },
            weather: None,
            course: CourseState::default(),
            current_procedure: None,
            default_location: None,
            current_node_id: None,
            waiting_for_trigger: false,
            action_label: None,
            is_post_trigger: false,
            time_limits: TimeLimits::default(),
            ocs_boats: Vec::new(),
            boats: HashMap::new(),
            penalties: Vec::new(),
            logs: Vec::new(),
            fleet_history: HashMap::new(),
        }
    }
}
