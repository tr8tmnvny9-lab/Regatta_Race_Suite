// CountdownView.swift
// Start sequence countdown display.
//
// Shows large digital countdown with:
//   - T-5:00 (Idle): white
//   - T-5:00 → T-1:00 (Warning to Prep): yellow
//   - T-1:00 → T-0 (One Minute): orange
//   - T-0 (Gun / Racing): green flash then settled
// Hides when race is not in a timed phase.

import SwiftUI

enum RacePhase: String {
    case idle       = "IDLE"
    case warming    = "WARNING"
    case prep       = "PREP"
    case oneMinute  = "ONE_MINUTE"
    case racing     = "RACING"
    case postponed  = "POSTPONED"
    case abandoned  = "ABANDONED"
}

struct CountdownView: View {
    let timeRemaining: Double  // seconds
    let phase: RacePhase

    var body: some View {
        VStack(spacing: 4) {
            // Phase label
            Text(phaseLabel)
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(phaseColor.opacity(0.7))
                .textCase(.uppercase)

            // Large countdown
            if phase == .racing {
                Text("RACING")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
            } else if phase == .abandoned {
                Text("ABANDONED")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.red)
            } else if timeRemaining > 0 {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundStyle(phaseColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: timeRemaining)
            }
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .idle:       return "Standby"
        case .warming:    return "Warning"
        case .prep:       return "Preparatory"
        case .oneMinute:  return "One Minute"
        case .racing:     return "Racing"
        case .postponed:  return "Postponed"
        case .abandoned:  return "Abandoned"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .idle:       return .white.opacity(0.4)
        case .warming:    return .white
        case .prep:       return .yellow
        case .oneMinute:  return .orange
        case .racing:     return .green
        case .postponed:  return .yellow.opacity(0.6)
        case .abandoned:  return .red.opacity(0.7)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let m = s / 60
        let rem = s % 60
        return String(format: "%d:%02d", m, rem)
    }
}
