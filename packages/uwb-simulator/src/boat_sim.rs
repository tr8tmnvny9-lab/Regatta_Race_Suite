//! boat_sim.rs — Boat physics simulation
//!
//! Simulates N racing boats approaching the start line.
//! Each boat has realistic sailing physics including:
//! - Position in ENU frame (East-North-Up Cartesian, meters)
//! - Velocity with tactical slowdown near the line
//! - Heel angle from boat speed (lever-arm source for UWB testing)
//! - Pitch from wave model
//! - Heading variation for realistic approach angles
//!
//! validation_protocol.json invariants served:
//! - #1 (≤1 cm): lever-arm compensation tested by realistic heel variation
//! - #5 (UWB Hive): mark buoys + committee boat are fixed anchors in this frame
//! - #8 (zero interruption): pure math, no panics, no unwraps

use rand::Rng;
use rand_distr::{Distribution, Normal, Uniform};
use serde::{Deserialize, Serialize};

// ── Types ─────────────────────────────────────────────────────────────────────

/// 3D vector in ENU (East-North-Up) frame, meters
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Vec3 {
    pub x: f64,  // East
    pub y: f64,  // North (toward start line)
    pub z: f64,  // Up
}

impl Vec3 {
    pub fn new(x: f64, y: f64, z: f64) -> Self { Self { x, y, z } }
    pub fn zero() -> Self { Self { x: 0.0, y: 0.0, z: 0.0 } }
    pub fn dist(&self, other: &Vec3) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2) + (self.z - other.z).powi(2)).sqrt()
    }
    pub fn add(&self, other: &Vec3) -> Vec3 {
        Vec3::new(self.x + other.x, self.y + other.y, self.z + other.z)
    }
    pub fn scale(&self, s: f64) -> Vec3 {
        Vec3::new(self.x * s, self.y * s, self.z * s)
    }
}

/// Unit quaternion for 3D rotation (w, x, y, z)
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Quat {
    pub w: f64, pub x: f64, pub y: f64, pub z: f64,
}

impl Quat {
    pub fn identity() -> Self { Self { w: 1.0, x: 0.0, y: 0.0, z: 0.0 } }

    /// Build from Euler angles (roll=heel, pitch, yaw=heading)
    /// All angles in radians. Applied in ZYX order (yaw then pitch then roll).
    pub fn from_euler(roll: f64, pitch: f64, yaw: f64) -> Self {
        let (cr, sr) = ((roll/2.0).cos(), (roll/2.0).sin());
        let (cp, sp) = ((pitch/2.0).cos(), (pitch/2.0).sin());
        let (cy, sy) = ((yaw/2.0).cos(), (yaw/2.0).sin());
        Self {
            w: cr*cp*cy + sr*sp*sy,
            x: sr*cp*cy - cr*sp*sy,
            y: cr*sp*cy + sr*cp*sy,
            z: cr*cp*sy - sr*sp*cy,
        }
    }

    /// Rotate a vector by this quaternion: v' = q * v * q⁻¹
    pub fn rotate(&self, v: Vec3) -> Vec3 {
        let (w, qx, qy, qz) = (self.w, self.x, self.y, self.z);
        let (vx, vy, vz) = (v.x, v.y, v.z);
        // Efficient quaternion-vector product
        let ix =  w*vx + qy*vz - qz*vy;
        let iy =  w*vy + qz*vx - qx*vz;
        let iz =  w*vz + qx*vy - qy*vx;
        let iw = -qx*vx - qy*vy - qz*vz;
        Vec3::new(
            ix*w + iw*(-qx) + iy*(-qz) - iz*(-qy),
            iy*w + iw*(-qy) + iz*(-qx) - ix*(-qz),
            iz*w + iw*(-qz) + ix*(-qy) - iy*(-qx),
        )
    }
}

// ── Race world geometry (Invariant #5 — UWB Hive anchors) ────────────────────

/// Fixed anchor positions in ENU frame
#[derive(Debug, Clone, Serialize)]
pub struct Anchors {
    /// Start line port end (pin mark / buoy)
    pub mark_a: Vec3,
    /// Start line starboard end (committee boat end buoy)
    pub mark_b: Vec3,
    /// Committee boat itself (UWB node, node_id=1)
    pub committee: Vec3,
}

impl Anchors {
    pub fn new(line_length: f64, committee: [f64; 3]) -> Self {
        Self {
            mark_a:    Vec3::new(-line_length / 2.0, 0.0, 0.0),
            mark_b:    Vec3::new( line_length / 2.0, 0.0, 0.0),
            committee: Vec3::new(committee[0], committee[1], committee[2]),
        }
    }

    /// Unit vector along start line (MarkA → MarkB)
    pub fn line_unit(&self) -> Vec3 {
        let dx = self.mark_b.x - self.mark_a.x;
        let dy = self.mark_b.y - self.mark_a.y;
        let len = (dx*dx + dy*dy).sqrt();
        Vec3::new(dx/len, dy/len, 0.0)
    }

    /// Unit normal to start line pointing toward OCS side (course side = negative)
    pub fn line_normal(&self) -> Vec3 {
        let u = self.line_unit();
        Vec3::new(-u.y, u.x, 0.0)   // 90° CCW rotation
    }
}

// ── Boat state ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize)]
pub struct BoatState {
    /// Logical boat number (1-based for display)
    pub boat_number: u32,
    /// UWB node_id (10-based: boat 1 → node 10, boat 12 → node 21)
    pub node_id: u32,
    /// 3D CoG position in ENU frame (meters)
    pub cog: Vec3,
    /// 3D velocity (m/s)
    pub vel: Vec3,
    /// True heading (0=N, 90=E), degrees
    pub heading_deg: f64,
    /// Heel angle (positive = starboard side down), radians
    pub heel_rad: f64,
    /// Pitch angle (positive = bow up), radians
    pub pitch_rad: f64,
    /// Current boat speed through water (m/s)
    pub boat_speed_mps: f64,
    /// Base (nominal) speed for this boat (m/s) — varies per boat
    pub base_speed_mps: f64,
    /// Battery level 0-100%
    pub battery_pct: u8,
    /// Has the boat purposely crossed the line (OCS scenario)
    pub is_ocs_scenario: bool,
    /// Wave phase offset (unique per boat)
    pub wave_phase: f64,
}

impl BoatState {
    /// Compute antenna world position after lever-arm + attitude correction
    /// lever_arm_body: offset from CoG to antenna in body frame (meters)
    ///
    /// This is the CRITICAL calculation — without it, ranging accuracy degrades
    /// by up to 50cm at 25° heel. Invariant #1 depends on this being correct.
    pub fn antenna_world_pos(&self, lever_arm_body: [f64; 3]) -> Vec3 {
        let q = Quat::from_euler(self.heel_rad, self.pitch_rad, self.heading_deg.to_radians());
        let offset_world = q.rotate(Vec3::new(
            lever_arm_body[0], lever_arm_body[1], lever_arm_body[2]
        ));
        self.cog.add(&offset_world)
    }

    /// Signed distance to start line in the line-normal direction (+ = OCS side)
    /// invariant_ref: #1 (≤1 cm) — hub computes this; GT here for error validation
    pub fn dtl_m(&self, anchors: &Anchors) -> f64 {
        let n = anchors.line_normal();
        let origin = anchors.mark_a;
        // Project CoG relative to line origin onto normal
        (self.cog.x - origin.x) * n.x + (self.cog.y - origin.y) * n.y
    }
}

// ── Simulation tick ───────────────────────────────────────────────────────────

pub struct BoatSim {
    pub boats: Vec<BoatState>,
    pub anchors: Anchors,
    pub t_elapsed: f64,           // seconds since sim start
    pub t_to_gun: f64,            // seconds until T-0
    pub batch_mode: bool,         // true during 2s batch solve at gun

    // Config
    line_length: f64,
    wave_amplitude: f64,
    wave_period: f64,
    lever_arm_body: [f64; 3],
    tactical_slowdown_y: f64,
    tactical_slowdown_factor: f64,
    max_heel_rad: f64,
    ocs_set: std::collections::HashSet<u32>,  // node_ids to force OCS
    ocs_offset: f64,
}

impl BoatSim {
    pub fn new(cfg: &SimConfig) -> Self {
        let anchors = Anchors::new(cfg.line_length_m, cfg.committee_offset_m);
        let boats = Self::spawn_boats(cfg, &anchors);
        let ocs_set = cfg.ocs_boat_ids.iter().cloned().collect();
        Self {
            boats,
            anchors,
            t_elapsed: 0.0,
            t_to_gun: cfg.t_minus_seconds as f64,
            batch_mode: false,
            line_length: cfg.line_length_m,
            wave_amplitude: cfg.wave_amplitude_m
                * if cfg.rough_sea { 2.0 } else { 1.0 },
            wave_period: cfg.wave_period_s,
            lever_arm_body: cfg.lever_arm_body,
            tactical_slowdown_y: cfg.tactical_slowdown_y_m,
            tactical_slowdown_factor: cfg.tactical_slowdown_factor,
            max_heel_rad: cfg.max_heel_rad,
            ocs_set,
            ocs_offset: cfg.ocs_offset_m,
        }
    }

    fn spawn_boats(cfg: &SimConfig, anchors: &Anchors) -> Vec<BoatState> {
        let mut rng = rand::thread_rng();
        let speed_dist = Uniform::new(
            cfg.target_speed_mps - cfg.speed_variance / 2.0,
            cfg.target_speed_mps + cfg.speed_variance / 2.0,
        );
        let x_spread = cfg.line_length_m * 0.9;

        (0..cfg.n_boats).map(|i| {
            let base_speed = speed_dist.sample(&mut rng);
            let x = -x_spread/2.0 + (i as f64 / f64::max(cfg.n_boats as f64 - 1.0, 1.0)) * x_spread;
            let y = -cfg.approach_distance_m + rng.gen_range(-20.0..20.0);
            BoatState {
                boat_number: i as u32 + 1,
                node_id: 10 + i as u32,   // nodes 10..21 for boats
                cog: Vec3::new(x, y, 0.0),
                vel: Vec3::new(0.0, base_speed, 0.0),
                heading_deg: 360.0 + rng.gen_range(-10.0..10.0),   // roughly North
                heel_rad: 0.0,
                pitch_rad: 0.0,
                boat_speed_mps: base_speed,
                base_speed_mps: base_speed,
                battery_pct: rng.gen_range(70..=100),
                is_ocs_scenario: false,
                wave_phase: rng.gen_range(0.0..std::f64::consts::TAU),
            }
        }).collect()
    }

    /// Advance simulation by dt seconds
    /// invariant_ref: #8 — no panics, sail past the line gracefully
    pub fn tick(&mut self, dt: f64) {
        self.t_elapsed += dt;
        self.t_to_gun = f64::max(self.t_to_gun - dt, -30.0);

        let angle = std::f64::consts::TAU / self.wave_period;
        let ocs_active = self.t_to_gun <= 0.0 && self.t_to_gun >= -5.0;

        for boat in &mut self.boats {
            // Wave: z oscillation
            boat.cog.z = self.wave_amplitude * (angle * self.t_elapsed + boat.wave_phase).sin();

            // Target speed: slow down near the line
            let target_speed = if boat.cog.y > -(self.tactical_slowdown_y) {
                boat.base_speed_mps * self.tactical_slowdown_factor
            } else {
                boat.base_speed_mps
            };

            // OCS scenario: push boat across line at gun
            let (actual_speed, pos_override) = if ocs_active && self.ocs_set.contains(&boat.node_id) {
                // Gently push the boat OCS side (positive y)
                let dtl = boat.cog.y;  // distance from line (0 = on line, positive = OCS)
                if dtl < self.ocs_offset {
                    (boat.base_speed_mps * 0.5, Some(dtl + 0.001 * dt))  // creep across
                } else {
                    (0.0_f64, None)  // hold position once OCS
                }
            } else {
                (target_speed, None)
            };

            // Smooth speed transition (simple first-order lag)
            boat.boat_speed_mps += (actual_speed - boat.boat_speed_mps) * (dt * 2.0).min(1.0);

            // Position update
            if let Some(next_y) = pos_override {
                boat.cog.y = next_y;
            } else {
                let hdg_rad = boat.heading_deg.to_radians();
                boat.vel = Vec3::new(
                    boat.boat_speed_mps * hdg_rad.sin(),
                    boat.boat_speed_mps * hdg_rad.cos(),
                    0.0,
                );
                boat.cog = boat.cog.add(&boat.vel.scale(dt));
            }

            // Attitude
            let speed_ratio = boat.boat_speed_mps / boat.base_speed_mps;
            boat.heel_rad  = speed_ratio * self.max_heel_rad;
            boat.pitch_rad = 0.05 * (angle * self.t_elapsed * 0.7 + boat.wave_phase).sin();
        }

        // Batch mode activates at gun (2-second window per Invariant #1 batch solve)
        self.batch_mode = self.t_to_gun <= 0.0 && self.t_to_gun >= -2.0;
    }
}

// ── Config struct (populated from config.toml) ────────────────────────────────

#[derive(Debug, Clone, Deserialize)]
pub struct SimConfig {
    // [race]
    pub line_length_m: f64,
    pub committee_offset_m: [f64; 3],
    pub n_boats: usize,
    pub approach_distance_m: f64,
    pub t_minus_seconds: u32,

    // [boat_physics]
    pub target_speed_mps: f64,
    pub speed_variance: f64,
    pub tactical_slowdown_y_m: f64,
    pub tactical_slowdown_factor: f64,
    pub wave_amplitude_m: f64,
    pub wave_period_s: f64,
    pub lever_arm_body: [f64; 3],
    pub max_heel_rad: f64,

    // [scenarios]
    pub ocs_boat_ids: Vec<u32>,
    pub ocs_offset_m: f64,
    pub rough_sea: bool,
}
