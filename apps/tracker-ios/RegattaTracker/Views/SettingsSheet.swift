// SettingsSheet.swift
// Regatta Tracker — Configuration and session management settings.

import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var bleClient: UWBNodeBLEClient
    @EnvironmentObject var raceState: RaceStateModel
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("uwbEmulatorEnabled") private var uwbEmulatorEnabled = false
    @State private var devTapCount = 0
    @State private var showDebugMenu = false

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Camera & Aim
                Section {
                    VStack(spacing: 16) {
                        // Media thumbnail / simulation
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 160)
                                .cornerRadius(12)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.2))
                            
                            VStack {
                                HStack {
                                    Text("HD 1080p")
                                        .font(RegattaFont.label(9))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.statusRacing)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(8)
                        }
                        
                        Button {
                            // Future: Open full screen camera aim
                        } label: {
                            HStack {
                                Image(systemName: "scope")
                                Text("Aim Camera & Check Quality")
                            }
                            .font(RegattaFont.heroRounded(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .trueLiquidGlass(cornerRadius: 14)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("TRACKER CAMERA")
                        .font(RegattaFont.label(11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Section 2: Connection & Backend
                Section {
                    LabeledContent {
                        Text(connection.sessionId ?? "None")
                            .font(RegattaFont.data(16))
                            .foregroundColor(.cyanAccent)
                            .tracking(1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } label: {
                        Text("Session ID")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    LabeledContent {
                        Text(bleClient.isConnected ? "Connected ✓" : "Scanning…")
                            .foregroundColor(bleClient.isConnected ? .statusRacing : .statusWarn)
                    } label: {
                        Text("UWB Node (Thunderbolt)")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Toggle(isOn: $raceState.isJuryMode) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jury Mode")
                                .foregroundColor(.white)
                            Text("Report as a Jury/Safety node")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .tint(.purple)
                } header: {
                    Text("HARDWARE STATUS")
                        .font(RegattaFont.label(11))
                        .foregroundColor(.white.opacity(0.4))
                        .onTapGesture {
                            devTapCount += 1
                            if devTapCount >= 7 {
                                showDebugMenu = true
                            }
                        }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // Hidden Debug Section
                if showDebugMenu {
                    Section {
                        Toggle(isOn: $uwbEmulatorEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable UWB Emulator (GPS Spline)")
                                    .foregroundColor(.statusWarn)
                                Text("Injects synthetic 20Hz packets into BLE layer.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .tint(.statusWarn)
                    } header: {
                        Text("DEVELOPER TOOLS")
                            .font(RegattaFont.label(11))
                            .foregroundColor(.statusWarn)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // Section: Backend Endpoint
                Section {
                    Picker("Network Mode", selection: Binding(
                        get: { TrackerEndpointConfig.preferredMode.rawValue },
                        set: { TrackerEndpointConfig.setMode(TrackerNetworkMode(rawValue: $0) ?? .awsCloud) }
                    )) {
                        Text("Nokia SNPN (Local Edge)").tag(TrackerNetworkMode.localEdge.rawValue)
                        Text("AWS CloudVM (Fargate)").tag(TrackerNetworkMode.awsCloud.rawValue)
                    }
                    .pickerStyle(.segmented)
                    
                    LabeledContent {
                        Text(TrackerEndpointConfig.currentEndpointDisplayName)
                            .font(RegattaFont.data(12))
                            .foregroundColor(.cyanAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    } label: {
                        Text("Active Endpoint")
                            .foregroundColor(.white.opacity(0.6))
                    }
                } header: {
                    Text("NETWORK & BACKEND")
                        .font(RegattaFont.label(11))
                        .foregroundColor(.white.opacity(0.4))
                } footer: {
                    Text("Set via Settings → Backend or Info.plist REGATTA_BACKEND_URL key at build time.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
                .listRowBackground(Color.white.opacity(0.05))

                // Section 3: Session
                Section {
                    Button(role: .destructive) {
                        connection.sessionId = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Disconnect from Race")
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                        }
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await authManager.signOut()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text("Log Out")
                            Spacer()
                            Image(systemName: "power")
                        }
                    }
                    
                    LabeledContent {
                        Text(connection.sessionId ?? "None")
                            .font(RegattaFont.data(16))
                            .foregroundColor(.cyanAccent)
                            .tracking(1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } label: {
                        Text("Session ID")
                            .font(RegattaFont.label(11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Spacer to prevent clipping at the bottom of the list
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("SESSION")
                        .font(RegattaFont.label(11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.oceanDeep.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 32)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(RegattaFont.label(12))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .trueLiquidGlass(cornerRadius: 14)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
