// SettingsSheet.swift
// Regatta Tracker — Configuration and session management settings.

import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var bleClient: UWBNodeBLEClient
    @Environment(\.dismiss) var dismiss

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

                // Section 2: Connection
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
                        Text(bleClient.isConnected ? "Connected" : "Scanning...")
                            .foregroundColor(bleClient.isConnected ? .statusRacing : .statusWarn)
                    } label: {
                        Text("UWB Node")
                            .foregroundColor(.white.opacity(0.6))
                    }
                } header: {
                    Text("NETWORK & HARDWARE")
                        .font(RegattaFont.label(11))
                        .foregroundColor(.white.opacity(0.4))
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
                            .font(RegattaFont.label(10))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
