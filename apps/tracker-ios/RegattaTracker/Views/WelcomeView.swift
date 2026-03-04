// WelcomeView.swift
// Regatta Tracker — First screen after login.

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var showContent = false
    @State private var navigateToConfig = false
    @State private var selectedMode: ConfigurationMode?

    enum ConfigurationMode {
        case manual, automatic
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedWaveBackground()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo Identity
                    VStack(spacing: 16) {
                        Image(systemName: "sailboat.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .foregroundColor(.cyanAccent)
                            .shadow(color: .cyanAccent.opacity(0.6), radius: 12)
                            .scaleEffect(showContent ? 1.0 : 0.8)
                            .opacity(showContent ? 1.0 : 0)
                        
                        VStack(spacing: 8) {
                            Text("Welcome, \(authManager.currentUser?.email?.components(separatedBy: "@").first ?? "Captain")")
                                .font(RegattaFont.heroRounded(32))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("To configure this tracker, choose a method below.")
                                .font(RegattaFont.bodyRounded(16))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1.0 : 0)
                    }
                    
                    // Mode Selection Cards
                    HStack(spacing: 20) {
                        // Manual Mode
                        Button {
                            selectMode(.manual)
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 42))
                                    .foregroundColor(.cyanAccent)
                                
                                VStack(spacing: 4) {
                                    Text("Manual")
                                        .font(RegattaFont.heroRounded(20))
                                        .foregroundColor(.white)
                                    Text("QR, ID, or browse")
                                        .font(RegattaFont.mono(11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .trueLiquidGlass(cornerRadius: 24)
                        }
                        .buttonStyle(GlassButtonStyle())
                        
                        // Automatic Mode
                        Button {
                            selectMode(.automatic)
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 42))
                                    .foregroundColor(.cyanAccent)
                                
                                VStack(spacing: 4) {
                                    Text("Automatic")
                                        .font(RegattaFont.heroRounded(20))
                                        .foregroundColor(.white)
                                    Text("Account sync")
                                        .font(RegattaFont.mono(11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .trueLiquidGlass(cornerRadius: 24)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .offset(y: showContent ? 0 : 40)
                    .opacity(showContent ? 1.0 : 0)
                    
                    Spacer()
                    
                    // Log out
                    Button {
                        Task { await authManager.signOut() }
                    } label: {
                        Text("Log out")
                            .font(RegattaFont.bodyRounded(14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showContent = true
                }
            }
            .navigationDestination(isPresented: $navigateToConfig) {
                if let mode = selectedMode {
                    ConfigurationView(initialMode: mode)
                }
            }
        }
    }

    private func selectMode(_ mode: ConfigurationMode) {
        selectedMode = mode
        authManager.hasSeenWelcome = true
        navigateToConfig = true
    }
}
