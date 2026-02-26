// SidecarManager.swift
// Manages the embedded Rust backend process ("sidecar" pattern).
//
// The Rust binary `regatta-backend` is bundled in Resources/ at build time.
// This class:
//   1. Launches it as a child process bound to 127.0.0.1:3001
//   2. Polls /health every 2s to detect crashes
//   3. Auto-restarts with exponential backoff (max 30s) if it crashes
//   4. Exposes frontendURL = http://localhost:3000 (Vite dev) or bundle URL
//
// Core Invariant #8: Zero race interruption — always restarts automatically.

import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "com.regatta.pro", category: "Sidecar")

// ─── Status ───────────────────────────────────────────────────────────────────

enum SidecarStatus: Equatable {
    case idle
    case starting
    case ready
    case failed(String)
}

// ─── SidecarManager ──────────────────────────────────────────────────────────

final class SidecarManager: ObservableObject {
    @Published var status: SidecarStatus = .idle
    @Published var logs: [String] = []

    // URL of the embedded Rust backend
    let backendURL = URL(string: "http://localhost:3001")!
    // Frontend URL — local dev Vite server in dev builds, bundled in production
    var frontendURL: URL {
        #if DEBUG
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "http://localhost:3001/app")!
        #endif
    }

    private var process: Process?
    private var healthTask: Task<Void, Never>?
    private var restartDelay: TimeInterval = 1.0
    private let maxRestartDelay: TimeInterval = 30.0
    private var logPipe = Pipe()

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    func start() {
        guard status == .idle else { return }
        status = .starting
        log.info("Starting Rust sidecar...")
        launchProcess()
        startHealthMonitor()
    }

    func stop() {
        healthTask?.cancel()
        process?.terminate()
        process = nil
        status = .idle
        log.info("Sidecar stopped")
    }

    // ─── Process launch ───────────────────────────────────────────────────────

    private func launchProcess() {
        guard let binaryURL = sidecarBinaryURL() else {
            DispatchQueue.main.async {
                self.status = .failed("regatta-backend binary not found in app bundle")
            }
            log.error("regatta-backend binary missing from Resources/")
            return
        }

        let p = Process()
        p.executableURL = binaryURL
        p.environment = [
            "BACKEND_MODE": "local",
            "PORT": "3001",
            "BINDADDR": "127.0.0.1",   // local only — never expose sidecar externally
            "CORS_ORIGINS": "http://localhost:3000,http://localhost:5173",
            "RUST_LOG": "info,regatta_backend=debug",
            "UWB_UDP_PORT": "5555",
        ]

        // Capture stdout/stderr for log viewer
        logPipe = Pipe()
        p.standardOutput = logPipe
        p.standardError = logPipe
        logPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async {
                    self?.logs.append(contentsOf: line.components(separatedBy: "\n").filter { !$0.isEmpty })
                    // Keep last 500 log lines
                    if let count = self?.logs.count, count > 500 {
                        self?.logs.removeFirst(count - 500)
                    }
                }
                log.debug("sidecar: \(line, privacy: .public)")
            }
        }

        p.terminationHandler = { [weak self] proc in
            guard let self else { return }
            log.warning("Sidecar exited with code \(proc.terminationStatus)")
            DispatchQueue.main.async { self.status = .starting }
            self.scheduleRestart()
        }

        do {
            try p.run()
            self.process = p
            log.info("Sidecar launched (PID \(p.processIdentifier))")
        } catch {
            DispatchQueue.main.async {
                self.status = .failed("Could not launch sidecar: \(error.localizedDescription)")
            }
            log.error("Failed to launch sidecar: \(error)")
        }
    }

    private func scheduleRestart() {
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, maxRestartDelay)
        log.info("Restarting sidecar in \(delay)s...")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.launchProcess()
        }
    }

    private func sidecarBinaryURL() -> URL? {
        // In production: bundled in Resources/
        if let url = Bundle.main.url(forResource: "regatta-backend", withExtension: nil) {
            return url
        }
        // In development: built by `just build-mac`, placed in project root
        let devURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()      // RegattaPro/
            .deletingLastPathComponent()      // regatta-mac/
            .deletingLastPathComponent()      // apps/
            .deletingLastPathComponent()      // regatta-suite/
            .appendingPathComponent("backend-rust/target/aarch64-apple-darwin/release/regatta-backend")
        if FileManager.default.isExecutableFile(atPath: devURL.path) {
            return devURL
        }
        // x86 fallback
        let x86URL = devURL
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("x86_64-apple-darwin/release/regatta-backend")
        if FileManager.default.isExecutableFile(atPath: x86URL.path) {
            return x86URL
        }
        return nil
    }

    // ─── Health monitor ───────────────────────────────────────────────────────

    private func startHealthMonitor() {
        healthTask = Task { [weak self] in
            guard let self else { return }

            // Wait up to 15s for initial startup
            var attempts = 0
            while attempts < 30 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                if await self.ping() { break }
                attempts += 1
            }

            // Steady-state: poll every 2s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                let alive = await self.ping()
                if !alive && self.status == .ready {
                    log.warning("Sidecar health check failed — not responding")
                }
            }
        }
    }

    private func ping() async -> Bool {
        let url = backendURL.appendingPathComponent("health")
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if ok && status != .ready {
                await MainActor.run {
                    self.status = .ready
                    self.restartDelay = 1.0   // reset backoff on successful start
                }
            }
            return ok
        } catch {
            return false
        }
    }
}
