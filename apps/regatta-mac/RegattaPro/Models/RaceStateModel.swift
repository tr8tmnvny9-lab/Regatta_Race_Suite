import Foundation
import Combine
import SwiftUI
import CoreLocation
import AppKit

// ─── Decoupled Video Buffer ──────────────────────────────────────────────────
final class LiveVideoSystem: ObservableObject {
    static let shared = LiveVideoSystem()
    @Published var frames: [String: NSImage] = [:]
    private init() {}
    
    func updateFrame(for boatId: String, image: NSImage) {
        self.frames[boatId] = image
    }
}
// ─── Geographic Types ────────────────────────────────────────────────────────

struct LatLon: Codable, Equatable {
    var lat: Double
    var lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// ─── Race Status ─────────────────────────────────────────────────────────────

enum RaceStatus: String, Codable {
    case idle = "IDLE"
    case warning = "WARNING"
    case preparatory = "PREPARATORY"
    case oneMinute = "ONE_MINUTE"
    case racing = "RACING"
    case finished = "FINISHED"
    case postponed = "POSTPONED"
    case individualRecall = "INDIVIDUAL_RECALL"
    case generalRecall = "GENERAL_RECALL"
    case abandoned = "ABANDONED"
    case shortenCourse = "SHORTEN_COURSE"
    case changeCourse = "CHANGE_COURSE"
}

// ─── Course Elements ─────────────────────────────────────────────────────────

enum BuoyType: String, Codable {
    case mark = "MARK"
    case start = "START"
    case finish = "FINISH"
    case gate = "GATE"
}

struct Buoy: Codable, Identifiable {
    let id: String
    var type: BuoyType
    var name: String
    var pos: LatLon
    var color: String? // Red, Green, Yellow, Orange, Blue
    var rounding: String? // Port, Starboard
    var design: String? // Cylindrical, Spherical, Spar, MarkSetBot
    var label: String? // Custom name/number
    var showLaylines: Bool = false
    var laylineDirection: Double = 0 // 0 = upwind, 180 = downwind
}

struct CourseLine: Codable {
    var p1: LatLon?
    var p2: LatLon?
}

struct RestrictionZone: Codable, Identifiable {
    let id: String
    var points: [LatLon]
    var color: String = "Yellow"
}

struct CourseSettings: Codable {
    var showMarkZones: Bool = true
    var markZoneMultiplier: Double = 3.0
    var show3DWall: Bool = true
    var show3DLogos: Bool = true
    var sponsorLogoPath: String = ""
}

struct CourseState: Codable {
    var marks: [Buoy] = []
    var startLine: CourseLine?
    var finishLine: CourseLine?
    var courseBoundary: [LatLon]?
    var restrictionZones: [RestrictionZone] = []
    var settings: CourseSettings = CourseSettings()
}

struct CourseTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var marks: [TemplateMark]
    var boundary: [TemplatePoint]?
    
    struct TemplateMark: Codable {
        let type: BuoyType
        let name: String
        let relativeX: Double // meters offset East/West from centroid
        let relativeY: Double // meters offset North/South from centroid
        let color: String?
        let design: String?
        let rounding: String?
        let showLaylines: Bool?
        let laylineDirection: Double?
    }
    
    struct TemplatePoint: Codable {
        let relativeX: Double
        let relativeY: Double
    }
}

// ─── Telemetry ───────────────────────────────────────────────────────────────

struct BoatState: Codable, Identifiable {
    var id: String { boatId }
    let boatId: String
    let pos: LatLon
    let imu: ImuData
    let velocity: VelocityData
    let dtl: Double
    let timestamp: Int64
    
    struct ImuData: Codable {
        let heading: Double
        let roll: Double?
        let pitch: Double?
    }
    
    struct VelocityData: Codable {
        let speed: Double
        let dir: Double?
    }
}

// ─── Logging ─────────────────────────────────────────────────────────────────

enum LogCategory: String, Codable, Hashable {
    case boat = "BOAT"
    case course = "COURSE"
    case procedure = "PROCEDURE"
    case jury = "JURY"
    case system = "SYSTEM"
}

struct LogEntry: Codable, Identifiable, Hashable {
    let id: String
    let timestamp: Int64
    let category: LogCategory
    let source: String
    let message: String
    var isFlagged: Bool = false
    
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

// ─── Direct Tactical Types ───────────────────────────────────────────────────

struct LiveBoat: Identifiable, Codable, Equatable {
    let id: String
    var pos: LatLon
    var speed: Double
    var heading: Double
    var cog: Double?
    var sog: Double?
    var color: String?
    var role: BoatRole = .sailboat
    var rank: Int?
    var dtf: Double?
    var legIndex: Int?
    var teamName: String?
    var timestamp: Int64
    
    // Ghost status helper property
    var isGhosted: Bool {
        let ageMs = Date().timeIntervalSince1970 * 1000 - Double(timestamp)
        return ageMs > 3000 // 3 seconds timeout
    }
    
    enum BoatRole: String, Codable {
        case sailboat = "SAILBOAT"
        case jury = "JURY"
        case help = "HELP"
        case media = "MEDIA"
        case safety = "SAFETY"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, speed, heading, cog, sog, color, role
        case lat, lon
        case rank, dtf, legIndex, teamName, timestamp
    }
    
    init(id: String, pos: LatLon, speed: Double, heading: Double, color: String? = nil, role: BoatRole = .sailboat, timestamp: Int64 = 0) {
        self.id = id
        self.pos = pos
        self.speed = speed
        self.heading = heading
        self.color = color
        self.role = role
        self.cog = heading
        self.sog = speed
        self.timestamp = timestamp == 0 ? Int64(Date().timeIntervalSince1970 * 1000) : timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        speed = (try? container.decode(Double.self, forKey: .speed)) ?? 0
        heading = (try? container.decode(Double.self, forKey: .heading)) ?? 0
        cog = try? container.decode(Double.self, forKey: .cog)
        sog = try? container.decode(Double.self, forKey: .sog)
        color = try? container.decode(String.self, forKey: .color)
        role = (try? container.decode(BoatRole.self, forKey: .role)) ?? .sailboat
        rank = try? container.decode(Int.self, forKey: .rank)
        dtf = try? container.decode(Double.self, forKey: .dtf)
        legIndex = try? container.decode(Int.self, forKey: .legIndex)
        teamName = try? container.decode(String.self, forKey: .teamName)
        timestamp = (try? container.decode(Int64.self, forKey: .timestamp)) ?? Int64(Date().timeIntervalSince1970 * 1000)
        
        let la = (try? container.decode(Double.self, forKey: .lat)) ?? 0
        let lo = (try? container.decode(Double.self, forKey: .lon)) ?? 0
        pos = LatLon(lat: la, lon: lo)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(speed, forKey: .speed)
        try container.encode(heading, forKey: .heading)
        try container.encode(cog, forKey: .cog)
        try container.encode(sog, forKey: .sog)
        try container.encode(color, forKey: .color)
        try container.encode(role, forKey: .role)
        try container.encode(rank, forKey: .rank)
        try container.encode(dtf, forKey: .dtf)
        try container.encode(legIndex, forKey: .legIndex)
        try container.encode(teamName, forKey: .teamName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(pos.lat, forKey: .lat)
        try container.encode(pos.lon, forKey: .lon)
    }
}

// ─── Main Model ─────────────────────────────────────────────────────────────

struct BackendProcedureNode: Identifiable, Equatable {
    let id: String
    let label: String
    let duration: Double
    let waitForUserTrigger: Bool
    let actionLabel: String?
}

final class RaceStateModel: ObservableObject {
    @Published var status: RaceStatus = .idle
    @Published var timeRemaining: Double = 0
    @Published var activeFlags: [String] = []
    
    // Performance    // Broadcast Mode View State
    @Published var isBroadcastModeActive: Bool = false
    
    // Live Video Buffer (Decoupled to LiveVideoSystem to prevent SwiftUI global freeze loops)
    var activeVideoFrames: [String: NSImage] = [:]
    
    // Course
    @Published var course = CourseState()
    
    // Wind
    @Published var tws: Double = 0.0
    @Published var twd: Double = 180.0
    
    var courseCentroid: LatLon? {
        guard !course.marks.isEmpty else { return nil }
        let totalLat = course.marks.reduce(0.0) { $0 + $1.pos.lat }
        let totalLon = course.marks.reduce(0.0) { $0 + $1.pos.lon }
        return LatLon(lat: totalLat / Double(course.marks.count), lon: totalLon / Double(course.marks.count))
    }
    
    // Procedure Engine State
    @Published var currentNodeId: String?
    @Published var activeProcedureNodes: [BackendProcedureNode] = []
    
    // Fleet
    @Published var boats: [LiveBoat] = []
    @Published var boatStates: [String: BoatState] = [:] // Detailed states
    @Published var ocsBoats: [String] = []
    
    // History
    @Published var logs: [LogEntry] = []
    
    // Diagnostic Pipeline Pulse Counters (D1-D6)
    @Published var diagnosticHeartbeats: [String: Int] = [
        "D1": 0, "D2": 0, "D3": 0, "D4": 0, "D5": 0, "D6": 0
    ]
    
    // Team Mapping Data
    @Published var activeFlightId: String?
    @Published var teamsMap: [String: String] = [:] // id -> name
    @Published var boatToTeamId: [String: String] = [:] // boatId -> teamId
    
    // Fleet Configuration
    @Published var boatProfiles: [BoatProfile] = [.defaultProfile]
    
    // --- League Sailing additions ---
    @Published var leagueTeams: [LeagueTeam] = (1...15).map { i in
        LeagueTeam(id: "team-\(i)", name: "Team \(i)", club: "Club \(i)")
    }
    @Published var leagueBoats: [LeagueBoat] = []
    @Published var leagueSchedule: LeagueSchedule? = nil
    
    // Race event timing (for recall windows)
    @Published var raceStartTime: Date?
    
    // Zone Detection (Rule 18 triggers)
    @Published var boatZoneEntries: [String: Set<String>] = [:] // boatId -> set of markIds
    
    // Track last time we pushed a team update to avoid race conditions with backend sync
    private var lastTeamPushTimestamp: Date = .distantPast
    
    // Tracker Demo Simulator Fallback
    private var demoGhostingTimer: Timer?
    
    // Reference to client for synchronization (set by App.swift)
    var raceEngine: RaceEngineClient?
    
    init() {
        // Fallback internal loop to keep demo simulated fleet boats alive when
        // running Mac app standalone without `uwb-simulator`.
        self.demoGhostingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            
            for i in 0..<self.boats.count {
                let boat = self.boats[i]
                
                // Exclude explicit trackers which MUST ghost if they disconnect
                let id = boat.id.lowercased()
                if id.contains("virtual") || id.contains("track") || id.contains("hardware") { continue }
                
                // Refresh Timestamp natively for Simulator Fleet
                self.boats[i].timestamp = nowMs
                
                // Micro-drift Physics (simulate gentle waves so they appear alive in 3D)
                let driftRate = 0.000005 // rough degrees lat/lon per second
                self.boats[i].pos = LatLon(
                    lat: boat.pos.lat + Double.random(in: -driftRate...driftRate),
                    lon: boat.pos.lon + Double.random(in: -driftRate...driftRate)
                )
                
                var newHeading = boat.heading + Double.random(in: -2...2)
                if newHeading < 0 { newHeading += 360 }
                if newHeading >= 360 { newHeading -= 360 }
                self.boats[i].heading = newHeading
            }
        }
        RunLoop.main.add(demoGhostingTimer!, forMode: .common)
    }

    // ─── Team Management (Optimistic UI) ───────────────────────────────────
    
    func addLeagueTeam(name: String, club: String) {
        let newTeam = LeagueTeam(id: UUID().uuidString, name: name, club: club, ranking: 0, score: 0)
        
        // Optimistic update
        DispatchQueue.main.async {
            self.leagueTeams.append(newTeam)
            self.leagueTeams.sort(by: { $0.name < $1.name })
            
            self.lastTeamPushTimestamp = Date()
            // Sync to backend
            self.raceEngine?.setTeams(teams: self.leagueTeams)
        }
    }
    
    func removeLeagueTeam(id: String) {
        // Optimistic update
        DispatchQueue.main.async {
            self.leagueTeams.removeAll(where: { $0.id == id })
            
            self.lastTeamPushTimestamp = Date()
            // Sync to backend
            self.raceEngine?.setTeams(teams: self.leagueTeams)
        }
    }
    
    func clearAllTeams() {
        DispatchQueue.main.async {
            self.leagueTeams = []
            self.lastTeamPushTimestamp = Date()
            self.raceEngine?.setTeams(teams: [])
        }
    }
    
    func updateBoatColor(id: String, colorHex: String) {
        DispatchQueue.main.async {
            if let idx = self.leagueBoats.firstIndex(where: { $0.id == id }) {
                self.leagueBoats[idx].color = colorHex
                // If backend needs the color later, sync here
            }
        }
    }
    
    func triggerConnectivityRefresh() {
        // This is called by RaceEngineClient when it detects a socket failure
        // We can use this to nudge ConnectionManager or just log it
        print("🔄 RaceStateModel: Connectivity refresh triggered by engine client")
    }

    func generateLeagueSchedule(boatCount: Int, flightCount: Int) {
        print("⚡️ RaceStateModel: Generating schedule instantly (local fallback)")
        
        // 1. Prepare boats (Preserve existing colors if available)
        var boats: [LeagueBoat] = []
        for i in 1...boatCount {
            let idStr = "\(i)"
            let existingColor = self.leagueBoats.first(where: { $0.id == idStr })?.color ?? "#FFFFFF"
            boats.append(LeagueBoat(id: idStr, name: "Boat \(i)", color: existingColor))
        }
        
        // Save back so the UI has them eagerly
        DispatchQueue.main.async {
            self.leagueBoats = boats
        }
        
        // 2. Generate locally
        let schedule = LeaguePairingGenerator.generate(
            teams: self.leagueTeams,
            boats: boats,
            flightCount: flightCount
        )
        
        // 3. Update UI instantly
        DispatchQueue.main.async {
            self.leagueSchedule = schedule
            print("✅ RaceStateModel: Local schedule applied (\(schedule.pairings.count) pairings)")
        }
        
        // 4. Sync with backend
        // We still tell the backend to generate so it has the state, 
        // but our local state is already 'optimistic'
        self.raceEngine?.generateFlights(flightCount: flightCount, boatCount: boatCount)
    }

    func applyStateUpdate(_ json: [String: Any]) {
        if let statusStr = json["status"] as? String {
            let newStatus = RaceStatus(rawValue: statusStr) ?? .idle
            // Capture race start time when transitioning to racing
            if newStatus == .racing && self.status != .racing {
                self.raceStartTime = Date()
            } else if newStatus != .racing {
                // Clear the start time when no longer racing (abandon, general recall, etc.)
                if newStatus == .idle || newStatus == .abandoned || newStatus == .generalRecall {
                    self.raceStartTime = nil
                }
            }
            self.status = newStatus
        }
        
        if let secs = json["sequenceTimeRemaining"] as? Double {
            self.timeRemaining = secs
        }
        
        if let seqInfo = json["currentSequence"] as? [String: Any],
           let flags = seqInfo["flags"] as? [String] {
            self.activeFlags = flags
        }
        
        if let wind = json["wind"] as? [String: Any] {
            if let speed = wind["speed"] as? Double { self.tws = speed }
            if let dir = wind["direction"] as? Double { self.twd = dir }
        }
        
        if let nodeId = json["currentNodeId"] as? String {
            self.currentNodeId = nodeId
        }
        
        // 1. Fleet Sync
        if let boatsDict = json["boats"] as? [String: [String: Any]] {
            var newBoats: [LiveBoat] = []
            for (id, dict) in boatsDict {
                if let pos = dict["pos"] as? [String: Any],
                   let lat = (pos["lat"] as? NSNumber)?.doubleValue,
                   let lon = (pos["lon"] as? NSNumber)?.doubleValue {
                    
                    let imu = dict["imu"] as? [String: Any]
                    let heading = (imu?["heading"] as? NSNumber)?.doubleValue ?? 0.0
                    
                    let vel = dict["velocity"] as? [String: Any]
                    let speed = (vel?["speed"] as? NSNumber)?.doubleValue ?? 0.0
                    
                    var boat = LiveBoat(id: id, pos: LatLon(lat: lat, lon: lon), speed: speed, heading: heading)
                    boat.rank = dict["rank"] as? Int
                    boat.dtf = dict["dtfM"] as? Double
                    boat.legIndex = dict["legIndex"] as? Int
                    
                    if let tid = self.boatToTeamId[id], let tName = self.teamsMap[tid] {
                        boat.teamName = tName
                    }
                    newBoats.append(boat)
                }
            }
            if !newBoats.isEmpty {
                self.mergeBoats(newBoats)
            }
        }
        
        if let proc = json["currentProcedure"] as? [String: Any],
           let nodes = proc["nodes"] as? [[String: Any]] {
            var parsedNodes: [BackendProcedureNode] = []
            for n in nodes {
                if let id = n["id"] as? String,
                   let data = n["data"] as? [String: Any],
                   let label = data["label"] as? String {
                    let duration = (data["duration"] as? Double) ?? 0.0
                    let waitForUserTrigger = (data["waitForUserTrigger"] as? Bool) ?? false
                    let actionLabel = data["actionLabel"] as? String
                    parsedNodes.append(BackendProcedureNode(
                        id: id, label: label, duration: duration, 
                        waitForUserTrigger: waitForUserTrigger, actionLabel: actionLabel
                    ))
                }
            }
            self.activeProcedureNodes = parsedNodes
        }
        
        // Course Settings Sync
        if let courseJson = json["course"] as? [String: Any] {
            applyCourseUpdate(courseJson)
        }
        
        // Logs Processing
        if let newLogs = json["logs"] as? [[String: Any]] {
            var parsedLogs: [LogEntry] = []
            for l in newLogs {
                if let id = l["id"] as? String,
                   let timestamp = l["timestamp"] as? Int64,
                   let catStr = l["category"] as? String,
                   let category = LogCategory(rawValue: catStr),
                   let source = l["source"] as? String,
                   let message = l["message"] as? String {
                    let isFlagged = l["protestFlagged"] as? Bool ?? false
                    parsedLogs.append(LogEntry(id: id, timestamp: timestamp, category: category, source: source, message: message, isFlagged: isFlagged))
                }
            }
            self.logs = parsedLogs.sorted(by: { $0.timestamp > $1.timestamp })
        }
        
        // Flight & Team Mapping
        if let active = json["activeFlightId"] as? String {
            self.activeFlightId = active
        }
        
        // 1. Teams Sync
        if let teamsDict = json["teams"] as? [String: Any] {
            // Protection: If we recently pushed a change (< 2 seconds ago), 
            // ignore incoming empty or significantly smaller team lists to prevent overwrite race.
            let recentlyPushed = Date().timeIntervalSince(lastTeamPushTimestamp) < 2.0
            
            if recentlyPushed && teamsDict.isEmpty && !self.leagueTeams.isEmpty {
                print("🛡️ Sync Protection: Ignored empty team update from backend (recently pushed local changes)")
            } else {
                var parsedTeams: [LeagueTeam] = []
                for (idStr, tdValue) in teamsDict {
                    guard let td = tdValue as? [String: Any] else { continue }
                    
                    if let name = td["name"] as? String,
                       let club = td["club"] as? String {
                        let ranking = td["ranking"] as? Int ?? 0
                        parsedTeams.append(LeagueTeam(id: idStr, name: name, club: club, ranking: ranking))
                    }
                }
                self.leagueTeams = parsedTeams.sorted(by: { $0.name < $1.name })
                self.teamsMap = parsedTeams.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
            }
        }
        
        // 1.5 Boat Profiles Sync
        if let profilesData = json["boatProfiles"] as? [[String: Any]] {
            var parsedProfiles: [BoatProfile] = []
            for p in profilesData {
                if let id = p["id"] as? String,
                   let name = p["name"] as? String,
                   let lp = p["maxLengthPole"] as? Double,
                   let lh = p["maxLengthHull"] as? Double,
                   let wd = p["maxWidthDeck"] as? Double,
                   let mountData = p["mount"] as? [String: Any] {
                    
                    let mount = TrackerMount(
                        offsetX: mountData["offsetX"] as? Double ?? 1.5,
                        offsetY: mountData["offsetY"] as? Double ?? 0.0,
                        offsetZ: mountData["offsetZ"] as? Double ?? 0.1,
                        mountingAzimuth: mountData["mountingAzimuth"] as? Double ?? 0.0,
                        mountingElevation: mountData["mountingElevation"] as? Double ?? 0.0
                    )
                    
                    parsedProfiles.append(BoatProfile(
                        id: id, name: name, 
                        maxLengthPole: lp, maxLengthHull: lh, maxWidthDeck: wd, 
                        mount: mount
                    ))
                }
            }
            if !parsedProfiles.isEmpty {
                self.boatProfiles = parsedProfiles
            }
        }
        
        // 2. Flights Sync
        var flightIdToIndex: [String: Int] = [:]
        if let flightsData = json["flights"] as? [String: Any] {
            for (fid, fdValue) in flightsData {
                if let fd = fdValue as? [String: Any], let num = fd["flightNumber"] as? Int {
                    flightIdToIndex[fid] = num - 1
                }
            }
        }
        
        // 3. Pairings Sync
        if let pairingsData = json["pairings"] as? [[String: Any]] {
            var schedulePairings: [LeaguePairing] = []
            for p in pairingsData {
                guard let fid = p["flightId"] as? String,
                      let bid = p["boatId"] as? String,
                      let ridx = p["raceIndex"] as? Int,
                      let fidx = flightIdToIndex[fid] else {
                    continue
                }
                
                let tid = p["teamId"] as? String
                
                schedulePairings.append(LeaguePairing(
                    flightIndex: fidx,
                    raceIndex: ridx,
                    boatId: bid,
                    teamId: tid
                ))
            }
            
            if !schedulePairings.isEmpty {
                let maxFlight = (schedulePairings.map { $0.flightIndex }.max() ?? 0) + 1
                
                // Robust boat count: extract largest number from boatId string or default to 6
                let boatIds = schedulePairings.map { $0.boatId }
                let allNumbers = boatIds.compactMap { id -> Int? in
                    let digits = id.filter { $0.isNumber }
                    return Int(digits)
                }
                let maxBoat = allNumbers.max() ?? 6
                
                self.leagueSchedule = LeagueSchedule(
                    flightCount: maxFlight,
                    boatCount: maxBoat,
                    pairings: schedulePairings
                )
                print("✅ Successfully parsed \(schedulePairings.count) pairings for \(maxFlight) flights.")
            } else if recentlyPushed(field: "flights") {
                // Keep current schedule if we just generated
            } else {
                self.leagueSchedule = nil
            }
            
            if let active = self.activeFlightId, let activeIdx = flightIdToIndex[active] {
                self.boatToTeamId = schedulePairings
                    .filter { $0.flightIndex == activeIdx }
                    .reduce(into: [String: String]()) { $0[$1.boatId] = $1.teamId ?? "" }
            }
        }
    }
    
    private func recentlyPushed(field: String) -> Bool {
        return Date().timeIntervalSince(lastTeamPushTimestamp) < 2.0
    }
    
    // ─── Zone Detection ───────────────────────────────────────────────────────
    
    func updateZoneDetection(_ newBoats: [LiveBoat]) {
        // We use a safe boat length of 12m if profile is missing
        let boatLength = self.boatProfiles.first?.maxLengthHull ?? 12.0
        // We assume 3x boat length for rule detection unless otherwise specified
        let zoneRadius = boatLength * 3.0 
        
        for boat in newBoats {
            let boatLoc = CLLocation(latitude: boat.pos.lat, longitude: boat.pos.lon)
            var currentEnteredMarks = Set<String>()
            
            for mark in self.course.marks {
                let markLoc = CLLocation(latitude: mark.pos.lat, longitude: mark.pos.lon)
                let distance = boatLoc.distance(from: markLoc)
                
                if distance <= zoneRadius {
                    currentEnteredMarks.insert(mark.id)
                    
                    // If just entered, log it
                    if !(boatZoneEntries[boat.id]?.contains(mark.id) ?? false) {
                        let logMsg = "Boat \(boat.teamName ?? boat.id) ENTERED the zone of \(mark.name)"
                        print("⚓️ [ZONE] \(logMsg)")
                        // Future: Push to backend logs
                    }
                } else {
                    // If just left, log it
                    if (boatZoneEntries[boat.id]?.contains(mark.id) ?? false) {
                        let logMsg = "Boat \(boat.teamName ?? boat.id) LEFT the zone of \(mark.name)"
                        print("⚓️ [ZONE] \(logMsg)")
                    }
                }
            }
            boatZoneEntries[boat.id] = currentEnteredMarks
        }
    }

    func updateSingleBoat(_ boat: LiveBoat) {
        DispatchQueue.main.async {
            if let idx = self.boats.firstIndex(where: { $0.id == boat.id }) {
                self.boats[idx].pos = boat.pos
                self.boats[idx].heading = boat.heading
                self.boats[idx].speed = boat.speed
                if let rank = boat.rank { self.boats[idx].rank = rank }
                if let dtf = boat.dtf { self.boats[idx].dtf = dtf }
                if let leg = boat.legIndex { self.boats[idx].legIndex = leg }
                self.boats[idx].timestamp = boat.timestamp
                
                if boat.id == "virtual-boat-1" {
                    self.diagnosticHeartbeats["D5", default: 0] += 1
                }
            } else {
                self.boats.append(boat)
                if boat.id == "virtual-boat-1" {
                    self.diagnosticHeartbeats["D5", default: 0] += 1
                }
            }
        }
    }

    func mergeBoats(_ newBoats: [LiveBoat]) {
        DispatchQueue.main.async {
            var currentBoats = self.boats
            
            // 1. Update existing and add new from telemetry
            for newBoat in newBoats {
                if let idx = currentBoats.firstIndex(where: { $0.id == newBoat.id }) {
                    currentBoats[idx].pos = newBoat.pos
                    currentBoats[idx].speed = newBoat.speed
                    currentBoats[idx].heading = newBoat.heading
                    currentBoats[idx].cog = newBoat.cog
                    currentBoats[idx].sog = newBoat.sog
                    currentBoats[idx].rank = newBoat.rank
                    currentBoats[idx].dtf = newBoat.dtf
                    currentBoats[idx].timestamp = newBoat.timestamp
                    currentBoats[idx].legIndex = newBoat.legIndex
                    if let tName = newBoat.teamName { currentBoats[idx].teamName = tName }
                    if newBoat.id == "virtual-boat-1" {
                        self.diagnosticHeartbeats["D5", default: 0] += 1
                    }
                } else {
                    currentBoats.append(newBoat)
                    if newBoat.id == "virtual-boat-1" {
                        self.diagnosticHeartbeats["D5", default: 0] += 1
                    }
                }
            }
            
            self.boats = currentBoats
        }
    }

    func applyCourseUpdate(_ json: [String: Any]) {
        DispatchQueue.main.async {
            // Marks
            if let marksJson = json["marks"] as? [[String: Any]] {
                var newMarks: [Buoy] = []
                for m in marksJson {
                    if let id = m["id"] as? String,
                       let name = m["name"] as? String,
                       let typeStr = m["type"] as? String,
                       let posJson = m["pos"] as? [String: Any],
                       let lat = (posJson["lat"] as? NSNumber)?.doubleValue,
                       let lon = (posJson["lon"] as? NSNumber)?.doubleValue {
                        let type = BuoyType(rawValue: typeStr) ?? .mark
                        let laylines = m["showLaylines"] as? Bool ?? false
                        newMarks.append(Buoy(id: id, type: type, name: name, pos: LatLon(lat: lat, lon: lon), showLaylines: laylines))
                    } else if let id = m["id"] as? String {
                        print("⚠️ [PARSE-FAIL] Failed to parse coordinates for mark: \(id). Payload: \(m)")
                    }
                }
                self.course.marks = newMarks
            }
            
            // Boundary
            if let boundaryJson = json["course_boundary"] as? [[String: Any]] {
                self.course.courseBoundary = boundaryJson.compactMap { dict in
                    guard let lat = dict["lat"] as? Double, let lon = dict["lon"] as? Double else { return nil }
                    return LatLon(lat: lat, lon: lon)
                }
            } else if json["course_boundary"] is NSNull {
                self.course.courseBoundary = nil
            }
            
            // Settings
            if let settingsJson = json["settings"] as? [String: Any] {
                var s = self.course.settings
                if let val = settingsJson["showMarkZones"] as? Bool { s.showMarkZones = val }
                if let val = settingsJson["markZoneMultiplier"] as? Double { s.markZoneMultiplier = val }
                if let val = settingsJson["show3DWall"] as? Bool { s.show3DWall = val }
                if let val = settingsJson["show3DLogos"] as? Bool { s.show3DLogos = val }
                if let val = settingsJson["sponsorLogoPath"] as? String { s.sponsorLogoPath = val }
                self.course.settings = s
            }
            
            // Start/Finish Lines
            if let startLineJson = json["startLine"] as? [String: Any] {
                self.course.startLine = self.parseLine(startLineJson)
            }
            if let finishLineJson = json["finishLine"] as? [String: Any] {
                self.course.finishLine = self.parseLine(finishLineJson)
            }
        }
    }

    private func parseLine(_ json: [String: Any]) -> CourseLine? {
        let p1 = json["p1"] as? [String: Any]
        let p2 = json["p2"] as? [String: Any]
        
        let lat1 = p1?["lat"] as? Double
        let lon1 = p1?["lon"] as? Double
        let lat2 = p2?["lat"] as? Double
        let lon2 = p2?["lon"] as? Double
        
        if let l1 = lat1, let ln1 = lon1, let l2 = lat2, let ln2 = lon2 {
            return CourseLine(p1: LatLon(lat: l1, lon: ln1), p2: LatLon(lat: l2, lon: ln2))
        }
        return nil
    }
    
    // ─── Preset Integration ──────────────────────────────────────────────────
    
    func loadFromPreset(_ preset: RacePreset) {
        DispatchQueue.main.async {
            // Course
            self.course = preset.course
            
            // Wind
            self.tws = preset.windSpeed
            self.twd = preset.windDirection
            
            // Boat Profiles
            if !preset.boatProfiles.isEmpty {
                self.boatProfiles = preset.boatProfiles
            }
            
            // Teams
            if let teams = preset.leagueTeams {
                self.leagueTeams = teams
                self.teamsMap = teams.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
            }
            
            // Boats
            if let boats = preset.leagueBoats {
                self.leagueBoats = boats
            }
            
            // Reset state for a fresh race
            self.status = .idle
            self.timeRemaining = 0
            self.activeFlags = []
            self.boats = []
            self.boatStates = [:]
            self.ocsBoats = []
            self.logs = []
            self.raceStartTime = nil
            
            // Push course to backend so the engine knows the marks
            if let engine = self.raceEngine {
                engine.overrideMarks(marks: preset.course.marks)
                engine.setWind(speed: preset.windSpeed, direction: preset.windDirection)
                if let teams = preset.leagueTeams, !teams.isEmpty {
                    engine.setTeams(teams: teams)
                }
            }
            
            print("✅ [RaceState] Loaded preset: \(preset.name)")
        }
    }
    
    func exportToPreset(name: String, existingId: String? = nil, createdAt: Date? = nil) -> RacePreset {
        return RacePreset(
            id: existingId ?? UUID().uuidString,
            name: name,
            createdAt: createdAt ?? Date(),
            modifiedAt: Date(),
            course: self.course,
            windSpeed: self.tws,
            windDirection: self.twd,
            boatProfiles: self.boatProfiles,
            procedureSteps: nil, // Procedure is managed separately by ProcedureArchitectModel
            leagueTeams: self.leagueTeams.isEmpty ? nil : self.leagueTeams,
            leagueBoats: self.leagueBoats.isEmpty ? nil : self.leagueBoats
        )
    }
}


