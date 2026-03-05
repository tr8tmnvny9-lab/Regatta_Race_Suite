// CommandTargetManager.swift
//
// Phase 4: Source of Truth Toggling
// Manages the PRO's explicit selection of which backend to command:
//   - .localEdge  → Nokia SNPN primary Mac (Thunderbolt / Private 5G)
//   - .awsCloudVM → Regatta Pro CloudVM on AWS Fargate
//
// The selection is persisted to UserDefaults so it survives app restarts.
// All SocketIO / REST commands are routed through this manager's backendURL.

import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "com.regatta.pro", category: "CommandTarget")

// ─── Command Target ───────────────────────────────────────────────────────────

enum CommandTarget: String, CaseIterable, Codable {
    case localEdge  = "localEdge"
    case awsCloudVM = "awsCloudVM"

    var displayName: String {
        switch self {
        case .localEdge:  return "Local Edge (SNPN)"
        case .awsCloudVM: return "AWS Cloud VM"
        }
    }

    var icon: String {
        switch self {
        case .localEdge:  return "network"
        case .awsCloudVM: return "cloud.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .localEdge:  return "green"
        case .awsCloudVM: return "blue"
        }
    }
}

// ─── CommandTargetManager ────────────────────────────────────────────────────

final class CommandTargetManager: ObservableObject {

    @Published private(set) var target: CommandTarget
    @Published private(set) var targetURL: URL

    // Local edge computer (committee boat Nokia SNPN Mac - set up mode)
    private let localEdgeURL: URL
    // AWS Fargate CloudVM (fetched from environment / config)
    private let awsCloudURL: URL

    static let shared = CommandTargetManager()

    private init() {
        // Local edge always runs on port 3001 on the committee boat's LAN IP
        let localHost = UserDefaults.standard.string(forKey: "localEdgeHost") ?? "localhost"
        self.localEdgeURL = URL(string: "http://\(localHost):3001")!

        // AWS CloudVM URL (set via AWS_CLOUDVM_URL env/UserDefaults)
        let awsHost = UserDefaults.standard.string(forKey: "awsCloudVMURL")
            ?? ProcessInfo.processInfo.environment["AWS_CLOUDVM_URL"]
            ?? "https://regatta-backend.fly.dev"
        self.awsCloudURL = URL(string: awsHost)!

        // Restore last selection
        let saved = UserDefaults.standard.string(forKey: "commandTarget")
        let restoredTarget = CommandTarget(rawValue: saved ?? "") ?? .localEdge
        self.target = restoredTarget
        self.targetURL = restoredTarget == .localEdge ? localEdgeURL : awsCloudURL

        log.info("CommandTargetManager initialized. Active target: \(restoredTarget.displayName)")
    }

    // ─── Switch target explicitly ─────────────────────────────────────────────

    func switchTarget(to newTarget: CommandTarget) {
        guard newTarget != target else { return }

        log.info("Switching command target: \(self.target.displayName) → \(newTarget.displayName)")

        UserDefaults.standard.setValue(newTarget.rawValue, forKey: "commandTarget")

        DispatchQueue.main.async {
            self.target = newTarget
            self.targetURL = newTarget == .localEdge ? self.localEdgeURL : self.awsCloudURL
        }
    }

    // ─── Persist custom URLs ──────────────────────────────────────────────────

    func setLocalEdgeHost(_ host: String) {
        UserDefaults.standard.setValue(host, forKey: "localEdgeHost")
        log.info("Local edge host updated to: \(host)")
    }

    func setAWSCloudVMURL(_ urlString: String) {
        guard URL(string: urlString) != nil else {
            log.error("Invalid AWS CloudVM URL: \(urlString)")
            return
        }
        UserDefaults.standard.setValue(urlString, forKey: "awsCloudVMURL")
        log.info("AWS CloudVM URL updated to: \(urlString)")
    }
}
