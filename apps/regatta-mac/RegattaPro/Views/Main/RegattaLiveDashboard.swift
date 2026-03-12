import SwiftUI

/// The root presentation layer for the V3 SailGP-style Broadcast View.
/// Enforces a rigid, edge-to-edge layout separating Top, Bottom, Left, Right, and Center Stage zones.
struct RegattaLiveDashboard: View {
    @EnvironmentObject var raceState: RaceStateModel
    @Binding var isPresented: Bool
    
    
    // UI-isolated models
    @StateObject private var stageModel = BroadcastStageModel()
    
    // V5 Transitions
    @EnvironmentObject var raceStateModel: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var body: some View {
        ZStack {
            // Base layer: Exact Login Screen Waves
            AnimatedWaveBackground()
                .ignoresSafeArea()
            
            // Layout Grid
            VStack(spacing: 0) {
                // 1. Top Header (Centered logos)
                BroadcastTopBar(isPresented: $isPresented)
                    .frame(height: 60)
                    .padding(.horizontal, 24)
                
                // 2. Main Middle Row (3-Columns)
                HStack(alignment: .top, spacing: 16) {
                    // LEFT SIDEBAR (Digital Chrono + Lists)
                    VStack(spacing: 16) {
                        BroadcastSidebarModule(title: "Current race results", icon: "stopwatch") {
                            VStack(spacing: 12) {
                                // Simple Digital Clock for this side
                                Text(String(format: "%02d:%02d", Int(raceState.timeRemaining) / 60, Int(raceState.timeRemaining) % 60))
                                    .font(.system(size: 32, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                
                                Divider().background(.white.opacity(0.1))
                                
                                // Show waiting state if not racing, or live boats sorted by rank
                                if raceState.status == .idle || raceState.status == .warning || raceState.status == .preparatory || raceState.status == .oneMinute {
                                    Text("Waiting for race to start...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .padding(.vertical, 20)
                                } else {
                                    let sortedBoats = raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) })
                                    ForEach(sortedBoats.prefix(6)) { boat in
                                        SidebarBoatRow(boat: boat, rank: boat.rank)
                                    }
                                }
                            }
                        }
                        
                        BroadcastSidebarModule(title: "Race Data", icon: "chart.bar.fill") {
                            VStack(spacing: 8) {
                                TelemetryValue(label: "TWS", value: String(format: "%.1f", raceState.tws), unit: "kts", color: .white)
                                TelemetryValue(label: "TWD", value: "\(Int(raceState.twd))", unit: "°", color: .cyan)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(width: 250)
                    
                    // CENTER STAGE (The Action)
                    BroadcastCenterStage()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    // RIGHT SIDEBAR (Analog Chrono + Lists)
                    VStack(spacing: 16) {
                        BroadcastSidebarModule(title: "Regatta results", icon: "clock") {
                            VStack(spacing: 12) {
                                RegattaLiveAnalogChrono()
                                    .scaleEffect(0.8)
                                    .frame(height: 140)
                                
                                Divider().background(.white.opacity(0.1))
                                
                                // Mirror race results on right side (overall race replay state)
                                if raceState.status == .idle || raceState.status == .warning || raceState.status == .preparatory || raceState.status == .oneMinute {
                                    Text("Waiting for race to start...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .padding(.vertical, 20)
                                } else {
                                    let sortedBoats = raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) })
                                    ForEach(sortedBoats.prefix(4)) { boat in
                                        SidebarBoatRow(boat: boat, rank: boat.rank)
                                    }
                                }
                            }
                        }
                        
                        BroadcastSidebarModule(title: "Standings", icon: "trophy") {
                            VStack(spacing: 8) {
                                let validTeams = raceState.leagueTeams.filter { $0.ranking > 0 } // Using backend score/ranking mapping
                                
                                if validTeams.isEmpty {
                                    Text("Waiting for regatta to begin...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .padding(.vertical, 10)
                                } else {
                                    let sortedTeams = validTeams.sorted(by: { $0.ranking < $1.ranking })
                                    ForEach(sortedTeams.prefix(6)) { team in
                                        HStack {
                                            Text("\(team.ranking).").font(.caption.bold()).foregroundStyle(.white.opacity(0.6))
                                            Text(team.name.prefix(15)).font(.caption.bold()).foregroundStyle(.white).lineLimit(1)
                                            Spacer()
                                            Text("\(team.score) PTS").font(.caption.monospaced()).foregroundStyle(.cyan)
                                        }
                                    }
                                }
                            }
                        }
                        
                        BroadcastSidebarModule(title: "Feed Selector", icon: "square.grid.2x2") {
                            BroadcastFeedSelector()
                        }
                        
                        Spacer()
                    }
                    .frame(width: 250)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                // 3. Procedural Footer
                BroadcastProceduralFooter()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        }
        .environmentObject(stageModel)
        .onAppear {
            // Silence heavy main-app MapKit logic
            raceState.isBroadcastModeActive = true
        }
        .onDisappear {
            // Restore main-app logic
            raceState.isBroadcastModeActive = false
        }
    }
}

// ─── Background Layer (Deep Ocean) ───────────────

struct RegattaLiveDeepOceanBackground: View {
    @State private var waveOffset = Angle(degrees: 0)
    @State private var glowOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Very dark, deep sea blue base
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.02, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.4, blue: 0.7)
            ]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            // Depth Glows to make .ultraThinMaterial pop
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: glowOffset.width - 200, y: glowOffset.height - 200)
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: -glowOffset.width + 250, y: -glowOffset.height + 150)
            
            // Midground Waves
            LiveWaveShape(phase: CGFloat(waveOffset.radians), frequency: 1.5)
                .fill(Color.white.opacity(0.04))
                .ignoresSafeArea()
                .offset(y: 60)
            
            LiveWaveShape(phase: CGFloat(waveOffset.radians + .pi), frequency: 1.2)
                .fill(Color.cyan.opacity(0.06))
                .ignoresSafeArea()
                .offset(y: 80)
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                waveOffset = Angle(degrees: 360)
            }
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                glowOffset = CGSize(width: 100, height: 100)
            }
        }
    }
}

// Vector Wave Shape for infinite rolling background
struct LiveWaveShape: Shape {
    var phase: CGFloat
    var frequency: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * frequency * .pi * 2 + phase)
            let y = midHeight + sine * (height * 0.1)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}
