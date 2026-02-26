// StartLineView.swift
// Primary race HUD for the Regatta Tracker app.
//
// Shows:
//   - Signed distance to start line in centimeters (large, color-coded)
//   - T-minus countdown timer
//   - Active flags (P, I, Z, X, AP, N)
//   - Heel/tilt indicator
//   - OCS full-screen flash if over the line
//   - Connection source (UWB GATT / GPS / Offline)
//
// Core Invariant #1: 1 cm accuracy displayed when UWB fix quality >= 60
// Core Invariant #9: Intuitive UX for high-pressure sailors

import SwiftUI
import CoreMotion

struct StartLineView: View {
    @EnvironmentObject var bleClient: UWBNodeBLEClient
    @EnvironmentObject var race: RaceStateModel
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var haptics: HapticManager

    @State private var showOCSOverlay = false
    @State private var heelAngle: Double = 0

    // Attitude manager for heel readout
    private let motionManager = CMMotionManager()

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar: flags + connection ─────────────────────────────
                HStack {
                    FlagRow(flags: race.activeFlags)
                    Spacer()
                    ConnectionBadge(bleState: bleClient.state, fixQuality: bleClient.fixQuality)
                }
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8)

                Divider().background(.white.opacity(0.1))

                // ── Countdown ───────────────────────────────────────────────
                CountdownView(timeRemaining: race.timeRemaining, phase: race.currentPhase)
                    .padding(.top, 20)

                // ── Distance to Line (main readout) ─────────────────────────
                DTLReadout(position: bleClient.position, gpsActive: location.isActive)
                    .padding(.top, 20)

                // ── Approach velocity bar ────────────────────────────────────
                if let pos = bleClient.position {
                    ApproachVelocityBar(vyMps: pos.vyLineMps)
                        .padding(.horizontal, 40)
                        .padding(.top, 12)
                }

                Spacer()

                // ── Heel indicator ───────────────────────────────────────────
                HeelIndicator(angle: heelAngle)
                    .padding(.bottom, 24)
            }

            // ── OCS overlay ──────────────────────────────────────────────────
            if showOCSOverlay {
                OCSOverlayView(onDismiss: { showOCSOverlay = false })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear { startMotion() }
        .onDisappear { motionManager.stopDeviceMotionUpdates() }
        .onChange(of: bleClient.position?.isOCS) { _, isOCS in
            if isOCS == true && !showOCSOverlay {
                showOCSOverlay = true
                haptics.ocsHaptic()
            } else if isOCS == false {
                showOCSOverlay = false
            }
        }
        .onChange(of: race.timeRemaining) { _, secs in
            haptics.countdownTick(secondsRemaining: Int(secs))
        }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let m = motion else { return }
            heelAngle = m.attitude.roll * 180 / .pi
        }
    }
}

// ─── Distance to Line readout ─────────────────────────────────────────────────

struct DTLReadout: View {
    let position: UWBPosition?
    let gpsActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let pos = position {
                // UWB mode — centimeter accuracy
                let cm = pos.dtlCm
                let isOver = pos.isOCS
                Text(String(format: "%+.1f cm", cm))
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundStyle(isOver ? .red : (abs(cm) < 50 ? .orange : .green))
                    .animation(.easeInOut(duration: 0.15), value: cm)
                Text(isOver ? "⚠ OVER THE LINE" : (cm < 0 ? "behind line" : "to line"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                QualityDots(quality: pos.fixQuality)
            } else if gpsActive {
                // GPS fallback — meters
                Text("GPS")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.yellow.opacity(0.6))
                Text("UWB node not found — GPS mode")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("—")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(.white.opacity(0.3))
                Text("No position data")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// ─── Fix quality dots ─────────────────────────────────────────────────────────

struct QualityDots: View {
    let quality: UInt8
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(Int(quality) > i * 20 ? .green : .white.opacity(0.2))
            }
            Text("\(quality)%")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// ─── Approach velocity bar ────────────────────────────────────────────────────

struct ApproachVelocityBar: View {
    let vyMps: Float   // positive = approaching line (OCS direction)
    var body: some View {
        VStack(spacing: 4) {
            Text("VMG: \(String(format: "%+.2f m/s", vyMps))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            GeometryReader { geo in
                ZStack(alignment: vyMps >= 0 ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .foregroundStyle(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .foregroundStyle(vyMps > 0 ? .red.opacity(0.6) : .green.opacity(0.6))
                        .frame(width: min(CGFloat(abs(vyMps)) / 3.0, 1.0) * geo.size.width)
                        .animation(.linear(duration: 0.1), value: vyMps)
                }
            }
            .frame(height: 8)
        }
    }
}

// ─── Heel indicator ───────────────────────────────────────────────────────────

struct HeelIndicator: View {
    let angle: Double
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.and.right.circle")
                .foregroundStyle(.white.opacity(0.4))
            Text(String(format: "%.1f°", angle))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// ─── OCS overlay ─────────────────────────────────────────────────────────────

struct OCSOverlayView: View {
    let onDismiss: () -> Void
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()
                .opacity(0.92)
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                Text("OVER THE LINE")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)
                Text("Return to start immediately")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
                Button("Acknowledge") { onDismiss() }
                    .foregroundStyle(.red)
                    .background(.white)
                    .clipShape(Capsule())
                    .padding(.top, 12)
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) { opacity = 1.0 }
        }
    }
}

// ─── Connection badge ─────────────────────────────────────────────────────────

struct ConnectionBadge: View {
    let bleState: UWBNodeBLEClient.BLEState
    let fixQuality: UInt8

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(bleState == .connected ? .green : .yellow)
            Text(bleState == .connected ? "UWB" : "GPS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

// ─── Flag row ──────────────────────────────────────────────────────────────────

struct FlagRow: View {
    let flags: [String]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(flags, id: \.self) { flag in
                FlagChip(label: flag)
            }
        }
    }
}

struct FlagChip: View {
    let label: String
    var color: Color {
        switch label {
        case "P": return .blue
        case "I": return .yellow
        case "Z": return .yellow
        case "X": return .white
        case "AP", "N": return .red
        default: return .gray
        }
    }
    var body: some View {
        Text(label)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(label == "X" ? .black : .white)
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
