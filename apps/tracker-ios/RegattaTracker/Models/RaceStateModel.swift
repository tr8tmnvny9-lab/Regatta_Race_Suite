// RaceStateModel.swift
// Observable model keeping local iOS tracker state in sync with the backend.
//
// Receives updates via WebSocket (TrackerConnectionManager) and exposes
// derived properties the SwiftUI views bind to.
//
// Source of truth priority:
//   1. UWB BLE GATT stream (UWBNodeBLEClient) — position data
//   2. WebSocket from backend — sequence state, flags, procedure events
//   3. Offline buffer (SQLite) — last known state

import Foundation
import Combine

final class RaceStateModel: ObservableObject {
    // ── Sequence / countdown ──────────────────────────────────────────────────
    @Published var currentPhase: RacePhase = .idle
    @Published var timeRemaining: Double = 0
    @Published var activeFlags: [String] = []
    @Published var currentNodeId: String = ""

    // ── Fleet ─────────────────────────────────────────────────────────────────
    @Published var assignedBoatNumber: String = ""
    @Published var assignedTeamName: String? 
    @Published var isLeagueMode: Bool = false
    @Published var sessionId: String?

    var cancellables = Set<AnyCancellable>()

    // ─ Update from backend JSON state-update ─────────────────────────────────
    func applyStateUpdate(_ json: [String: Any]) {
        if let statusStr = json["status"] as? String {
            currentPhase = RacePhase(rawValue: statusStr) ?? .idle
        }
        if let secs = json["sequenceTimeRemaining"] as? Double {
            timeRemaining = secs
        }
        if let seqInfo = json["currentSequence"] as? [String: Any],
           let flags = seqInfo["flags"] as? [String] {
            activeFlags = flags
        }
        
        // Fleet parsing for League formats
        if let fleetSettings = json["fleetSettings"] as? [String: Any],
           let mode = fleetSettings["mode"] as? String {
            isLeagueMode = (mode == "LEAGUE")
        } else {
            isLeagueMode = false
        }
        
        if isLeagueMode {
            var currentTeam: String? = nil
            if let activeFlightId = json["activeFlightId"] as? String,
               let pairings = json["pairings"] as? [[String: Any]],
               let teams = json["teams"] as? [String: Any] {
                
                // Find pairing for this boat in the active flight
                if let pairing = pairings.first(where: { 
                    ($0["flightId"] as? String) == activeFlightId &&
                    ($0["boatId"] as? String) == assignedBoatNumber
                }), let teamId = pairing["teamId"] as? String {
                    
                    // Lookup team name
                    if let teamMap = teams[teamId] as? [String: Any],
                       let teamName = teamMap["name"] as? String {
                        currentTeam = teamName
                    }
                }
            }
            assignedTeamName = currentTeam
        } else {
            assignedTeamName = nil
        }
    }
}

// ─── TrackerConnectionManager ─────────────────────────────────────────────────
// iOS-specific connection manager with offline SQLite buffer.

final class TrackerConnectionManager: ObservableObject {
    @Published var sessionId: String?
    @Published var connectionMode: String = "offline"
    @Published var isConnected: Bool = false

    private let cloudURL = "wss://regatta-backend.fly.dev"
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?

    func start() {
        // Resume last session if available
        sessionId = UserDefaults.standard.string(forKey: "lastSessionId")
        if sessionId != nil { connect() }
    }

    func joinSession(id: String, role: String = "tracker") {
        sessionId = id
        UserDefaults.standard.set(id, forKey: "lastSessionId")
        connect()
    }

    func connect() {
        guard let sid = sessionId else { return }
        // Try LAN first (via Bonjour lookup — simplified for Phase 4)
        let urlStr = "\(cloudURL)?sessionId=\(sid)&role=tracker"
        guard let url = URL(string: urlStr) else { return }
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        connectionMode = "cloud"
        receive()
        startPing()
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                default:
                    break
                }
                self?.receive()
            case .failure(let error):
                print("WS error: \(error)")
                self?.isConnected = false
            }
        }
    }

    private func handleMessage(_ text: String) {
        // Parse Socket.IO message format
        // Real Socket.IO parsing happens in Phase 4.2 (library integration)
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // Forward to RaceStateModel
        DispatchQueue.main.async {
            // NotificationCenter or injected reference
            NotificationCenter.default.post(name: .stateUpdate, object: json)
        }
    }

    private func startPing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                webSocketTask?.sendPing { _ in }
            }
        }
    }
}

extension Notification.Name {
    static let stateUpdate = Notification.Name("regatta.stateUpdate")
}

// ─── LocationManager ─────────────────────────────────────────────────────────

import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isActive: Bool = false
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 0.5
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        isActive = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isActive = false
    }
}
