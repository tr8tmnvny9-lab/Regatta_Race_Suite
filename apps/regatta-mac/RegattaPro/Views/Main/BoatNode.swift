import SceneKit
import Foundation

/// A 3D representation of a J70 sailboat.
final class BoatNode: SCNNode {
    let boatId: String
    
    // Components
    private var hullNode: SCNNode?
    private var mastNode: SCNNode?
    private var mainSailNode: SCNNode?
    private var jennakerNode: SCNNode?
    private var boatNumberNode: SCNNode?
    
    // Identity elements
    private var nameTagNode: SCNNode?
    
    init(boatId: String, color: NSColor, teamName: String) {
        self.boatId = boatId
        super.init()
        setupBoat(color: color, teamName: teamName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBoat(color: NSColor, teamName: String) {
        // Initial placeholder geometry (Primitives)
        // Hull
        let hull = SCNCone(topRadius: 40, bottomRadius: 100, height: 700) // 7m long, ~1m wide
        let hullMaterial = SCNMaterial()
        hullMaterial.diffuse.contents = color
        hull.materials = [hullMaterial]
        
        let hullN = SCNNode(geometry: hull)
        hullN.eulerAngles.x = .pi / 2
        hullN.position = SCNVector3(0, 50, 0)
        hullNode = hullN
        addChildNode(hullN)
        
        // Mast
        let mast = SCNCylinder(radius: 5, height: 900) // 9m mast
        let mastN = SCNNode(geometry: mast)
        mastN.position = SCNVector3(0, 450, 100)
        mastNode = mastN
        addChildNode(mastN)
        
        // Identity Tag (Billboard)
        setupIdentity(teamName: teamName)
    }
    
    private func setupIdentity(teamName: String) {
        let text = SCNText(string: teamName, extrusionDepth: 2.0)
        text.font = NSFont.boldSystemFont(ofSize: 40)
        text.firstMaterial?.diffuse.contents = NSColor.white
        
        let textNode = SCNNode(geometry: text)
        let (min, max) = text.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation((max.x - min.x) / 2, 0, 0)
        textNode.scale = SCNVector3(1, 1, 1) // 1:1 scale
        
        let container = SCNNode()
        container.position = SCNVector3(0, 1000, 0) // 10m above water
        container.addChildNode(textNode)
        
        // Billboard constraint ensures it always faces the camera
        container.constraints = [SCNBillboardConstraint()]
        
        nameTagNode = container
        addChildNode(container)
        
        // Boat Number on Hull/Bow
        setupBoatNumber()
    }
    
    private func setupBoatNumber() {
        let text = SCNText(string: "#07", extrusionDepth: 1.0) // Mock number
        text.font = NSFont.boldSystemFont(ofSize: 20)
        text.firstMaterial?.diffuse.contents = NSColor.white
        
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(1, 1, 1)
        node.position = SCNVector3(100, 50, 200) // Position on bow
        node.eulerAngles.y = .pi / 2
        hullNode?.addChildNode(node)
        boatNumberNode = node
    }
    
    func update(state: LiveBoat, windDir: Double) {
        // Update heeling (Z-rotation) from IMU
        // We use the boat's roll data. 
        if let roll = state.imu?.roll {
            self.eulerAngles.z = Float(roll.degreesToRadians)
        }
        
        // Update heading (Y-rotation)
        self.eulerAngles.y = Float((-state.heading).degreesToRadians)
        
        // Update sail visibility based on wind angle
    }
}

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
