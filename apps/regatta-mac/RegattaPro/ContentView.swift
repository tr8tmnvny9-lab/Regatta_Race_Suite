// ContentView.swift
// WKWebView wrapper for the React frontend.
//
// In development: loads http://localhost:3000 (Vite dev server)
// In production app bundle: loads the built frontend from localhost:3001/app
//
// Features:
// - Native macOS toolbar showing connection mode (LAN/Cloud/Offline)
// - Retry button if the page fails to load (sidecar startup race condition)
// - JavaScript bridge for native features (notifications, haptics, menus)

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var sidecar: SidecarManager
    @EnvironmentObject var authManager: SupabaseAuthManager

    var body: some View {
        ZStack {
            MainLayoutView()

            // Connection status bar (overlaid at top)
            VStack {
                ConnectionStatusBar()
                Spacer()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Label("Regatta Pro", systemImage: "sailboat.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            ToolbarItem(placement: .status) {
                Text(connection.modeLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            ToolbarItem(placement: .status) {
                if connection.latencyMs > 0 {
                    Text(String(format: "%.0f ms", connection.latencyMs))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}



// ─── Connection status bar ────────────────────────────────────────────────────

struct ConnectionStatusBar: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var visible = true

    var body: some View {
        if connection.mode == .offline {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("No connection — data may be stale")
                Spacer()
                Button("Retry") { connection.start() }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.85))
            .foregroundStyle(.white)
            .font(.system(size: 12, weight: .medium))
        }
    }
}


