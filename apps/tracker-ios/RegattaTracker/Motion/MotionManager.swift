import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    @Published var accelerometerData: CMAcceleration?
    @Published var gyroData: CMRotationRate?
    @Published var magnetometerData: CMMagneticField?
    @Published var relativeAltitude: Double = 0.0
    
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    
    init() {
        motionManager.accelerometerUpdateInterval = 0.02 // 50Hz
        motionManager.gyroUpdateInterval = 0.02
        motionManager.magnetometerUpdateInterval = 0.1 // 10Hz is enough for mag
    }
    
    func start() {
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                self?.accelerometerData = data?.acceleration
            }
        }
        
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
                self?.gyroData = data?.rotationRate
            }
        }
        
        if motionManager.isMagnetometerAvailable {
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                self?.magnetometerData = data?.magneticField
            }
        }
        
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                self?.relativeAltitude = data?.relativeAltitude.doubleValue ?? 0.0
            }
        }
    }
    
    func stop() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}
