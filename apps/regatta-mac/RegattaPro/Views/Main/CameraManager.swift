import SceneKit
import Foundation

/// Manages camera modes and smooth transitions for the 3D race view.
/// Hard constraints: horizon lock, no underwater, auto-center on course.
final class CameraManager {
    enum CameraMode {
        case drone(targetId: String?)
        case broadcast(markId: String)
        case orbital
    }
    
    private let cameraNode: SCNNode
    private var currentMode: CameraMode = .orbital
    
    // Logical target (the point we are looking at)
    private var targetPos = SCNVector3(0, 0, 0)
    
    // Spherical coordinates relative to target
    private var yaw: CGFloat = 0.0
    private var pitch: CGFloat = 0.45        // Start at ~25° above horizon
    private var distance: CGFloat = 15000.0  // Start zoomed out to see course (~150m)
    
    // Hard limits
    private let minPitch: CGFloat = 0.12     // ~7° — never go below horizon
    private let maxPitch: CGFloat = 1.40     // ~80° — lock gimbal well below zenith to prevent horizon inversion
    private let minDistance: CGFloat = 300.0  // 3m minimum zoom
    private let maxDistance: CGFloat = 10000000.0
    private let minCameraY: CGFloat = 50.0   // Camera never goes below 50cm above water
    
    // Smooth rendering states
    var smoothedTarget = SCNVector3(0, 0, 0)
    
    // Track if we've auto-centered on the course
    private var hasAutoCentered = false
    
    init(cameraNode: SCNNode) {
        self.cameraNode = cameraNode
        updateNodeTransform(instant: true)
    }
    
    func setMode(_ mode: CameraMode) {
        self.currentMode = mode
    }
    
    /// Called once when marks first appear to center the camera on the course.
    func autoCenterOnCourse(marks: [String: MarkNode]) {
        guard !hasAutoCentered, !marks.isEmpty else { return }
        hasAutoCentered = true
        
        // Find the centroid of all marks
        var sumX: CGFloat = 0, sumZ: CGFloat = 0
        for (_, node) in marks {
            sumX += node.position.x
            sumZ += node.position.z
        }
        let count = CGFloat(marks.count)
        let center = SCNVector3(sumX / count, 0, sumZ / count)
        
        // Find the max distance from center to any mark — zoom to fit
        var maxDist: CGFloat = 0
        for (_, node) in marks {
            let dx = node.position.x - center.x
            let dz = node.position.z - center.z
            let d = sqrt(dx*dx + dz*dz)
            if d > maxDist { maxDist = d }
        }
        
        targetPos = center
        smoothedTarget = center
        distance = max(5000, maxDist * 2.5) // Enough to see everything with margin
        pitch = 0.55 // ~31° — good overview angle
        yaw = 0.0
        
        updateNodeTransform(instant: true)
        print("📸 [CameraManager] Auto-centered on \(marks.count) marks, distance: \(distance)")
    }
    
    // ─── Interaction ───
    
    /// Shifts the rotation center to a new point while keeping the camera in the same world position.
    func setPivot(to worldPos: SCNVector3) {
        let camPos = cameraNode.presentation.position
        targetPos = worldPos
        
        let dx = CGFloat(camPos.x - targetPos.x)
        let dy = CGFloat(camPos.y - targetPos.y)
        let dz = CGFloat(camPos.z - targetPos.z)
        
        distance = sqrt(dx*dx + dy*dy + dz*dz)
        pitch = asin(dy / max(distance, 1.0))
        yaw = atan2(dx, dz)
        
        clampValues()
    }
    
    func rotate(deltaX: Float, deltaY: Float) {
        currentMode = .orbital
        
        let sensitivity = 0.012 * (distance / 5000.0)
        yaw -= CGFloat(deltaX) * sensitivity
        pitch -= CGFloat(deltaY) * sensitivity
        
        clampValues()
    }
    
    func zoom(delta: Float) {
        currentMode = .orbital
        
        let step = distance * 0.1 * CGFloat(delta)
        distance -= step
        
        // Smart Zoom: Tilt towards top-down as we zoom out, towards horizon as we zoom in
        let tiltFactor = (distance - minDistance) / (200000 - minDistance)
        let targetPitch = 0.2 + (1.3 * max(0, min(1, tiltFactor)))
        pitch = pitch + (targetPitch - pitch) * 0.1
        
        clampValues()
    }
    
    /// Zooms towards a specific point (e.g. cursor)
    func zoomToward(point: SCNVector3, delta: Float) {
        setPivot(to: point)
        zoom(delta: delta)
    }
    
    func pan(deltaX: Float, deltaY: Float) {
        currentMode = .orbital
        
        let zoomFactor = distance / 5000.0
        let sY = sin(yaw)
        let cY = cos(yaw)
        
        let dx = -CGFloat(deltaX) * zoomFactor
        let dz = -CGFloat(deltaY) * zoomFactor
        
        targetPos.x += dx * cY - dz * sY
        targetPos.z += dx * sY + dz * cY
    }
    
    /// Clamp all values to hard limits
    private func clampValues() {
        pitch = max(minPitch, min(maxPitch, pitch))
        distance = max(minDistance, min(maxDistance, distance))
    }
    
    // ─── Frame Update ───
    
    func update(fleet: [String: BoatNode], marks: [String: MarkNode]) {
        // Auto-center on first marks
        autoCenterOnCourse(marks: marks)
        
        // Sync target state from auto-modes
        switch currentMode {
        case .drone(let id):
            if let boat = id.flatMap({ fleet[$0] }) ?? fleet.values.first {
                targetPos = boat.position
            }
        case .broadcast(let id):
            if let mark = marks[id] {
                targetPos = mark.position
            }
        case .orbital:
            break
        }
        
        updateNodeTransform(instant: false)
    }
    
    private func updateNodeTransform(instant: Bool) {
        let t: CGFloat = instant ? 1.0 : 0.15 // Smooth damping
        
        // Smoothly follow the target point
        smoothedTarget = SCNVector3(
            smoothedTarget.x + (targetPos.x - smoothedTarget.x) * t,
            0, // Target always on water surface
            smoothedTarget.z + (targetPos.z - smoothedTarget.z) * t
        )
        
        // Calculate ideal position in spherical space
        let x = smoothedTarget.x + distance * cos(pitch) * sin(yaw)
        var y = smoothedTarget.y + distance * sin(pitch)
        let z = smoothedTarget.z + distance * cos(pitch) * cos(yaw)
        
        // HARD CLAMP: Camera never goes below water (Y must be positive)
        y = max(minCameraY, y)
        
        let idealPos = SCNVector3(x, y, z)
        
        // Smoothly move camera node
        cameraNode.position = SCNVector3(
            cameraNode.position.x + (idealPos.x - cameraNode.position.x) * t,
            cameraNode.position.y + (idealPos.y - cameraNode.position.y) * t,
            cameraNode.position.z + (idealPos.z - cameraNode.position.z) * t
        )
        
        // HORIZON LOCK: Look at target with world-up always pointing Y+
        cameraNode.look(at: smoothedTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        
        // Force roll to zero (belt and suspenders)
        cameraNode.eulerAngles.z = 0
    }
}
