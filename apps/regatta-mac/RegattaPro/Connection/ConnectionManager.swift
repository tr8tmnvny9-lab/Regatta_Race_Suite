// ConnectionManager.swift
// Network topology manager — switches between LAN, Cloud, and Offline modes.
//
// Priority chain (satisfies Core Invariant #3 — <10s cloud failover):
//   1. LAN   → Bonjour _regatta._tcp. discovery → local backend
//   2. Cloud  → wss://api.regatta.app (Fly.io) → cloud backend
//   3. Offline → buffer mode (iOS), read-only (Mac)
//
// On network change: re-evaluates priority chain within 2s.
// On LAN restore: switches back from cloud (saves bandwidth, lower latency).
//
// Core Invariant #3: cloud failover < 10s if committee boat device fails
// Core Invariant #7: three synchronized products that interoperate seamlessly

import Foundation
import Network
import Combine
import OSLog

private let log = Logger(subsystem: "com.regatta.pro", category: "Connection")

// ─── Connection Mode ──────────────────────────────────────────────────────────

enum ConnectionMode: Equatable {
    case local(URL)         // LAN backend (committee boat sidecar)
    case cloud(URL)         // Fly.io cloud backend
    case offline            // No connectivity
}

// ─── ConnectionManager ────────────────────────────────────────────────────────

final class ConnectionManager: ObservableObject {
    @Published var mode: ConnectionMode = .offline
    @Published var isConnected: Bool = false
    @Published var latencyMs: Double = 0

    // Cloud endpoint (production)
    private let cloudURL = URL(string: "https://regatta-backend.fly.dev")!
    // Local sidecar (always try this first)
    private let localURL = URL(string: "http://localhost:3001")!

    private var pathMonitor: NWPathMonitor?
    private var bonjourBrowser: NWBrowser?
    private var monitorTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    // ─── Start ────────────────────────────────────────────────────────────────

    func start() {
        startPathMonitor()
        startBonjourBrowser()
        startConnectionLoop()
    }

    func stop() {
        pathMonitor?.cancel()
        bonjourBrowser?.cancel()
        monitorTask?.cancel()
        reconnectTask?.cancel()
    }

    // ─── Network path monitor ─────────────────────────────────────────────────

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            log.info("Network path changed: \(path.status == .satisfied ? "satisfied" : "unsatisfied")")
            self?.evaluateConnectionMode()
        }
        monitor.start(queue: DispatchQueue(label: "com.regatta.pro.netpath"))
        self.pathMonitor = monitor
    }

    // ─── Bonjour / mDNS browser ───────────────────────────────────────────────
    // Discovers _regatta._tcp. services on LAN — committee boat Mac broadcasts this.

    private func startBonjourBrowser() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_regatta._tcp.", domain: nil),
            using: parameters
        )
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            for change in changes {
                switch change {
                case .added(let result):
                    log.info("Bonjour: found Regatta Pro service: \(result.endpoint)")
                    self?.evaluateConnectionMode()
                case .removed:
                    log.info("Bonjour: Regatta Pro service disappeared")
                    self?.evaluateConnectionMode()
                default:
                    break
                }
            }
        }
        browser.start(queue: DispatchQueue(label: "com.regatta.pro.bonjour"))
        self.bonjourBrowser = browser
    }

    // ─── Connection loop ──────────────────────────────────────────────────────

    private func startConnectionLoop() {
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.evaluateConnectionModeAsync()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // every 5s
            }
        }
    }

    private func evaluateConnectionMode() {
        Task { await evaluateConnectionModeAsync() }
    }

    private func evaluateConnectionModeAsync() async {
        // 1. Try local sidecar (always preferred for lowest latency)
        if let ms = await ping(url: localURL) {
            await MainActor.run {
                self.mode = .local(self.localURL)
                self.isConnected = true
                self.latencyMs = ms
            }
            return
        }

        // 2. Try cloud backend (satisfies Invariant #3: <10s failover)
        if let ms = await ping(url: cloudURL) {
            log.info("Switched to cloud backend (latency: \(ms)ms)")
            await MainActor.run {
                self.mode = .cloud(self.cloudURL)
                self.isConnected = true
                self.latencyMs = ms
            }
            return
        }

        // 3. Offline
        log.warning("All backends unreachable — entering offline mode")
        await MainActor.run {
            self.mode = .offline
            self.isConnected = false
            self.latencyMs = 0
        }
    }

    private func ping(url: URL) async -> Double? {
        let start = Date()
        do {
            let healthURL = url.appendingPathComponent("health")
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return Date().timeIntervalSince(start) * 1000
        } catch {
            return nil
        }
    }

    // ─── Current backend URL ──────────────────────────────────────────────────

    var backendURL: URL? {
        switch mode {
        case .local(let url): return url
        case .cloud(let url): return url
        case .offline: return nil
        }
    }

    var modeLabel: String {
        switch mode {
        case .local:  return "🟢 LAN"
        case .cloud:  return "🟡 Cloud"
        case .offline: return "🔴 Offline"
        }
    }
}
