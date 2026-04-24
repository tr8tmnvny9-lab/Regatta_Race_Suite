// VirtualSailingView.swift
// Regatta Tracker — Joystick controller for virtual sailboat.

import SwiftUI
import CoreLocation

struct VirtualSailingView: View {
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var locationManager: LocationManager
    @ObservedObject var viewModel: VirtualSailingViewModel
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var liveStream: LiveStreamManager
    
    var body: some View {
        ZStack {
            AnimatedWaveBackground()
            
                VStack(spacing: 40) {
                    // Connectivity Status HUD
                    HStack {
                        Circle()
                            .fill(connection.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(connection.isConnected ? "CONNECTED TO ENGINE" : "DISCONNECTED")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(connection.isConnected ? .green : .red)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    // Connection Status
                    HStack {
                        Capsule()
                            .fill(connection.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: connection.isConnected ? .green : .red, radius: 4)
                        
                        Text(connection.isConnected ? "LIVE TELEMETRY" : "DISCONNECTED")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Header HUD
                    HStack(spacing: 20) {
                    TelemetryBlock(label: "HEADING", value: String(format: "%03d°", Int(viewModel.heading)))
                    TelemetryBlock(label: "SPEED", value: String(format: "%.1f", viewModel.speedKnots), unit: "KTS")
                    TelemetryBlock(label: "ROLL", value: String(format: "%d°", Int(viewModel.roll)))
                    TelemetryBlock(label: "TWA", value: String(format: "%d°", Int(viewModel.twa)))
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Wind Indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.cyanAccent)
                        .rotationEffect(.degrees(viewModel.virtualWindDir - viewModel.heading))
                    
                    Text("N")
                        .font(RegattaFont.label(12))
                        .foregroundColor(.white.opacity(0.4))
                        .offset(y: -70)
                }
                
                // Joystick
                JoystickView(offset: $viewModel.joystickOffset)
                    .frame(width: 200, height: 200)
                
                // Speed Slider
                VStack(spacing: 12) {
                    Text("SPEED CONTROL")
                        .font(RegattaFont.label(12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Slider(value: $viewModel.speedKnots, in: 0...15)
                        .tint(.cyanAccent)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Quality of Life Buttons
                // Quality of Life Buttons
                HStack(spacing: 12) {
                    Button {
                        if let centroid = connection.raceState?.courseCentroid {
                            viewModel.warpToLocation(lat: centroid.lat, lon: centroid.lon)
                        } else {
                            viewModel.warpToLocation(lat: 60.1699, lon: 24.9384)
                        }
                    } label: {
                        Label("WARP TO COURSE", systemImage: "scope")
                            .font(.system(size: 10, weight: .bold))
                            .padding(8)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if liveStream.isStreaming {
                            liveStream.disconnect()
                        } else {
                            // Virtual simulator uses local bridge connection without credentials
                            liveStream.connect(channelARN: "virtual", token: "local", region: "local")
                        }
                    } label: {
                        Label(liveStream.isStreaming ? "STOP VIDEO" : "TX VIDEO", systemImage: liveStream.isStreaming ? "video.fill" : "video.slash")
                            .font(.system(size: 10, weight: .bold))
                            .padding(8)
                            .background(liveStream.isStreaming ? Color.red.opacity(0.8) : Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 10)
                
                // Exit Button
                Button {
                    viewModel.stop()
                    connection.virtualSailingModel = nil
                    dismiss()
                } label: {
                    Text("EXIT SIMULATION")
                        .font(RegattaFont.heroRounded(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .trueLiquidGlass(cornerRadius: 16)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            connection.virtualSailingModel = viewModel
            if connection.sessionId == nil {
                print("📍 Sim Spawn: No active session. Auto-joining 'virtual-dev' session to force connection.")
                connection.joinSession(id: "virtual-dev")
            }
            attemptSpawn()
        }
        .onChange(of: connection.raceState?.course.marks) { oldMarks, newMarks in
            // If the course loads from the committee boat, and we are not near the course, warp there.
            if let first = newMarks?.first {
                let dist = abs(viewModel.latitude - first.pos.lat) + abs(viewModel.longitude - first.pos.lon)
                if dist > 0.05 { attemptSpawn() }
            } else if viewModel.latitude == 60.1699 && viewModel.longitude == 24.9384 {
                attemptSpawn()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    private func attemptSpawn() {
        // 1. Attempt to spawn at the mathematical centroid of the active race course boundary
        if let centroid = connection.raceState?.courseCentroid {
            print("📍 Sim Spawn: Starting at course centroid: \(centroid.lat), \(centroid.lon)")
            viewModel.start(initialLocation: CLLocationCoordinate2D(latitude: centroid.lat, longitude: centroid.lon))
            viewModel.virtualWindDir = connection.raceState?.twd ?? 0.0
            return
        }

        // 2. Fallback to a starting mark
        if let marks = connection.raceState?.course.marks, !marks.isEmpty {
            if let startMark = marks.first(where: { 
                $0.type == .start || 
                $0.name.lowercased().contains("start") || 
                $0.name.lowercased().contains("pin") || 
                $0.name.lowercased().contains("committee") 
            }) {
                print("📍 Sim Spawn: Starting at course mark: \(startMark.name)")
                viewModel.start(initialLocation: CLLocationCoordinate2D(latitude: startMark.pos.lat, longitude: startMark.pos.lon))
                viewModel.virtualWindDir = connection.raceState?.twd ?? 0.0
                return
            } else if let firstMark = marks.first {
                print("📍 Sim Spawn: Starting at first course mark: \(firstMark.name)")
                viewModel.start(initialLocation: CLLocationCoordinate2D(latitude: firstMark.pos.lat, longitude: firstMark.pos.lon))
                viewModel.virtualWindDir = connection.raceState?.twd ?? 0.0
                return
            }
        }
        
        // 3. Fallback to current GPS location
        if let loc = locationManager.currentPosition {
            print("📍 Sim Spawn: Fallback to GPS: \(loc.latitude), \(loc.longitude)")
            viewModel.start(initialLocation: loc)
        } else {
            print("📍 Sim Spawn: Default Helsinki")
            viewModel.start(initialLocation: nil)
        }
    }
}

struct TelemetryBlock: View {
    let label: String
    let value: String
    var unit: String? = nil
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(RegattaFont.label(10))
                .foregroundColor(.white.opacity(0.4))
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(RegattaFont.data(20))
                    .foregroundColor(.white)
                if let unit = unit {
                    Text(unit)
                        .font(RegattaFont.label(8))
                        .foregroundColor(.cyanAccent)
                        .padding(.bottom, 2)
                }
            }
        }
        .frame(minWidth: 70)
        .padding(10)
        .glassCard(cornerRadius: 12)
    }
}

struct JoystickView: View {
    @Binding var offset: CGPoint
    @State private var dragPosition: CGPoint = .zero
    private let limit: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                .frame(width: 180, height: 180)
            
            // Inner Knob
            Circle()
                .fill(RadialGradient(colors: [.cyanAccent, .blue], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 70, height: 70)
                .shadow(color: .cyanAccent.opacity(0.5), radius: 10)
                .offset(x: dragPosition.x, y: dragPosition.y)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dist = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            let scale = min(dist, limit) / dist
                            
                            if dist > 0 {
                                dragPosition = CGPoint(
                                    x: value.translation.width * scale,
                                    y: value.translation.height * scale
                                )
                            }
                            
                            // Normalize to -1.0 ... 1.0
                            offset = CGPoint(
                                x: dragPosition.x / limit,
                                y: dragPosition.y / limit
                            )
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                dragPosition = .zero
                                offset = .zero
                            }
                        }
                )
        }
    }
}
