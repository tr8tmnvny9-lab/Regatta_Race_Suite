// MainHUDView.swift
// Regatta Tracker — The operational operational core HUD for the sailor.

import SwiftUI

struct MainHUDView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var race: RaceStateModel
    @EnvironmentObject var bleClient: UWBNodeBLEClient
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var haptics: HapticManager
    
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // 1. Edge-to-edge animated background
            AnimatedWaveBackground()
            
            // 2. OCS Violation Flash Overlay
            if let dtl = bleClient.dtlCm, dtl > 10.0 {
                Color.red.opacity(0.3)
                    .onAppear { haptics.playOCSHaptic() }
            }
            
            // 3. Main Data Stack
            VStack(spacing: 0) {
                // Top Status Bar
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        AnimatedPulseDot(color: connection.isConnected ? .statusRacing : .statusError)
                        Text(connection.isConnected ? "LIVE" : "OFFLINE")
                            .font(RegattaFont.label(9))
                            .foregroundColor(.white)
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .trueLiquidGlass(cornerRadius: 14)
                    
                    HStack(spacing: 4) {
                        Text("⚡")
                        Text("12ms")
                            .font(RegattaFont.mono(9))
                    }
                    .foregroundColor(.cyanAccent)
                    
                    Spacer()
                    
                    Text(race.currentPhase.rawValue)
                        .font(RegattaFont.label(9))
                        .foregroundColor(phaseColor)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .trueLiquidGlass(cornerRadius: 14)

                    Text(currentTimeString)
                        .font(RegattaFont.mono(10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // NEW: Settings Button on the right
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .trueLiquidGlass(cornerRadius: 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                
                Spacer()
                
                // Hero Identity Card
                VStack(spacing: 12) {
                    if let team = race.assignedTeamName {
                        Text(team.uppercased())
                            .font(RegattaFont.heroRounded(48))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 60, height: 1)
                        
                        Text(race.assignedBoatNumber)
                            .font(RegattaFont.heroRounded(32))
                            .foregroundColor(.cyanAccent)
                        
                        Text("CONFIRM YOUR BOAT")
                            .font(RegattaFont.label(10))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                    } else {
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .frame(maxWidth: 240)
                                .frame(height: 40)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .frame(maxWidth: 160)
                                .frame(height: 20)
                        }
                        .shimmer()
                        
                        Text("AWAITING TEAM ASSIGNMENT")
                            .font(RegattaFont.label(10))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .trueLiquidGlass(cornerRadius: 32)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Countdown
                if race.currentPhase != .idle && race.currentPhase != .racing {
                    CountdownView(timeRemaining: race.timeRemaining, phase: race.currentPhase)
                        .padding(.bottom, 24)
                }
                
                // Navigation Data cards
                HStack(spacing: 12) {
                    // Heading & Speed (Side-by-Side)
                    HStack(spacing: 0) {
                        // Heading
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEADING")
                                .font(RegattaFont.label(9))
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(Int(location.headingDegrees))°")
                                    .font(RegattaFont.data(32))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                                CompassArrow(degrees: location.headingDegrees)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                        
                        // Speed
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SPEED")
                                .font(RegattaFont.label(9))
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", location.speedKnots))
                                    .font(RegattaFont.data(32))
                                    .foregroundColor(.cyanAccent)
                                Text("kn")
                                    .font(RegattaFont.heroRounded(10))
                                    .foregroundColor(.cyanAccent.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .trueLiquidGlass(cornerRadius: 24)
                    
                    // DTL
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIST TO LINE")
                            .font(RegattaFont.label(10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        if let dtlCm = bleClient.dtlCm {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", dtlCm / 100))
                                    .font(RegattaFont.data(32))
                                    .foregroundColor(dtlColor(dtlCm))
                                    .minimumScaleFactor(0.5)
                                Text("m")
                                    .font(RegattaFont.heroRounded(12))
                                    .foregroundColor(dtlColor(dtlCm))
                            }
                            Text(dtlCm < 0 ? "OCS" : "CLEAR")
                                .font(RegattaFont.heroRounded(11))
                                .foregroundColor(dtlColor(dtlCm).opacity(0.8))
                                .lineLimit(1)
                        } else {
                            Text("---")
                                .font(RegattaFont.display(32))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 110)
                    .trueLiquidGlass(cornerRadius: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34) // Adjust for Home Indicator
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }
    
    private var phaseColor: Color {
        switch race.currentPhase {
        case .racing: return .statusRacing
        case .warming, .prep, .oneMinute: return .statusWarn
        case .postponed, .abandoned: return .statusError
        default: return .white.opacity(0.6)
        }
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: Date())
    }
    
    private func dtlColor(_ dtlCm: Double) -> Color {
        if dtlCm < 0 { return .statusError }
        if dtlCm < 1000 { return .statusWarn }
        return .white
    }
    
    private func cardinalDirection(_ heading: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((heading + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return directions[index]
    }
}
