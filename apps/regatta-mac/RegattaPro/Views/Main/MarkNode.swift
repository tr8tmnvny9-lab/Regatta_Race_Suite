import SceneKit
import Foundation

/// A 3D representation of a race course mark, including standard buoys and MarkSetBot.
final class MarkNode: SCNNode {
    let markId: String
    let design: String // "cylindrical", "spherical", "spar", "marksetbot"
    
    init(markId: String, design: String, color: NSColor) {
        self.markId = markId
        self.design = design.lowercased()
        super.init()
        setupMark(color: color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMark(color: NSColor) {
        switch design {
        case "marksetbot":
            setupMarkSetBot(color: color)
        case "spherical":
            let geo = SCNSphere(radius: 100) // 1m radius
            applyGeo(geo, color: color)
        case "spar":
            let geo = SCNCylinder(radius: 20, height: 300) // 3m tall spar
            applyGeo(geo, color: NSColor.yellow) // Spars often yellow
        default: // cylindrical
            let geo = SCNCylinder(radius: 60, height: 150) // Standard buoy
            applyGeo(geo, color: color)
        }
    }
    
    private func applyGeo(_ geo: SCNGeometry, color: NSColor) {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        geo.materials = [mat]
        self.geometry = geo
        self.position = SCNVector3(0, Float(geo.boundingBox.max.y), 0) // Sit on water
    }
    
    private func setupMarkSetBot(color: NSColor) {
        // Base (Dual Pontoon)
        let base = SCNBox(width: 150, height: 40, length: 150, chamferRadius: 10)
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = NSColor.darkGray
        base.materials = [baseMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 20, 0)
        addChildNode(baseNode)
        
        // Canopy (Orange/Yellow inflatable)
        let canopy = SCNCone(topRadius: 40, bottomRadius: 70, height: 100)
        let canopyMaterial = SCNMaterial()
        canopyMaterial.diffuse.contents = NSColor.orange
        canopy.materials = [canopyMaterial]
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.position = SCNVector3(0, 90, 0)
        addChildNode(canopyNode)
        
        // Antenna/Mast
        let antenna = SCNCylinder(radius: 2, height: 200)
        let antennaNode = SCNNode(geometry: antenna)
        antennaNode.position = SCNVector3(0, 140, 0)
        addChildNode(antennaNode)
    }
}
