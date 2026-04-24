import Foundation

struct LeagueTeam: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var club: String
    var ranking: Int = 0
    var score: Int = 0
}

struct LeagueBoat: Identifiable, Codable, Hashable {
    var id: String // e.g., "Boat 1"
    var name: String // e.g., "Red"
    var color: String // Hex or standard name
}

struct LeaguePairing: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var flightIndex: Int
    var raceIndex: Int
    var boatId: String
    var teamId: String?
    var trackerId: String?
}

struct LeagueSchedule: Codable {
    var flightCount: Int
    var boatCount: Int
    var pairings: [LeaguePairing] = []
    
    // Helper to get pairings for a specific flight/race
    func pairingsFor(flight: Int, race: Int) -> [LeaguePairing] {
        pairings.filter { $0.flightIndex == flight && $0.raceIndex == race }
    }
    
    // Manual Override Mutators
    mutating func updateTeam(flight: Int, race: Int, boatId: String, newTeamId: String?, onwards: Bool) {
        for i in 0..<pairings.count {
            if onwards {
                // Apply if flight is greater OR (same flight AND race is >= selected)
                let matchesTime = (pairings[i].flightIndex > flight) || (pairings[i].flightIndex == flight && pairings[i].raceIndex >= race)
                if matchesTime && pairings[i].boatId == boatId {
                    pairings[i].teamId = newTeamId
                }
            } else {
                if pairings[i].flightIndex == flight && pairings[i].raceIndex == race && pairings[i].boatId == boatId {
                    pairings[i].teamId = newTeamId
                }
            }
        }
    }
    
    mutating func updateBoat(flight: Int, race: Int, targetPairingId: UUID, newBoatId: String, onwards: Bool) {
        // Since boatID is foundational to how pairs are keyed across races, 
        // applying onwards by team tracking or pairing UUID is tricky. 
        // Let's implement looking up the original teamId being manipulated.
        guard let teamId = pairings.first(where: { $0.id == targetPairingId })?.teamId else { return }
        
        for i in 0..<pairings.count {
            if onwards {
                let matchesTime = (pairings[i].flightIndex > flight) || (pairings[i].flightIndex == flight && pairings[i].raceIndex >= race)
                if matchesTime && pairings[i].teamId == teamId {
                    pairings[i].boatId = newBoatId
                }
            } else {
                if pairings[i].id == targetPairingId {
                    pairings[i].boatId = newBoatId
                }
            }
        }
    }
    
    mutating func updateTracker(flight: Int, race: Int, boatId: String, newTrackerId: String?, onwards: Bool) {
        for i in 0..<pairings.count {
            if onwards {
                let matchesTime = (pairings[i].flightIndex > flight) || (pairings[i].flightIndex == flight && pairings[i].raceIndex >= race)
                if matchesTime && pairings[i].boatId == boatId {
                    pairings[i].trackerId = newTrackerId
                }
            } else {
                if pairings[i].flightIndex == flight && pairings[i].raceIndex == race && pairings[i].boatId == boatId {
                    pairings[i].trackerId = newTrackerId
                }
            }
        }
    }
}

// Extend RaceStateModel to hold the league data
extension RaceStateModel {
    // We navigate to these via Published properties for UI refresh
    // Note: These should ideally be in the main class body, but for modularity we can use an extension if we adjust accessibility
}
