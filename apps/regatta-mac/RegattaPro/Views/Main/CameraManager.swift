import SceneKit
import Foundation

/// Manages camera modes and smooth transitions for the 3D race view.
final class CameraManager {
    enum CameraMode {
        case drone(targetId: String?) // Follows a specific boat or the leader
        case broadcast(markId: String) // Fixed view from a mark (usually committee boat)
        case free // Manual control
    }
    
    private let cameraNode: SCNNode
    private var currentMode: CameraMode = .free
    
    init(cameraNode: SCNNode) {
        self.cameraNode = cameraNode
    }
    
    func setMode(_ mode: CameraMode) {
        self.currentMode = mode
    }
    
    func update(fleet: [String: BoatNode], marks: [String: MarkNode], status: RaceStatus) {
        switch currentMode {
        case .drone(let targetId):
            updateDroneView(targetId: targetId, fleet: fleet)
        case .broadcast(let markId):
            updateBroadcastView(markId: markId, marks: marks)
        case .free:
            break
        }
    }
    
    private func updateDroneView(targetId: String?, fleet: [String: BoatNode]) {
        guard let targetNode = targetId.flatMap({ fleet[$0] }) ?? fleet.values.first else { return }
        
        let targetPos = targetNode.position
        let cameraTarget = SCNVector3(targetPos.x, targetPos.y + 500, targetPos.z + 1000) // 5m up, 10m back
        
        // Simple linear interpolation for camera position (Damping)
        cameraNode.position = lerp(from: cameraNode.position, to: cameraTarget, t: 0.1)
        
        // Ensure camera looks at the boat
        let lookAtNode = SCNNode()
        lookAtNode.position = targetPos
        cameraNode.look(at: targetPos)
    }
    
    private func updateBroadcastView(markId: String, marks: [String: MarkNode]) {
        guard let markNode = marks[markId] else { return }
        
        // Position on the committee boat (offset from mark)
        let markPos = markNode.position
        let cameraPos = SCNVector3(markPos.x + 500, markPos.y + 500, markPos.z)
        
        cameraNode.position = lerp(from: cameraNode.position, to: cameraPos, t: 0.05)
        cameraNode.look(at: SCNVector3(0, 0, 0)) // Look towards course center
    }
    
    private func lerp(from: SCNVector3, to: SCNVector3, t: Float) -> SCNVector3 {
        return SCNVector3(
            from.x + (to.x - from.x) * t,
            from.y + (to.y - from.y) * t,
            from.z + (to.z - from.z) * t
        )
    }
}
