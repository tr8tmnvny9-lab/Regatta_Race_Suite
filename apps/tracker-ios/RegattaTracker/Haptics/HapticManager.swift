// HapticManager.swift
// Haptic feedback patterns for race events.
//
// Patterns follow RRS 26 temporal structure:
//   T-5 to T-1: single taps (increasing intensity approaching T-0)
//   T-0 (gun): double heavy impact
//   OCS: repeating heavy impact pattern × 3 + sustained vibration
//   General Recall: long continuous pattern
//   Individual Recall (X flag): triple medium tap
//
// Core Invariant #9: Intuitive UX — haptics give sailors physical awareness
//   without needing to look at the screen.

import UIKit
import AVFoundation

final class HapticManager: ObservableObject {
    private let impact = UIImpactFeedbackGenerator(style: .heavy)
    private let light  = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private var lastCountdownTick: Int = -1

    init() {
        // Pre-warm generators to reduce latency at critical moments
        impact.prepare()
        medium.prepare()
        notification.prepare()
    }

    // ─── Countdown ticks ──────────────────────────────────────────────────────

    func countdownTick(secondsRemaining: Int) {
        guard secondsRemaining != lastCountdownTick else { return }
        lastCountdownTick = secondsRemaining

        switch secondsRemaining {
        case 300:  // T-5:00 — warning signal
            notification.notificationOccurred(.warning)
        case 240:  // T-4:00 — preparatory signal
            medium.impactOccurred(intensity: 0.6)
        case 60:   // T-1:00 — one minute
            impact.impactOccurred(intensity: 0.8)
        case 30:   // T-30s
            medium.impactOccurred()
        case 10, 9, 8, 7, 6:  // Last 10s — every second
            light.impactOccurred(intensity: 0.5)
        case 5:
            medium.impactOccurred(intensity: 0.7)
        case 4:
            medium.impactOccurred(intensity: 0.75)
        case 3:
            impact.impactOccurred(intensity: 0.8)
        case 2:
            impact.impactOccurred(intensity: 0.9)
        case 1:
            impact.impactOccurred(intensity: 1.0)
        case 0:  // GUN — 2 heavy impacts
            gunHaptic()
        default:
            break
        }
    }

    // ─── Gun signal ───────────────────────────────────────────────────────────

    func gunHaptic() {
        impact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.impact.impactOccurred(intensity: 1.0)
        }
    }

    // ─── OCS detected ─────────────────────────────────────────────────────────
    //  3× heavy impact over 600ms, unmistakable even in physical exertion

    func ocsHaptic() {
        let delays: [Double] = [0, 0.2, 0.4]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.impact.impactOccurred(intensity: 1.0)
            }
        }
    }

    // ─── General Recall ───────────────────────────────────────────────────────
    //  5× heavy impacts over 2s

    func generalRecallHaptic() {
        let delays: [Double] = [0, 0.35, 0.7, 1.05, 1.4]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.impact.impactOccurred(intensity: 1.0)
            }
        }
    }

    // ─── Individual Recall (X flag) ───────────────────────────────────────────

    func individualRecallHaptic() {
        let delays: [Double] = [0, 0.15, 0.30]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.medium.impactOccurred()
            }
        }
    }

    // ─── Penalty scored ───────────────────────────────────────────────────────

    func penaltyHaptic() {
        notification.notificationOccurred(.error)
    }
}
