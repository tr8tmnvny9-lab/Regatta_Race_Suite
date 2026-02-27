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


extension Notification.Name {
    static let stateUpdate = Notification.Name("regatta.stateUpdate")
}

