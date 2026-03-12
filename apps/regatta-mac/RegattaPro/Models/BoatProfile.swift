import Foundation

/// 3D Tracker Mounting Offset relative to the front-center of the deck.
struct TrackerMount: Codable, Equatable {
    /// Offset towards the aft of the boat (meters). Positive is backwards from the bow.
    var offsetX: Double
    /// Offset towards port/starboard (meters). Positive is starboard.
    var offsetY: Double
    /// Height offset above the deck (meters). Positive is up.
    var offsetZ: Double
    /// Mounting orientation azimuth angle (degrees).
    var mountingAzimuth: Double
    /// Mounting orientation elevation angle (degrees).
    var mountingElevation: Double
    
    static let defaultMount = TrackerMount(offsetX: 1.5, offsetY: 0, offsetZ: 0.1, mountingAzimuth: 0, mountingElevation: 0)
}

/// Geometric profile of a physical racing boat. Used by the UWB solver to identify edge extremities.
struct BoatProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    
    /// Maximum length of the vessel including the bow pole (meters).
    var maxLengthPole: Double
    /// Length of the physical hull excluding the pole (meters).
    var maxLengthHull: Double
    /// Maximum width of the deck (meters).
    var maxWidthDeck: Double
    
    /// The physical location of the UWB Tracker relative to the boat's bow.
    var mount: TrackerMount
    
    static let defaultProfile = BoatProfile(
        id: UUID().uuidString,
        name: "Standard 40ft Racer",
        maxLengthPole: 12.5,
        maxLengthHull: 11.9,
        maxWidthDeck: 3.8,
        mount: .defaultMount
    )
}
