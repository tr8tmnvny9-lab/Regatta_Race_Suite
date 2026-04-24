// TrackerEndpointConfig.swift
//
// Production-ready endpoint resolver for the iOS Tracker.
// Reads from two sources in priority order:
//   1. UserDefaults (set via SettingsSheet in the app)
//   2. Info.plist build-time config (injected by Xcode build settings from AWS SSM)
//
// In the Nokia SNPN (Edge) configuration, the backend is on the local Nokia DAC.
// In the Standard (Cellular) configuration, it connects to AWS Fargate CloudVM.
//
// This replaces the previous hardcoded wss://regatta-backend-oscar.fly.dev URL.

import Foundation

enum TrackerNetworkMode: String {
    case localEdge = "localEdge"   // Nokia SNPN — connects to local Rust backend
    case awsCloud  = "awsCloud"    // Standard / Cellular — connects to AWS Fargate
    case customQR  = "customQR"    // QR Setup — dynamically scanned endpoint
}

struct TrackerEndpointConfig {

    // ── Priority 1: UserDefaults (set at runtime from SettingsSheet) ──────────
    
    static var preferredMode: TrackerNetworkMode {
        let raw = UserDefaults.standard.string(forKey: "trackerNetworkMode") ?? "localEdge"
        return TrackerNetworkMode(rawValue: raw) ?? .localEdge
    }
    
    // ── Endpoint resolution ───────────────────────────────────────────────────
    
    /// Returns the WebSocket URL for the currently preferred backend.
    static var webSocketURL: URL {
        switch preferredMode {
        case .localEdge:
            return localEdgeWebSocketURL
        case .awsCloud:
            return awsCloudWebSocketURL
        case .customQR:
            let override = UserDefaults.standard.string(forKey: "customWebSocketURL") ?? ""
            return URL(string: "\(override)/socket.io/?EIO=4&transport=websocket") ?? localEdgeWebSocketURL
        }
    }
    
    /// Local SNPN edge backend — the Nokia DAC-hosted Rust backend.
    /// Default is the committee boat's LAN IP; overrideable via UserDefaults.
    /// In simulator builds, defaults to localhost (127.0.0.1) for sidecar development.
    static var localEdgeWebSocketURL: URL {
        #if targetEnvironment(simulator)
        // Simulator connects to the Mac's Rust sidecar directly
        let host = "127.0.0.1"
        #else
        // Real device: natively resolve the host via Bonjour over USB-C or Wi-Fi
        let host = UserDefaults.standard.string(forKey: "localEdgeHost") ?? "oscars-macbook-pro-2.local"
        #endif
        let port = UserDefaults.standard.string(forKey: "localEdgePort") ?? "3001"
        return URL(string: "ws://\(host):\(port)/socket.io/?EIO=4&transport=websocket")!
    }
    
    /// AWS Fargate CloudVM WebSocket endpoint.
    /// Read from Info.plist key `REGATTA_BACKEND_URL` first (set at build time).
    /// Falls back to UserDefaults override, then a compile-time placeholder.
    static var awsCloudWebSocketURL: URL {
        // Priority 1: Xcode Build Setting (from AWS SSM at CI time)
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "REGATTA_BACKEND_URL") as? String,
           !plistURL.isEmpty, plistURL != "$(REGATTA_BACKEND_URL)" {
            let wsURL = plistURL.replacingOccurrences(of: "https://", with: "wss://")
                                .replacingOccurrences(of: "http://", with: "ws://")
            return URL(string: "\(wsURL)/socket.io/?EIO=4&transport=websocket")!
        }
        
        // Priority 2: Runtime UserDefaults override (set in SettingsSheet)
        if let override = UserDefaults.standard.string(forKey: "awsCloudVMURL"), !override.isEmpty {
            let wsURL = override.replacingOccurrences(of: "https://", with: "wss://")
                                .replacingOccurrences(of: "http://", with: "ws://")
            return URL(string: "\(wsURL)/socket.io/?EIO=4&transport=websocket")!
        }
        
        // Priority 3: Production AWS default (update post-deployment)
        // ⚠️ Update this URL after running aws/002_kinesis_s3_config.sh and deploying Fargate.
        return URL(string: "wss://api.regatta.app/socket.io/?EIO=4&transport=websocket")!
    }

    // ── Save helpers (called from SettingsSheet) ──────────────────────────────

    static func setMode(_ mode: TrackerNetworkMode) {
        UserDefaults.standard.setValue(mode.rawValue, forKey: "trackerNetworkMode")
    }
    
    static func setLocalEdgeHost(_ host: String, port: String = "3001") {
        UserDefaults.standard.setValue(host, forKey: "localEdgeHost")
        UserDefaults.standard.setValue(port, forKey: "localEdgePort")
    }
    
    static func setAWSCloudURL(_ url: String) {
        UserDefaults.standard.setValue(url, forKey: "awsCloudVMURL")
    }
    
    // ── Description for UI ────────────────────────────────────────────────────

    static var currentEndpointDisplayName: String {
        switch preferredMode {
        case .localEdge:
            #if targetEnvironment(simulator)
            return "Local Simulator Core (127.0.0.1)"
            #else
            let host = UserDefaults.standard.string(forKey: "localEdgeHost") ?? "192.168.68.105"
            return "Nokia SNPN Edge (LAN: \(host))"
            #endif
        case .awsCloud:
            return "AWS Fargate Cloud (api.regatta.app)"
        case .customQR:
            let override = UserDefaults.standard.string(forKey: "customWebSocketURL") ?? "Unknown"
            return "QR Connected (\(override))"
        }
    }
}
