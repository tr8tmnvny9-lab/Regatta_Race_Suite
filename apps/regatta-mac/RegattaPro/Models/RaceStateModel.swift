import Foundation
import Combine
import SwiftUI

// Aligning with standard Apple patterns
enum RacePhase: String, Codable {
    case idle = "idle"
    case sequences = "sequences"
    case racing = "racing"
    case complete = "complete"
}

// Temporary data structure
struct LiveBoat: Identifiable {
    let id: String
    var position: CGPoint // Just plotting arbitrarily for now
    var speed: Double
    var heading: Double
}

final class RaceStateModel: ObservableObject {
    @Published var currentPhase: RacePhase = .idle
    @Published var timeRemaining: Double = 0
    @Published var activeFlags: [String] = []
    
    // Boat telemetry
    @Published var boats: [LiveBoat] = []
    
    // Fleet/Pairing
    @Published var isLeagueMode: Bool = false
    
    // Wind properties
    @Published var tws: Double = 0.0
    @Published var twd: Double = 0.0

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
        
        // Very rough wind parsing
        if let wind = json["wind"] as? [String: Any] {
            if let speed = wind["tws"] as? Double { tws = speed }
            if let dir = wind["twd"] as? Double { twd = dir }
        }
        
        // In a real scenario we'd parse "fleet" or "tracks", but we'll mock it for now
        // if we just get a state ping.
    }
}
