import Foundation
import CoreLocation
import Combine

/// Mathematical spline interpolation to scale 1Hz iPhone GPS up to 20Hz UWB mesh frequency
class GPSSplineInterpolator {
    private var anchorPoints: [(time: TimeInterval, coord: CLLocationCoordinate2D, speed: Double)] = []
    
    func addPoint(_ location: CLLocation) {
        anchorPoints.append((time: location.timestamp.timeIntervalSince1970, coord: location.coordinate, speed: location.speed))
        if anchorPoints.count > 5 {
            anchorPoints.removeFirst()
        }
    }
    
    func evaluate(at time: TimeInterval) -> (CLLocationCoordinate2D, Double)? {
        guard anchorPoints.count >= 2 else { return nil }
        
        // Find surrounding points
        var p0: (time: TimeInterval, coord: CLLocationCoordinate2D, speed: Double)!
        var p1: (time: TimeInterval, coord: CLLocationCoordinate2D, speed: Double)!
        
        for i in 0..<(anchorPoints.count - 1) {
            if time >= anchorPoints[i].time && time <= anchorPoints[i+1].time {
                p0 = anchorPoints[i]
                p1 = anchorPoints[i+1]
                break
            }
        }
        
        // If we requested a time beyond our newest anchor, extrapolate linearly (dead reckoning)
        if p0 == nil {
            let last = anchorPoints.last!
            let prev = anchorPoints[anchorPoints.count - 2]
            
            let dt = last.time - prev.time
            guard dt > 0 else { return (last.coord, last.speed) }
            
            let dTimeFromLast = time - last.time
            
            // Simple linear extrapolation based on speed
            let latDeriv = (last.coord.latitude - prev.coord.latitude) / dt
            let lonDeriv = (last.coord.longitude - prev.coord.longitude) / dt
            let speedDeriv = (last.speed - prev.speed) / dt
            
            let newLat = last.coord.latitude + (latDeriv * dTimeFromLast)
            let newLon = last.coord.longitude + (lonDeriv * dTimeFromLast)
            let newSpeed = last.speed + (speedDeriv * dTimeFromLast)
            
            return (CLLocationCoordinate2D(latitude: newLat, longitude: newLon), max(0, newSpeed))
        }
        
        // Interpolate using linear interpolation for now (cubic spline is overkill for 1Hz gaps with straight ship paths)
        let dt = p1.time - p0.time
        let t = (time - p0.time) / dt
        
        let interpLat = p0.coord.latitude + (p1.coord.latitude - p0.coord.latitude) * t
        let interpLon = p0.coord.longitude + (p1.coord.longitude - p0.coord.longitude) * t
        let interpSpeed = p0.speed + (p1.speed - p0.speed) * t
        
        return (CLLocationCoordinate2D(latitude: interpLat, longitude: interpLon), interpSpeed)
    }
}

/// Emulates a UWB Mesh hardware node over Bluetooth GATT
class UWBEmulator: ObservableObject {
    private var timer: AnyCancellable?
    private let interpolator = GPSSplineInterpolator()
    private var isSimulating = false
    
    var onPacketGenerated: ((Data) -> Void)?
    
    func ingestRealGPS(_ location: CLLocation) {
        interpolator.addPoint(location)
    }
    
    func start() {
        guard !isSimulating else { return }
        isSimulating = true
        
        // Run at 20Hz (50ms superframe)
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateEmulatedPacket()
            }
    }
    
    func stop() {
        isSimulating = false
        timer?.cancel()
        timer = nil
    }
    
    private func generateEmulatedPacket() {
        let now = Date().timeIntervalSince1970
        guard let (simCoord, _) = interpolator.evaluate(at: now) else { return }
        
        // In a full implementation, we would query RaceStateModel mapping to get the Mark positions
        // and calculate Euclidean distance, add 5mm Gaussian noise, and pack the `MeasurementPacket` bytes.
        // For emulator stubbing: we return a mocked Data payload that the BLE client parses.
        
        // Mock distances (y_line representation usually injected by the backend solve, but BLE client reads raw data)
        // Here we just fabricate an escalating payload mimicking the CoreBluetooth signature.
        var data = Data(repeating: 0, count: 16)
        
        // Offset 4-7 is the Y-line float32 in our debug mock definition
        let fakeYLine: Float32 = Float32(sin(now) * 5.0) // Bobbing between +/- 5 meters
        let yLineBytes = withUnsafeBytes(of: fakeYLine) { Data($0) }
        data.replaceSubrange(4..<8, with: yLineBytes)
        
        onPacketGenerated?(data)
    }
}
