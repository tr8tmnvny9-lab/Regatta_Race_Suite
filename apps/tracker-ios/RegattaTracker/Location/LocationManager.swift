import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentPosition: CLLocationCoordinate2D? = nil
    @Published var altitude: Double = 0.0
    @Published var speedKnots: Double = 0.0
    @Published var headingDegrees: Double = 0.0
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 0.1 // High frequency (10cm updates)
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }
    
    func start() {
        manager.requestAlwaysAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.currentPosition = loc.coordinate
            self.altitude = loc.altitude
            self.speedKnots = max(0, loc.speed * 1.94384) // meters/sec to knots
            
            if loc.course >= 0 {
                self.headingDegrees = loc.course
            }
        }
    }
}
