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
}

struct LeagueSchedule: Codable {
    var flightCount: Int
    var boatCount: Int
    var pairings: [LeaguePairing] = []
    
    // Helper to get pairings for a specific flight/race
    func pairingsFor(flight: Int, race: Int) -> [LeaguePairing] {
        pairings.filter { $0.flightIndex == flight && $0.raceIndex == race }
    }
}

// Extend RaceStateModel to hold the league data
extension RaceStateModel {
    // We navigate to these via Published properties for UI refresh
    // Note: These should ideally be in the main class body, but for modularity we can use an extension if we adjust accessibility
}
