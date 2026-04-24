import SceneKit
import Foundation

/// A 3D representation of a race course mark, including standard buoys and MarkSetBot.
final class MarkNode: SCNNode {
    let markId: String
    let design: String // "cylindrical", "spherical", "spar", "marksetbot"
    
    private var zoneNode: SCNNode?
    private var starboardLayline: SCNNode?
    private var portLayline: SCNNode?
    
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
        self.position = SCNVector3(0, geo.boundingBox.max.y, 0) // Sit on water
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
    
    func update(buoy: Buoy, showZones: Bool, multiplier: Double, twd: Double, boatLength: Double) {
        // 1. Zone Rendering (SCNTube for high-stability circle)
        if showZones {
            let radius = CGFloat(boatLength * 100.0 * multiplier) 
            if zoneNode == nil {
                let tube = SCNTube(innerRadius: radius - 20, outerRadius: radius, height: 10)
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor.cyan.withAlphaComponent(0.6)
                mat.lightingModel = .constant
                tube.materials = [mat]
                let node = SCNNode(geometry: tube)
                node.position = SCNVector3(0, 5, 0) // Just above water
                addChildNode(node)
                zoneNode = node
            } else if let tube = zoneNode?.geometry as? SCNTube {
                tube.innerRadius = radius - 20
                tube.outerRadius = radius
            }
            zoneNode?.isHidden = false
        } else {
            zoneNode?.isHidden = true
        }
        
        // 2. Layline Rendering (SCNBox "lasers")
        if buoy.showLaylines {
            setupLaylines(twd: twd)
            starboardLayline?.isHidden = false
            portLayline?.isHidden = false
        } else {
            starboardLayline?.isHidden = true
            portLayline?.isHidden = true
        }
    }
    
    private func setupLaylines(twd: Double) {
        if starboardLayline == nil {
            let box = SCNBox(width: 5, height: 2, length: 100000, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.red.withAlphaComponent(0.8)
            mat.lightingModel = .constant
            box.materials = [mat]
            
            let sNode = SCNNode(geometry: box)
            sNode.position = SCNVector3(0, 2, 50000) // Offset along Z-axis (length)
            let sContainer = SCNNode()
            sContainer.addChildNode(sNode)
            addChildNode(sContainer)
            starboardLayline = sContainer
            
            let pNode = SCNNode(geometry: box)
            pNode.position = SCNVector3(0, 2, 50000)
            let pContainer = SCNNode()
            pContainer.addChildNode(pNode)
            addChildNode(pContainer)
            portLayline = pContainer
        }
        
        // Rotate to match TWA (45 deg off TWD)
        // Note: twd is in degrees, SceneKit uses radians
        let twdDeg = twd
        starboardLayline?.eulerAngles.y = CGFloat(180 - (twdDeg + 45)).degreesToRadians
        portLayline?.eulerAngles.y = CGFloat(180 - (twdDeg - 45)).degreesToRadians
    }
}
