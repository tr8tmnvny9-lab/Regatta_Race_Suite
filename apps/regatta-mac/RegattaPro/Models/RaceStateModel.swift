import Foundation
import Combine
import SwiftUI
import CoreLocation

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

struct CourseState: Codable {
    var marks: [Buoy] = []
    var startLine: CourseLine?
    var finishLine: CourseLine?
    var courseBoundary: [LatLon]?
    var restrictionZones: [RestrictionZone] = []
}

struct CourseTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var marks: [TemplateMark]
    
    struct TemplateMark: Codable {
        let type: BuoyType
        let name: String
        let relativeX: Double // meters offset East/West from centroid
        let relativeY: Double // meters offset North/South from centroid
        let color: String?
        let design: String?
        let rounding: String?
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
    }
    
    init(id: String, pos: LatLon, speed: Double, heading: Double, color: String? = nil, role: BoatRole = .sailboat) {
        self.id = id
        self.pos = pos
        self.speed = speed
        self.heading = heading
        self.color = color
        self.role = role
        self.cog = heading
        self.sog = speed
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
    
    // Course
    @Published var course = CourseState()
    
    // Wind
    @Published var tws: Double = 0.0
    @Published var twd: Double = 180.0
    
    // Procedure Engine State
    @Published var currentNodeId: String?
    @Published var activeProcedureNodes: [BackendProcedureNode] = []
    
    // Fleet
    @Published var boats: [LiveBoat] = []
    @Published var boatStates: [String: BoatState] = [:] // Detailed states
    @Published var ocsBoats: [String] = []
    
    // History
    @Published var logs: [LogEntry] = []
    
    // Race event timing (for recall windows)
    @Published var raceStartTime: Date?

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
    }
}
