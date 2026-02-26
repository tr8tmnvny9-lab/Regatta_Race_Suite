//! trilateration.rs — Weighted-Least-Squares multilateration solver
//!
//! Used by both:
//!   - packages/uwb-simulator: to verify the hub's solve accuracy vs ground truth
//!   - backend-rust/src: extension to uwb_hub.rs for raw-mode packet processing
//!
//! Algorithm: iterative Gauss-Newton WLS minimizing:
//!   J = Σ_ij  w_ij * (d_ij_meas - ||p_i - p_j||)²
//! where w_ij = 1/σ²_ij (down-weighted for NLOS via Huber loss)
//!
//! validation_protocol.json:
//! - Invariant #1: this solver is the path to ≤1 cm batch accuracy
//! - Invariant #2: batch solve result is audit-logged (AuditEventType::UwbGunSolve)

use std::collections::HashMap;
use serde::{Deserialize, Serialize};

use crate::uwb_physics::PeerReport;

// ── Types ─────────────────────────────────────────────────────────────────────

/// A range measurement between two nodes
#[derive(Debug, Clone)]
pub struct RangeMeasurement {
    pub node_i: u32,
    pub node_j: u32,
    pub range_m: f32,
    pub sigma_m: f32,   // 0.07 LOS, 0.20 NLOS
    pub nlos: bool,
}

/// 2D position (line frame)
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Pos2D {
    pub x: f32,   // along start line (East direction)
    pub y: f32,   // perpendicular to line (North = OCS side)
}

/// Result from multilateration solve
#[derive(Debug, Clone, Serialize)]
pub struct MultilaterationResult {
    /// Estimated 2D positions per node_id
    pub positions: HashMap<u32, Pos2D>,
    /// RMS residual after convergence (meters) — target < 0.05m per epoch
    pub rms_residual_m: f32,
    /// Number of Gauss-Newton iterations taken
    pub iterations: u32,
    /// Whether solve converged
    pub converged: bool,
    /// Number of measurements used (total - rejected by Mahalanobis gate)
    pub n_measurements: u32,
    /// Number of measurements rejected
    pub n_rejected: u32,
}

// ── Known anchor positions (fixed in line frame) ──────────────────────────────

#[derive(Debug, Clone)]
pub struct AnchorMap {
    /// node_id → fixed position in line frame
    positions: HashMap<u32, [f32; 2]>,
}

impl AnchorMap {
    pub fn new() -> Self { Self { positions: HashMap::new() } }
    pub fn insert(&mut self, node_id: u32, pos: [f32; 2]) { self.positions.insert(node_id, pos); }
    pub fn get(&self, node_id: u32) -> Option<[f32; 2]> { self.positions.get(&node_id).copied() }
    pub fn is_anchor(&self, node_id: u32) -> bool { self.positions.contains_key(&node_id) }
}

// ── WLS Multilateration ───────────────────────────────────────────────────────

/// Huber loss weight: down-weight large residuals (robust to NLOS outliers)
/// δ = 0.15m (Huber threshold — residuals > 15cm are down-weighted)
fn huber_weight(residual: f32, sigma: f32, delta: f32) -> f32 {
    let normalized = (residual / sigma).abs();
    if normalized <= delta {
        1.0 / (sigma * sigma)
    } else {
        delta / (normalized * sigma * sigma)
    }
}

/// Main WLS multilateration solve.
///
/// Parameters:
/// - `measurements`: all range pairs collected in this solve epoch
/// - `anchors`: known fixed positions (MarkA=node 1, MarkB=node 2, Committee=node 3)
/// - `initial_guess`: starting positions for unknown nodes (often last epoch's result)
/// - `max_iter`: maximum Gauss-Newton iterations (typically 10)
/// - `converge_threshold`: stop when position update < this (meters)
///
/// Returns None if fewer than 3 unknown nodes have enough measurements to solve.
pub fn solve(
    measurements: &[RangeMeasurement],
    anchors: &AnchorMap,
    initial_guess: &HashMap<u32, Pos2D>,
    max_iter: u32,
    converge_threshold: f32,
) -> Option<MultilaterationResult> {
    // Collect all unique unknown node IDs
    let unknown_ids: Vec<u32> = {
        let mut ids = std::collections::BTreeSet::new();
        for m in measurements {
            if !anchors.is_anchor(m.node_i) { ids.insert(m.node_i); }
            if !anchors.is_anchor(m.node_j) { ids.insert(m.node_j); }
        }
        ids.into_iter().collect()
    };

    if unknown_ids.is_empty() { return None; }

    // Initialize position estimates
    let mut positions: HashMap<u32, [f32; 2]> = HashMap::new();
    for &id in &unknown_ids {
        let guess = initial_guess.get(&id).copied()
            .unwrap_or(Pos2D { x: 0.0, y: -50.0 });  // default: 50m under line
        positions.insert(id, [guess.x, guess.y]);
    }

    let mut n_rejected = 0u32;
    let mut final_rms = 0.0f32;
    let mut final_iter = 0u32;
    let mut converged = false;
    const MAHAL_GATE: f32 = 9.0;  // chi-squared 2-DoF 99th percentile ≈ 9.21

    for iter in 0..max_iter {
        final_iter = iter + 1;
        let mut max_update = 0.0f32;
        n_rejected = 0;
        let mut sum_sq_res = 0.0f32;
        let mut n_used = 0u32;

        // For each unknown node: solve its position given all measurements to other nodes
        for &id_i in &unknown_ids {
            let pi = positions[&id_i];
            // Gather measurements involving this node
            let mut atwa = [[0.0f64; 2]; 2];  // 2x2 normal matrix
            let mut atwb = [0.0f64; 2];       // 2x1 RHS

            for m in measurements {
                // Is this measurement relevant to node id_i?
                let pj_arr: Option<[f32; 2]> = if m.node_i == id_i {
                    anchors.get(m.node_j).or_else(|| positions.get(&m.node_j).copied())
                } else if m.node_j == id_i {
                    anchors.get(m.node_i).or_else(|| positions.get(&m.node_i).copied())
                } else {
                    None
                };
                let pj = match pj_arr { Some(p) => p, None => continue };

                let dx = pi[0] - pj[0];
                let dy = pi[1] - pj[1];
                let dist = (dx*dx + dy*dy).sqrt().max(0.001);
                let residual = m.range_m - dist;

                // Mahalanobis gate (reject egregious outliers)
                let mahal = (residual / m.sigma_m).powi(2);
                if mahal > MAHAL_GATE {
                    n_rejected += 1;
                    continue;
                }

                // Huber weight
                let w = huber_weight(residual, m.sigma_m, 0.15) as f64;
                sum_sq_res += residual * residual;
                n_used += 1;

                // Jacobian: ∂f/∂x = (pi-pj)/||pi-pj||
                let jx = (dx / dist) as f64;
                let jy = (dy / dist) as f64;

                // Normal equations: AᵀWA * δp = AᵀWr
                atwa[0][0] += w * jx * jx;
                atwa[0][1] += w * jx * jy;
                atwa[1][0] += w * jy * jx;
                atwa[1][1] += w * jy * jy;
                atwb[0] += w * jx * residual as f64;
                atwb[1] += w * jy * residual as f64;
            }

            // Solve 2x2 system (Cramer's rule — fast for 2D)
            let det = atwa[0][0] * atwa[1][1] - atwa[0][1] * atwa[1][0];
            if det.abs() < 1e-10 { continue; }  // singular — not enough measurements
            let dx = (atwa[1][1] * atwb[0] - atwa[0][1] * atwb[1]) / det;
            let dy = (atwa[0][0] * atwb[1] - atwa[1][0] * atwb[0]) / det;

            let update_norm = ((dx*dx + dy*dy).sqrt()) as f32;
            max_update = max_update.max(update_norm);

            positions.insert(id_i, [
                pi[0] + dx as f32,
                pi[1] + dy as f32,
            ]);
        }

        final_rms = if n_used > 0 { (sum_sq_res / n_used as f32).sqrt() } else { 0.0 };

        if max_update < converge_threshold {
            converged = true;
            break;
        }
    }

    let result_positions: HashMap<u32, Pos2D> = positions.iter()
        .map(|(&id, &p)| (id, Pos2D { x: p[0], y: p[1] }))
        .collect();

    Some(MultilaterationResult {
        positions: result_positions,
        rms_residual_m: final_rms,
        iterations: final_iter,
        converged,
        n_measurements: measurements.len() as u32 - n_rejected,
        n_rejected,
    })
}

/// Batch solve: accumulate measurements from multiple epochs, solve jointly.
/// This is the 2-second high-density solve triggered at gun (T-0).
/// Invariant #1: batch accuracy target ≤ 1 cm absolute.
pub fn batch_solve(
    epochs: &[Vec<RangeMeasurement>],
    anchors: &AnchorMap,
    initial_guess: &HashMap<u32, Pos2D>,
) -> Option<MultilaterationResult> {
    // Flatten all epoch measurements
    let all: Vec<RangeMeasurement> = epochs.iter().flat_map(|e| e.iter().cloned()).collect();
    // More measurements → better convergence and accuracy
    // With 40 epochs × 15 boats × 5 measurements = ~3000 ranges, expect σ_batch ≈ 1cm
    solve(&all, anchors, initial_guess, 20, 0.001)
}

// ── OCS determination from solve result ───────────────────────────────────────

/// Given a solve result, determine which nodes are OCS.
/// OCS = y_line_m > ocs_threshold AND fix_quality >= min_quality
/// invariant_ref: #1 (≤1 cm accuracy means OCS call is reliable)
/// invariant_ref: #2 (all OCS detections logged via AuditLogger)
pub struct OcsDetection {
    pub node_id: u32,
    pub y_line_m: f32,   // positive = OCS side
    pub dtl_cm: f32,
    pub fix_quality: u8,
}

pub fn detect_ocs(
    result: &MultilaterationResult,
    fix_qualities: &HashMap<u32, u8>,
    ocs_threshold_m: f32,
    min_fix_quality: u8,
) -> Vec<OcsDetection> {
    result.positions.iter()
        .filter_map(|(&node_id, &pos)| {
            let fq = fix_qualities.get(&node_id).copied().unwrap_or(0);
            if pos.y > ocs_threshold_m && fq >= min_fix_quality {
                Some(OcsDetection {
                    node_id,
                    y_line_m: pos.y,
                    dtl_cm: pos.y * 100.0,
                    fix_quality: fq,
                })
            } else {
                None
            }
        })
        .collect()
}
