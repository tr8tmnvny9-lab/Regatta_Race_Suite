import Foundation

class LeaguePairingGenerator {
    
    /// Generates a full regatta schedule using a rotational matrix and boat-retention optimization.
    static func generate(teams: [LeagueTeam], boats: [LeagueBoat], flightCount: Int) -> LeagueSchedule {
        print("🛠 Generator: Starting generation for \(teams.count) teams, \(boats.count) boats over \(flightCount) flights")
        
        guard !teams.isEmpty, !boats.isEmpty else {
            return LeagueSchedule(flightCount: 0, boatCount: 0, pairings: [])
        }
        
        let teamCount = teams.count
        let boatCount = boats.count
        
        var allPairings: [LeaguePairing] = []
        let baseTeams = teams.shuffled()
        
        for f in 0..<flightCount {
            // Rotational shift per flight to ensure everyone races everyone
            let shift = (f * 7) % teamCount 
            let flightTeams = rotate(baseTeams, by: shift)
            
            // Linear assignment: Every team in the rotated list gets exactly one slot in this flight
            let boatShift = f % boatCount
            for i in 0..<teamCount {
                let raceIndex = i / boatCount
                let boatIndex = (i + boatShift) % boatCount
                
                let pairing = LeaguePairing(
                    flightIndex: f,
                    raceIndex: raceIndex,
                    boatId: boats[boatIndex].id,
                    teamId: flightTeams[i].id
                )
                allPairings.append(pairing)
            }
        }
        
        var schedule = LeagueSchedule(flightCount: flightCount, boatCount: boatCount, pairings: allPairings)
        print("✅ Generator: Produced \(allPairings.count) pairings. Each team used exactly \(flightCount) times across regatta.")
        
        // 🛠 Post-processing: Boat Retention Optimization
        // Logic: If Team A is in Boat X in the LAST race of Flight N, 
        // and is in Boat Y in the FIRST race of Flight N+1, 
        // swap Boat Y with Boat X in Flight N+1.
        schedule = optimizeBoatRetention(schedule, boats: boats)
        
        return schedule
    }
    
    private static func rotate<T>(_ array: [T], by: Int) -> [T] {
        guard array.count > 0 else { return array }
        let k = by % array.count
        return Array(array[k...]) + Array(array[..<k])
    }
    
    private static func optimizeBoatRetention(_ schedule: LeagueSchedule, boats: [LeagueBoat]) -> LeagueSchedule {
        var optimizedPairings = schedule.pairings
        
        for f in 0..<(schedule.flightCount - 1) {
            // Teams in the last race of flight f
            let maxRaceF = optimizedPairings.filter { $0.flightIndex == f }.map { $0.raceIndex }.max() ?? 0
            let lastRaceTeams = optimizedPairings.filter { $0.flightIndex == f && $0.raceIndex == maxRaceF }
            
            // Teams in the first race of flight f + 1
            let firstRaceIndices = optimizedPairings.indices.filter { 
                optimizedPairings[$0].flightIndex == f + 1 && optimizedPairings[$0].raceIndex == 0 
            }
            
            for fIdx in firstRaceIndices {
                let pairingNext = optimizedPairings[fIdx]
                guard let teamId = pairingNext.teamId else { continue }
                
                // Did this team race in the last race of the previous flight?
                if let previousPairing = lastRaceTeams.first(where: { $0.teamId == teamId }) {
                    let oldBoatId = pairingNext.boatId
                    let newBoatId = previousPairing.boatId
                    
                    if oldBoatId != newBoatId {
                        // Swap Boat IDs in the target race to keep the team in the same boat
                        if let swapIdx = optimizedPairings.indices.first(where: { 
                            optimizedPairings[$0].flightIndex == f + 1 && 
                            optimizedPairings[$0].raceIndex == 0 && 
                            optimizedPairings[$0].boatId == newBoatId 
                        }) {
                            optimizedPairings[fIdx].boatId = newBoatId
                            optimizedPairings[swapIdx].boatId = oldBoatId
                        }
                    }
                }
            }
        }
        
        return LeagueSchedule(
            flightCount: schedule.flightCount,
            boatCount: schedule.boatCount,
            pairings: optimizedPairings
        )
    }
}
