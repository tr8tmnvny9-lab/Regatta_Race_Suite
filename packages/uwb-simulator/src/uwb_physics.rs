//! uwb_physics.rs — UWB DS-TWR radio physics simulation
//!
//! Simulates the full DW3720 UWB chip measurement chain:
//! 1. Compute true 3D inter-node ranges (after lever-arm correction)
//! 2. Apply DS-TWR noise: Gaussian LOS or biased NLOS
//! 3. Compute PDoA angles with realistic noise
//! 4. Generate CIR stats (SNR, fp_index) consistent with LOS/NLOS
//! 5. Classify NLOS using geometry + random probability
//!
//! validation_protocol.json:
//! - Invariant #1: σ_los=7cm ensures realistic path to ≤1cm batch accuracy
//! - Invariant #5: self-organizing mesh (every node ranges every visible peer)

use rand::Rng;
use rand_distr::{Distribution, Normal, Uniform};
use serde::{Deserialize, Serialize};

use crate::boat_sim::{Anchors, BoatState, Vec3};

// ── Radio configuration ───────────────────────────────────────────────────────

#[derive(Debug, Clone, Deserialize)]
pub struct RadioConfig {
    pub sigma_los_m:          f64,
    pub sigma_nlos_m:         f64,
    pub nlos_base_rate:       f64,
    pub nlos_crowd_radius_m:  f64,
    pub sigma_azimuth_deg:    f64,
    pub sigma_elevation_deg:  f64,
    pub snr_los_db_min:       f64,
    pub snr_los_db_max:       f64,
    pub snr_nlos_db_min:      f64,
    pub snr_nlos_db_max:      f64,
    pub fp_index_los_min:     u8,
    pub fp_index_los_max:     u8,
    pub fp_index_nlos_min:    u8,
    pub fp_index_nlos_max:    u8,
    pub max_los_range_m:      f64,
}

// ── Peer measurement (what one node reports about one peer) ───────────────────

/// Matches the PeerReport struct in packages/uwb-types/src/lib.rs
#[derive(Debug, Clone, Serialize)]
pub struct PeerReport {
    pub peer_id:      u32,
    /// Measured range in meters (DS-TWR output, noisy)
    pub range_m:      f32,
    /// PDoA azimuth in radians (in receiver body frame)
    pub pdoa_az_rad:  f32,
    /// PDoA elevation in radians
    pub pdoa_el_rad:  f32,
    /// CIR SNR (dB × 10, integer)
    pub snr_db10:     i16,
    /// First-path index (CIR quality indicator)
    pub fp_index:     u8,
    /// NLOS flag (firmware-detected)
    pub nlos:         bool,
}

/// Full measurement packet from one node in one epoch
#[derive(Debug, Clone, Serialize)]
pub struct EpochMeasurement {
    pub node_id:      u32,
    pub seq_num:      u32,
    pub designation:  u8,           // 0=boat, 1=markA, 2=markB, 3=committee
    pub battery_pct:  u8,
    /// EKF-estimated position (what the node sends in Phase 2 mode)
    pub x_line_m:     f32,
    pub y_line_m:     f32,
    pub vx_line_mps:  f32,
    pub vy_line_mps:  f32,
    pub heading_deg:  f32,
    pub fix_quality:  u8,
    pub batch_mode:   bool,
    /// Raw peer reports (used in "raw mode" for hub trilateration testing)
    pub peers:        Vec<PeerReport>,
    /// Ground truth DTL (for error display in web UI; NOT sent to hub)
    #[serde(skip)]
    pub gt_y_line_m:  f32,
}

// ── NLOS classifier ───────────────────────────────────────────────────────────

/// Determine if ranging between node_i and node_j is NLOS.
/// Uses geometric blocking (boats in between) + range attenuation + random base rate.
fn is_nlos(
    p_i: &Vec3,
    p_j: &Vec3,
    all_boats: &[BoatState],
    i_id: u32,
    j_id: u32,
    range: f64,
    cfg: &RadioConfig,
    rng: &mut impl Rng,
) -> bool {
    let mut prob = cfg.nlos_base_rate;

    // Geometric blocking: any boat within crowd_radius of the ranging line?
    let dir = Vec3::new(p_j.x - p_i.x, p_j.y - p_i.y, p_j.z - p_i.z);
    let len = range.max(0.001);
    for boat in all_boats {
        if boat.node_id == i_id || boat.node_id == j_id { continue; }
        // Distance from boat CoG to the line segment p_i→p_j
        let t = ((boat.cog.x - p_i.x) * dir.x + (boat.cog.y - p_i.y) * dir.y) / (len * len);
        let t = t.clamp(0.0, 1.0);
        let closest = Vec3::new(p_i.x + t * dir.x, p_i.y + t * dir.y, p_i.z + t * dir.z);
        let dist_to_line = closest.dist(&boat.cog);
        if dist_to_line < cfg.nlos_crowd_radius_m {
            prob += 0.20;
        }
    }

    // Long range attenuation
    if range > cfg.max_los_range_m {
        prob += 0.10 + 0.05 * ((range - cfg.max_los_range_m) / 50.0).min(0.30);
    }

    rng.gen_bool(prob.min(0.95))
}

// ── Main UWB measurement generator ───────────────────────────────────────────

/// Generate all measurements for one epoch.
/// Each boat's node ranges against all other visible nodes.
/// All anchor nodes (MarkA, MarkB, Committee) are included as fixed peers.
///
/// invariant_ref: #5 — self-organizing mesh (all-to-all ranging in TDMA)
pub fn generate_epoch(
    boats: &[BoatState],
    anchors: &Anchors,
    lever_arm: [f64; 3],
    cfg: &RadioConfig,
    seq_nums: &mut std::collections::HashMap<u32, u32>,
    batch_mode: bool,
    t_to_gun: f64,
) -> Vec<EpochMeasurement> {
    let mut rng = rand::thread_rng();

    // Compute all antenna world positions (CoG + lever-arm + attitude)
    // Fixed anchors at their stated positions (no lever arm offset for buoys)
    let mut node_positions: Vec<(u32, Vec3, u8, u8)> = vec![
        (1, anchors.mark_a,    1, 100),   // node_id, pos, designation, battery
        (2, anchors.mark_b,    2, 100),
        (3, anchors.committee, 3, 100),
    ];
    for boat in boats {
        let ant_pos = boat.antenna_world_pos(lever_arm);
        node_positions.push((boat.node_id, ant_pos, 0, boat.battery_pct));
    }

    let n = node_positions.len();
    let mut measurements = Vec::with_capacity(boats.len() + 3);

    for (idx_i, (ni, pi, desig_i, batt_i)) in node_positions.iter().enumerate() {
        // Only boats generate and send measurement packets (marks are passive anchors
        // that respond to ranging but don't initiate epochs)
        if *desig_i == 1 || *desig_i == 2 { continue; }

        let seq = seq_nums.entry(*ni).or_insert(0);
        *seq += 1;
        let seq_val = *seq;

        let mut peers = Vec::new();

        for (idx_j, (nj, pj, _, _)) in node_positions.iter().enumerate() {
            if idx_i == idx_j { continue; }

            let true_range = pi.dist(pj);

            // Determine NLOS (fixed anchors are assumed LOS to all boats)
            let nlos = if *desig_i >= 1 && *desig_i <= 3 {
                false
            } else {
                is_nlos(pi, pj, boats, *ni, *nj, true_range, cfg, &mut rng)
            };

            // DS-TWR range measurement with noise
            let sigma = if nlos { cfg.sigma_nlos_m } else { cfg.sigma_los_m };
            let noise_dist = Normal::new(0.0, sigma).unwrap();
            let nlos_bias = if nlos { f64::max(Normal::new(0.3, 0.1).unwrap().sample(&mut rng), 0.0) } else { 0.0 };
            let measured_range = (true_range + noise_dist.sample(&mut rng) + nlos_bias) as f32;

            // PDoA — in receiver body frame (i.e., relative to boat attitude)
            let peer_vec_world = Vec3::new(pj.x - pi.x, pj.y - pi.y, pj.z - pi.z);
            let az_true = peer_vec_world.y.atan2(peer_vec_world.x);
            let el_true = peer_vec_world.z.atan2((peer_vec_world.x.powi(2) + peer_vec_world.y.powi(2)).sqrt());
            let az_noise = Normal::new(0.0, cfg.sigma_azimuth_deg.to_radians()).unwrap().sample(&mut rng);
            let el_noise = Normal::new(0.0, cfg.sigma_elevation_deg.to_radians()).unwrap().sample(&mut rng);

            // CIR stats
            let (snr, fp_idx) = if nlos {
                let snr = Uniform::new(cfg.snr_nlos_db_min, cfg.snr_nlos_db_max).sample(&mut rng);
                let fp  = rng.gen_range(cfg.fp_index_nlos_min..=cfg.fp_index_nlos_max);
                (snr, fp)
            } else {
                let snr = Uniform::new(cfg.snr_los_db_min, cfg.snr_los_db_max).sample(&mut rng);
                let fp  = rng.gen_range(cfg.fp_index_los_min..=cfg.fp_index_los_max);
                (snr, fp)
            };

            peers.push(PeerReport {
                peer_id:     *nj,
                range_m:     measured_range,
                pdoa_az_rad: (az_true + az_noise) as f32,
                pdoa_el_rad: (el_true + el_noise) as f32,
                snr_db10:    (snr * 10.0) as i16,
                fp_index:    fp_idx,
                nlos,
            });
        }

        // Fix quality: penalize NLOS measurements
        let n_nlos = peers.iter().filter(|p| p.nlos).count();
        let n_total = peers.len();
        let fix_quality = if n_total == 0 { 0u8 } else {
            (70_u32.saturating_sub((n_nlos as u32 * 12)) + (n_total.min(8) as u32 * 4)).min(100) as u8
        };

        // EKF estimated position in line frame
        // In Phase 2: boat reports its EKF position (which here = GT + small noise)
        // In raw mode the hub receives PeerReports and does trilateration itself
        let boat = boats.iter().find(|b| b.node_id == *ni);
        let (x_line, y_line, vx_line, vy_line, heading, gt_y) = if let Some(b) = boat {
            let ekf_noise_m = Normal::new(0.0, 0.04).unwrap();  // 4cm EKF residual
            let gt_y = b.cog.y as f32;  // approximate GT as CoG y (close enough for sim)
            (
                b.cog.x as f32,
                (b.cog.y + ekf_noise_m.sample(&mut rng)) as f32,
                b.vel.x as f32,
                b.vel.y as f32,
                b.heading_deg as f32,
                gt_y,
            )
        } else {
            (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        };

        measurements.push(EpochMeasurement {
            node_id:    *ni,
            seq_num:    seq_val,
            designation: *desig_i,
            battery_pct: *batt_i,
            x_line_m:   x_line,
            y_line_m:   y_line,
            vx_line_mps: vx_line,
            vy_line_mps: vy_line,
            heading_deg: heading,
            fix_quality,
            batch_mode,
            peers,
            gt_y_line_m: gt_y,
        });
    }

    measurements
}
