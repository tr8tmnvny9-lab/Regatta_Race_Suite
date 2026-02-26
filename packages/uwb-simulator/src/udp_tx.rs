//! udp_tx.rs — UDP transmitter for MeasurementPackets
//!
//! Sends simulated packets to the hub via:
//!   - Unicast: 127.0.0.1:5555 (local backend, always enabled)
//!   - Multicast: 239.255.0.1:5555 (when MULTICAST=true, mirrors real Ubiquiti AP relay)
//!
//! validation_protocol.json:
//! - Invariant #6: Ubiquiti 5 GHz WiFi backbone — multicast target matches real network
//! - Invariant #8: send errors are logged but never crash the sim

use std::net::UdpSocket;
use tracing::{debug, warn};

use crate::uwb_physics::EpochMeasurement;

pub struct UdpTransmitter {
    socket: UdpSocket,
    unicast_addr: String,
    multicast_addr: Option<String>,
}

impl UdpTransmitter {
    /// Create a transmitter.
    /// unicast_addr: always "127.0.0.1:5555" for local dev
    /// multicast_addr: Some("239.255.0.1:5555") for network testing
    pub fn new(unicast_addr: &str, multicast_addr: Option<&str>) -> Result<Self, std::io::Error> {
        let socket = UdpSocket::bind("0.0.0.0:0")?;
        socket.set_nonblocking(false)?;
        Ok(Self {
            socket,
            unicast_addr: unicast_addr.to_string(),
            multicast_addr: multicast_addr.map(|s| s.to_string()),
        })
    }

    /// Send all measurements from one epoch to the hub.
    /// invariant_ref: #8 — errors logged, never panic
    pub fn send_epoch(&self, measurements: &[EpochMeasurement]) {
        for m in measurements {
            self.send_measurement(m);
        }
    }

    fn send_measurement(&self, m: &EpochMeasurement) {
        // Build JSON envelope matching uwb_hub.rs UwbMeasurementEnvelope
        let payload = serde_json::json!({
            "node_id":     m.node_id,
            "seq_num":     m.seq_num,
            "designation": m.designation,
            "battery_pct": m.battery_pct,
            "x_line_m":    m.x_line_m,
            "y_line_m":    m.y_line_m,
            "vx_line_mps": m.vx_line_mps,
            "vy_line_mps": m.vy_line_mps,
            "heading_deg": m.heading_deg,
            "fix_quality": m.fix_quality,
            "batch_mode":  m.batch_mode,
            "lat":         null,
            "lon":         null,
            // Include raw peers for hub raw-mode trilateration (optional)
            "peers": m.peers.iter().map(|p| serde_json::json!({
                "peer_id":    p.peer_id,
                "range_m":    p.range_m,
                "pdoa_az":    p.pdoa_az_rad,
                "pdoa_el":    p.pdoa_el_rad,
                "snr_db10":   p.snr_db10,
                "fp_index":   p.fp_index,
                "nlos":       p.nlos,
            })).collect::<Vec<_>>(),
        });

        let bytes = match serde_json::to_vec(&payload) {
            Ok(b) => b,
            Err(e) => { warn!("UDP: serialize failed: {e}"); return; }
        };

        // Unicast to local hub
        if let Err(e) = self.socket.send_to(&bytes, &self.unicast_addr) {
            warn!("UDP: unicast send failed: {e}");
        } else {
            debug!("UDP → {} node_id={} y={:.2}m", self.unicast_addr, m.node_id, m.y_line_m);
        }

        // Optional multicast (mirrors real Ubiquiti AP relay behavior)
        if let Some(mc) = &self.multicast_addr {
            if let Err(e) = self.socket.send_to(&bytes, mc) {
                warn!("UDP: multicast send failed: {e}");
            }
        }
    }
}
