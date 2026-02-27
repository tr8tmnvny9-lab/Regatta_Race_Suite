// RegattaProApp.swift
// Regatta Pro — macOS application entry point
//
// Architecture:
//  - App.swift starts the embedded Rust sidecar (SidecarManager)
//  - Once sidecar is ready, ContentView loads WKWebView pointing at localhost:3001/app
//  - Network monitor (ConnectionManager) switches between LAN, cloud, offline
//  - AuditLogger is always running (in the sidecar), results visible in Jury tab
//
// Phase 3 target: macOS 14+ (Sonoma), Apple Silicon + Intel universal binary

import SwiftUI
import Combine
import Network
import OSLog

private let log = Logger(subsystem: "com.regatta.pro", category: "App")

// ─── App ─────────────────────────────────────────────────────────────────────

@main
struct RegattaProApp: App {
    @StateObject private var authManager = SupabaseAuthManager()
    @StateObject private var sidecar = SidecarManager()
    @StateObject private var connection = ConnectionManager()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var udpListener = UDPListener()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(sidecar)
                .environmentObject(connection)
                .environmentObject(notifications)
                .environmentObject(udpListener)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            RegattaMenuCommands(sidecar: sidecar, connection: connection)
        }
    }
}

// ─── Root View (shows loading until sidecar is ready) ────────────────────────

struct RootView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var sidecar: SidecarManager
    @EnvironmentObject var connection: ConnectionManager

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                LoginView()
            } else if sidecar.status == .ready {
                ContentView()
            } else {
                SidecarLoadingView()
            }
        }
        .onAppear {
            sidecar.start()
            connection.start()
            udpListener.start()
        }
    }
}

// ─── Loading screen ───────────────────────────────────────────────────────────

struct SidecarLoadingView: View {
    @EnvironmentObject var sidecar: SidecarManager
    @State private var dotCount = 1
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "sailboat.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Regatta Pro")
                    .font(.system(size: 32, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .onReceive(timer) { _ in dotCount = (dotCount % 3) + 1 }
                if case .failed(let err) = sidecar.status {
                    Text("⚠ \(err)")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }

    private var statusText: String {
        switch sidecar.status {
        case .idle:      return "Initializing" + String(repeating: ".", count: dotCount)
        case .starting:  return "Starting race engine" + String(repeating: ".", count: dotCount)
        case .ready:     return "Ready"
        case .failed:    return "Failed to start"
        }
    }
}
