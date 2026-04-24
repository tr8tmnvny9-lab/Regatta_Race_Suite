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

struct LatLon: Codable, Equatable {
    var lat: Double
    var lon: Double
}

enum BuoyType: String, Codable, Equatable {
    case mark = "MARK"
    case start = "START"
    case finish = "FINISH"
    case gate = "GATE"
}

struct Buoy: Codable, Identifiable, Equatable {
    let id: String
    var type: BuoyType
    var name: String
    var pos: LatLon
}


struct CourseState: Codable {
    var marks: [Buoy] = []
}

final class RaceStateModel: ObservableObject {
    // ── Sequence / countdown ──────────────────────────────────────────────────
    @Published var currentPhase: RacePhase = .idle
    @Published var timeRemaining: Double = 0
    @Published var isJuryMode: Bool = false
    @Published var activeFlags: [String] = []
    @Published var currentNodeId: String = ""
    
    // ── Course & Wind ─────────────────────────────────────────────────────────
    @Published var course: CourseState = CourseState()
    @Published var twd: Double = 0.0
    
    // ── Diagnostics ───────────────────────────────────────────────────────────
    @Published var diagnosticHeartbeats: [String: Int] = [:]

    // ── Fleet ─────────────────────────────────────────────────────────────────
    @Published var assignedBoatNumber: String = ""
    @Published var assignedTeamName: String? 
    @Published var boatColour: String = ""
    @Published var isLeagueMode: Bool = false
    @Published var sessionId: String?

    var courseCentroid: LatLon? {
        guard !course.marks.isEmpty else { return nil }
        let totalLat = course.marks.reduce(0.0) { $0 + $1.pos.lat }
        let totalLon = course.marks.reduce(0.0) { $0 + $1.pos.lon }
        return LatLon(lat: totalLat / Double(course.marks.count), lon: totalLon / Double(course.marks.count))
    }
    
    var cancellables = Set<AnyCancellable>()

    // ─ Update from backend JSON state-update ─────────────────────────────────
    func applyStateUpdate(_ json: [String: Any]) {
        if let statusStr = json["status"] as? String {
            currentPhase = RacePhase(rawValue: statusStr) ?? .idle
        }
        if let secs = json["sequenceTimeRemaining"] as? Double {
            timeRemaining = secs
        }
        if let boatColor = json["hullColour"] as? String {
            boatColour = boatColor
        }
        if let seqInfo = json["currentSequence"] as? [String: Any],
           let flags = seqInfo["flags"] as? [String] {
            activeFlags = flags
        }
        
        if let wind = json["wind"] as? [String: Any],
           let dir = wind["direction"] as? Double {
            self.twd = dir
        }
        
        if let courseJson = json["course"] as? [String: Any],
           let marksJson = courseJson["marks"] as? [[String: Any]] {
            var newMarks: [Buoy] = []
            for m in marksJson {
                if let id = m["id"] as? String,
                   let name = m["name"] as? String,
                   let typeStr = m["type"] as? String,
                   let posJson = m["pos"] as? [String: Any],
                   let lat = posJson["lat"] as? Double,
                   let lon = posJson["lon"] as? Double {
                    let type = BuoyType(rawValue: typeStr) ?? .mark
                    newMarks.append(Buoy(id: id, type: type, name: name, pos: LatLon(lat: lat, lon: lon)))
                }
            }
            self.course.marks = newMarks

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

