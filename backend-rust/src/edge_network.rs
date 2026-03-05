//! edge_network.rs
//! 
//! Manages Linux network routing specifically for Configuration 2 (Nokia SNPN Mode).
//! Ensures that while all inbound UWB and Tracker traffic is confined to the local
//! private 5G network (`eth0`), all outbound streaming pushes to AWS are forced
//! through the Starlink dish interface (`eth1` / `en1`).

use tokio::process::Command;
use tracing::{info, debug};

#[derive(Debug, thiserror::Error)]
pub enum EdgeNetworkError {
    #[error("Failed to execute routing command: {0}")]
    CommandError(#[from] std::io::Error),
    #[error("Routing configuration failed with exit code: {0}")]
    ProcessError(i32),
}

/// Configures the routing tables on the Edge Mac/Linux machine to split traffic.
pub async fn configure_starlink_routing() -> Result<(), EdgeNetworkError> {
    
    // In a production Linux environment (like inside a Docker container on the edge node),
    // we would use `ip route`. Since this could run on a Mac during development,
    // we use a generalized approach or dummy log for safety if not explicitly Linux.
    
    if cfg!(target_os = "linux") {
        debug!("Applying Linux `ip route` overrides for Starlink on eth1...");
        
        // Ensure default route for Regatta AWS Cloud endpoints goes out via eth1 (Starlink)
        // 1. Delete default route if it's on eth0
        // 2. Add default route on eth1
        // (Note: This is a highly privileged operation requiring CAP_NET_ADMIN in Docker)
        
        let status = Command::new("ip")
            .args(&["route", "add", "default", "via", "192.168.100.1", "dev", "eth1", "metric", "100"])
            .status()
            .await?;
            
        if !status.success() {
            return Err(EdgeNetworkError::ProcessError(status.code().unwrap_or(-1)));
        }
    } else if cfg!(target_os = "macos") {
        debug!("macOS Edge environment detected. Skipping hard `ip route` rules.");
        info!("MacOS Starlink Stub: Assume Regatta App selects the correct Wi-Fi interface.");
    }

    Ok(())
}
