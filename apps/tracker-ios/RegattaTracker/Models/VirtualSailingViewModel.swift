// VirtualSailingViewModel.swift
// Regatta Tracker — Temporary physics model for joystick-controlled sailing.

import Foundation
import Combine
import CoreLocation
import AVFoundation
import CoreImage
import CoreVideo
import UIKit

class VirtualSailingViewModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var isActive: Bool = false
    
    // Telemetry State
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var heading: Double = 0 // 0-360
    @Published var speedKnots: Double = 0 // 0-15
    @Published var roll: Double = 0 // Heeling angle
    
    // Joystick State
    @Published var joystickOffset: CGPoint = .zero // -1.0 to 1.0
    
    // Environment
    var virtualWindDir: Double = 0.0 // True North
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 0.1 // 10Hz
    private var hasWarped: Bool = false
    
    init() {}
    
    func start(initialLocation: CLLocationCoordinate2D?) {
        if let loc = initialLocation {
            self.latitude = loc.latitude
            self.longitude = loc.longitude
        } else {
            // Default Helsinki center if no GPS
            self.latitude = 60.1699
            self.longitude = 24.9384
        }
        
        self.isActive = true
        self.hasWarped = false
        
        timer?.invalidate()
        let newTimer = Timer(timeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updatePhysics()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    func stop() {
        self.isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    private func updatePhysics() {
        guard isActive else { return }
        
        // Max turn rate: 15 degrees per second at full horizontal joystick deflection
        // Dragging left (negative x) should turn left (decrease heading)
        let turnRate = Double(joystickOffset.x) * 15.0 * updateInterval
        heading = (heading + turnRate).truncatingRemainder(dividingBy: 360)
        if heading < 0 { heading += 360 }
        
        // 1.5. Speed (RC Throttle via Slider)
        // The UI Slider is bound to `speedKnots`. We don't overwrite it here so it stays persistent.
        
        // 2. Dead Reckoning
        // 1 knot = 0.514444 m/s
        let speedMetersPerSec = speedKnots * 0.514444
        let distanceMoved = speedMetersPerSec * updateInterval
        
        // Approximations for small movements
        let earthRadius = 6378137.0
        let headingRad = heading * .pi / 180.0
        
        let deltaLat = (distanceMoved * cos(headingRad)) / earthRadius
        let deltaLon = (distanceMoved * sin(headingRad)) / (earthRadius * cos(latitude * .pi / 180.0))
        
        self.latitude += (deltaLat * 180.0 / .pi)
        self.longitude += (deltaLon * 180.0 / .pi)
        
        // 3. Roll / Heeling Logic
        // Heel is higher when sailing beam reach (90 deg to wind) and at higher speeds.
        var twa = abs(heading - virtualWindDir)
        if twa > 180 { twa = 360 - twa }
        
        let heelFactor = 25.0 // Max 25 degrees of heel
        let sailEfficiency = sin(twa * .pi / 180.0) // 1.0 at 90 deg, 0.0 at 0 or 180
        let speedNormalized = speedKnots / 15.0
        
        // Calculate side of wind to determine roll direction
        let isPortTack = ((heading - virtualWindDir + 360).truncatingRemainder(dividingBy: 360)) < 180
        let targetRoll = heelFactor * sailEfficiency * speedNormalized * (isPortTack ? 1.0 : -1.0)
        
        // Smoothly interp roll
        self.roll += (targetRoll - self.roll) * 0.2
    }
    
    // Warp the boat to a specific coordinate (e.g. course center)
    // Only warps if the boat is currently at the default fallback location
    func warpToLocation(lat: Double, lon: Double) {
        guard !hasWarped else { return }
        print("⚓️ VirtualSailingViewModel: Warping to course area (\(lat), \(lon))")
        self.latitude = lat
        self.longitude = lon
        self.hasWarped = true
    }
    
    var twa: Double {
        var angle = abs(heading - virtualWindDir)
        if angle > 180 { angle = 360 - angle }
        return angle
    }
}


