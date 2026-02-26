// RegattaTrackerApp.swift
// Regatta Tracker — iOS/iPadOS native sailor app entry point
//
// Architecture:
//  - Scans for the race session (QR code or pull from UserDefaults)
//  - Connects via ConnectionManager (LAN Bonjour → Cloud → Offline buffer)
//  - BLE GATT client scans for UWB node service on attached node
//  - SwiftUI HUD shows: DTL in cm, countdown, active flags, OCS alert
//
// Core Invariant #4: Native iOS — CoreBluetooth, CoreLocation, CoreMotion
// Core Invariant #1: 1 cm accuracy from UWB GATT stream

import SwiftUI

@main
struct RegattaTrackerApp: App {
    @StateObject private var authManager = SupabaseAuthManager()
    @StateObject private var connection = TrackerConnectionManager()
    @StateObject private var bleClient  = UWBNodeBLEClient()
    @StateObject private var location   = LocationManager()
    @StateObject private var race       = RaceStateModel()
    @StateObject private var haptics    = HapticManager()

    var body: some Scene {
        WindowGroup {
            TrackerRootView()
                .environmentObject(authManager)
                .environmentObject(connection)
                .environmentObject(bleClient)
                .environmentObject(location)
                .environmentObject(race)
                .environmentObject(haptics)
                .preferredColorScheme(.dark)
                .onAppear {
                    connection.start()
                    bleClient.start()
                    location.start()
                }
        }
    }
}

// ─── Root view ────────────────────────────────────────────────────────────────

struct TrackerRootView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var race: RaceStateModel
    @State private var showJoin = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                LoginView()
            } else if connection.sessionId == nil {
                JoinView(showSheet: $showJoin)
            } else {
                StartLineView()
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinView(showSheet: $showJoin)
        }
    }
}
