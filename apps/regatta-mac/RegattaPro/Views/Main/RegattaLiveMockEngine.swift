import SwiftUI
import Combine
import CoreLocation

/// Provides high-frequency mock data isolated from the real Rust backend to allow
/// for 60fps premium UI tuning (animations, colors, layout responsiveness).
final class RegattaLiveMockEngine: ObservableObject {
    @Published var timeRemaining: Double = 300 // 5:00 minutes
    @Published var raceStateString: String = "PRE-START"
    @Published var tws: Double = 12.4
    @Published var twd: Double = 235.0
    @Published var isActive: Bool = true
    
    @Published var boats: [LiveBoat] = []
    
    // Core timing
    private var timerCancellable: AnyCancellable?
    
    init() {
        setupMockFleet()
        startEngine()
    }
    
    private func createBoat(id: String, lat: Double, lon: Double, speed: Double, heading: Double, color: String, rank: Int, teamName: String) -> LiveBoat {
        var b = LiveBoat(id: id, pos: LatLon(lat: lat, lon: lon), speed: speed, heading: heading, color: color, role: .sailboat)
        b.rank = rank
        b.teamName = teamName
        b.cog = heading
        b.sog = speed
        return b
    }
    
    private func setupMockFleet() {
        // Create 6 premium looking test boats
        boats = [
            createBoat(id: "USA", lat: 37.8, lon: -122.4, speed: 38.4, heading: 45, color: "#FF0033", rank: 1, teamName: "American Magic"),
            createBoat(id: "NZL", lat: 37.801, lon: -122.399, speed: 41.2, heading: 42, color: "#000000", rank: 2, teamName: "Emirates Team NZ"),
            createBoat(id: "ITA", lat: 37.799, lon: -122.402, speed: 36.1, heading: 48, color: "#C0C0C0", rank: 3, teamName: "Luna Rossa"),
            createBoat(id: "GBR", lat: 37.795, lon: -122.405, speed: 35.8, heading: 50, color: "#00246B", rank: 4, teamName: "INEOS Britannia"),
            createBoat(id: "FRA", lat: 37.790, lon: -122.410, speed: 42.5, heading: 35, color: "#1F3A93", rank: 5, teamName: "Orient Express"),
            createBoat(id: "SUI", lat: 37.788, lon: -122.412, speed: 32.0, heading: 60, color: "#D11141", rank: 6, teamName: "Alinghi Red Bull")
        ]
    }
    
    private func startEngine() {
        // High frequency 60Hz loop for buttery smooth UI data bindings
        timerCancellable = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        // 1. Tick Master Clock backwards at exactly real time
        timeRemaining -= (1.0 / 60.0)
        if timeRemaining <= 0 {
            timeRemaining = 1200 // loop back to 20 mins
            raceStateString = "RACING"
        }
        
        // 2. Fluctuate Speeds smoothly using sine waves based on time
        let t = Date().timeIntervalSince1970
        
        for i in 0..<boats.count {
            // Jitter speed +/- 2 knots smoothly over a few seconds
            let speedVariance = sin(t * Double(i + 1) * 0.5) * 2.0
            
            // Subtly move position to test vector map translations
            let latMove = cos(t * 0.1 + Double(i)) * 0.00001
            let lonMove = sin(t * 0.1 + Double(i)) * 0.00001
            
            // Jitter heading slowly
            let headVariance = sin(t * 0.2 + Double(i)) * 1.5
            
            // Build new struct to force SwiftUI state update
            var b = boats[i]
            
            // We use the base logic to generate plausible numbers
            let baseS: Double = [38.4, 41.2, 36.1, 35.8, 42.5, 32.0][i]
            let baseH: Double = [45, 42, 48, 50, 35, 60][i]
            
            b.speed = baseS + speedVariance
            b.heading = baseH + headVariance
            b.pos = LatLon(lat: b.pos.lat + latMove, lon: b.pos.lon + lonMove)
            
            // Occasionally randomly swap ranks for testing implicit animations
            if Int.random(in: 0...600) == 0 { // about once every 10 seconds per boat
                // Shift ranks
                let oldRank = b.rank ?? 99
                let newRank = max(1, min(6, oldRank + (Int.random(in: 0...1) == 0 ? 1 : -1)))
                b.rank = newRank
            }
            
            boats[i] = b
        }
        
        // Ensure ranks are unique if they got randomly swapped
        boats.sort { ($0.rank ?? 99) < ($1.rank ?? 99) }
        for i in 0..<boats.count {
            boats[i].rank = i + 1
        }
    }
    
    deinit {
        timerCancellable?.cancel()
    }
}
