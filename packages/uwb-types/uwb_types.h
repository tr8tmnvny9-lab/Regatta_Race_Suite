// uwb_types.h
// Auto-generated C header for Swift interop (BLE GATT, Mac sidecar)
// DO NOT EDIT — generated from packages/uwb-types/src/lib.rs
// Swift usage: import uwb_types; let pos = NodePosition2D()

#pragma once
#include <stdint.h>
#include <stdbool.h>

// ── Node designation ──────────────────────────────────────────────────────────
typedef enum __attribute__((packed)) {
    NODE_DESIGNATION_BOAT      = 0,
    NODE_DESIGNATION_MARK_A    = 1,
    NODE_DESIGNATION_MARK_B    = 2,
    NODE_DESIGNATION_COMMITTEE = 3,
} NodeDesignation;

// ── Quaternion (IMU orientation) ─────────────────────────────────────────────
typedef struct {
    float x, y, z, w;
} Quat;

// ── 3D vector (meters, world/body frame) ─────────────────────────────────────
typedef struct {
    float x, y, z;
} Vec3;

// ── 2D vector (meters, line frame) ───────────────────────────────────────────
typedef struct {
    float x, y;
} Vec2;

// ── Per-peer ranging report (28 bytes) ───────────────────────────────────────
typedef struct __attribute__((packed)) {
    uint32_t peer_id;
    int32_t  range_mm;           // DS-TWR Euclidean range, millimeters
    int16_t  azimuth_deg10;      // PDoA azimuth × 10
    int16_t  elevation_deg10;    // PDoA elevation × 10
    uint16_t cir_snr_db10;       // CIR SNR × 10
    uint8_t  fp_index;           // First-path index (NLOS: high value)
    uint8_t  quality_flags;      // bit0=NLOS, bit1=multipath, bit2=STS_fail
} PeerReport;

// ── UWB Measurement Packet header (fixed portion) ────────────────────────────
typedef struct __attribute__((packed)) {
    uint32_t       node_id;
    uint64_t       tx_timestamp_ns;
    uint32_t       seq_num;
    NodeDesignation designation;
    uint16_t       battery_mv;
    uint8_t        node_flags;
    Quat           orientation;
    Vec3           ant_offset_body;  // body-frame antenna lever arm to CoG
    uint8_t        num_reports;      // number of PeerReport entries following
    // PeerReport reports[num_reports]  -- variable length
    // uint32_t crc32                  -- after last report
} MeasurementPacketHeader;

// ── Fused position per node (from hub → all clients) ─────────────────────────
typedef struct {
    uint32_t node_id;
    float    x_line_m;       // signed distance along line (MarkA→MarkB)
    float    y_line_m;       // perpendicular (positive = OCS side)
    float    vx_line_mps;    // velocity along line
    float    vy_line_mps;    // velocity perpendicular to line
    float    heading_deg;
    uint8_t  fix_quality;    // 0–100; OCS only called if ≥ 60
    bool     batch_mode;     // true = gun batch solve (1 cm), false = incremental (3–5 cm)
} NodePosition2D;

// ── Fused position packet header (from hub UDP multicast) ────────────────────
typedef struct {
    uint64_t epoch_ms;
    Vec3     mark_a_pos;
    Vec3     mark_b_pos;
    Vec2     line_origin;
    Vec2     line_dir_unit;
    bool     batch_mode;
    uint8_t  num_nodes;
    // NodePosition2D nodes[num_nodes]  -- variable length
} FusedPositionPacketHeader;

// ── OCS threshold constants ───────────────────────────────────────────────────
#define UWB_OCS_THRESHOLD_M    0.10f   // 10 cm over line
#define UWB_MIN_FIX_QUALITY    60      // minimum quality for OCS call
#define UWB_MAX_PEERS_PER_EPOCH 24
#define UWB_SUPERFRAME_MS       50
#define UWB_BURST_SUPERFRAME_MS 25     // at T-1:00 and during gun batch

// ── Helper: is this node OCS? ─────────────────────────────────────────────────
static inline bool uwb_is_ocs(const NodePosition2D* node) {
    return node->y_line_m > UWB_OCS_THRESHOLD_M &&
           node->fix_quality >= UWB_MIN_FIX_QUALITY;
}

// ── Helper: distance to line in cm ───────────────────────────────────────────
static inline float uwb_dtl_cm(const NodePosition2D* node) {
    return node->y_line_m * 100.0f;
}
