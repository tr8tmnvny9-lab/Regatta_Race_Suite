// NotificationManager.swift
// macOS user notifications and alerts during a race.
//
// Sends native macOS notifications for:
//   - OCS detected (high priority, persistent)
//   - Race sequence started
//   - General Recall issued
//   - Cloud failover triggered (director awareness)
//   - Sidecar crash (actionable — prompt to restart)
//
// All notifications are non-blocking — never interrupts race flow (Invariant #8).

import Foundation
import UserNotifications
import OSLog

private let log = Logger(subsystem: "com.regatta.pro", category: "Notifications")

final class NotificationManager: ObservableObject {
    @Published var permissionGranted: Bool = false

    init() {
        requestPermission()
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async { self.permissionGranted = granted }
            if let error { log.error("Notification permission error: \(error)") }
        }
    }

    // ── Race Events ───────────────────────────────────────────────────────────

    func notifyOCSDetected(boatIds: [String]) {
        let body = boatIds.count == 1
            ? "Boat \(boatIds[0]) is over the start line"
            : "\(boatIds.count) boats are over the start line: \(boatIds.joined(separator: ", "))"
        send(
            id: "ocs-\(boatIds.joined(separator: "-"))",
            title: "⚠ OCS Detected",
            body: body,
            sound: .defaultCritical,
            interruption: .critical
        )
    }

    func notifySequenceStarted(sequenceName: String) {
        send(id: "seq-start", title: "🏁 Sequence Started", body: sequenceName)
    }

    func notifyGeneralRecall() {
        send(id: "general-recall", title: "🚨 General Recall",
             body: "First Substitute flag raised — return to start", sound: .defaultCritical)
    }

    func notifyCloudFailover() {
        send(id: "cloud-failover", title: "☁ Switched to Cloud",
             body: "Local backend lost — connected to Fly.io cloud backend")
    }

    func notifySidecarCrash() {
        send(id: "sidecar-crash", title: "⚡ Race Engine Crashed",
             body: "Attempting to restart automatically...")
    }

    // ── Internal sender ───────────────────────────────────────────────────────

    private func send(
        id: String,
        title: String,
        body: String,
        sound: UNNotificationSound = .default,
        interruption: UNNotificationInterruptionLevel = .active
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.interruptionLevel = interruption

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil   // immediate delivery
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { log.error("Notification failed: \(error)") }
        }
    }
}
