import Foundation
import SceneKit
import Combine
import MapKit

/// The coordinator manages the 3D scene, coordinate transformations, and data synchronization.
final class Race3DCoordinator: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    var cameraNode: SCNNode!
    var waterNode: SCNNode!
    var sponsorWallNode: SCNNode?
    private var cameraManager: CameraManager!
    private var wakeNodes: [SCNNode] = []
    
    // Node Management
    private var boatNodes: [String: BoatNode] = [:]
    private var markNodes: [String: MarkNode] = [:]
    
    // Scale: 1 unit = 1 centimeter
    let sceneScale: Double = 100.0 // 100 units per meter
    
    // Reference point for the Cartesian grid (usually the course centroid or start line)
    var originMapPoint: MKMapPoint?
    
    private var cancellables = Set<AnyCancellable>()
    private weak var model: RaceStateModel?
    
    override init() {
        super.init()
        setupEnvironment()
    }
    
    func setup(with model: RaceStateModel) {
        self.model = model
        
        // Subscribe to wind changes for water animation
        model.$tws
            .sink { [weak self] speed in
                self?.updateWaterAnimation(speed: speed)
            }
            .store(in: &cancellables)
            
        // Subscribe to fleet updates
        model.$fleet
            .sink { [weak self] _ in
                self?.syncFleet()
            }
            .store(in: &cancellables)
            
        // Subscribe to course updates
        model.$course
            .sink { [weak self] _ in
                self?.syncCourse()
            }
            .store(in: &cancellables)
            
        // Initialize Camera Manager
        cameraManager = CameraManager(cameraNode: cameraNode)
        
        // Initial Sync
        syncFleet()
        syncCourse()
    }
    
    private func setupEnvironment() {
        // 1. Lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400
        ambientLight.color = NSColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        directionalLight.color = NSColor.white
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.position = SCNVector3(100, 500, 100)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)
        
        // 2. Initial Camera (Free Look)
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 10.0 // 10cm
        cameraNode.camera?.zFar = 1000000.0 // 10km
        cameraNode.position = SCNVector3(0, 2000, 4000) // 20m up, 40m back
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // 3. The Infinite Sea
        setupWater()
    }
    
    private func setupWater() {
        // Plane size: 10km x 10km in cm
        let waterSize: CGFloat = 1000000.0 
        let waterPlane = SCNPlane(width: waterSize, height: waterSize)
        waterPlane.widthSegmentCount = 100
        waterPlane.heightSegmentCount = 100
        
        waterNode = SCNNode(geometry: waterPlane)
        waterNode.eulerAngles.x = -.pi / 2 // Rotate to horizontal
        
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor(red: 0.0, green: 0.4, blue: 0.5, alpha: 0.8)
        waterMaterial.isDoubleSided = false
        waterMaterial.transparent.contents = 0.8
        
        // Placeholder for a tiled texture
        // waterMaterial.normal.contents = "water_normal_map"
        // waterMaterial.normal.wrapS = .repeat
        // waterMaterial.normal.wrapT = .repeat
        
        waterPlane.materials = [waterMaterial]
        scene.rootNode.addChildNode(waterNode)
        
        // Add shader modifier for vertex waves and surface color
        let waveShader = """
        uniform float twist = 0.0;
        float speed = u_time * 1.5;
        float amplitude = 12.0; // 12cm waves base
        float frequency = 0.015;
        
        // Custom simple wave sum
        _geometry.position.z += sin(_geometry.position.x * frequency + speed) * amplitude;
        _geometry.position.z += cos(_geometry.position.y * (frequency * 0.7) + speed * 1.1) * (amplitude * 0.8);
        _geometry.position.z += sin((_geometry.position.x + _geometry.position.y) * frequency * 0.5 + speed * 0.5) * (amplitude * 0.5);
        """
        
        let surfaceShader = """
        // Teal/Blue semi-transparent water with depth coloring
        vec4 baseColor = vec4(0.0, 0.45, 0.55, 0.85);
        float fresnel = pow(1.0 - dot(normalize(_surface.view), normalize(_surface.normal)), 3.0);
        _surface.diffuse = baseColor + (fresnel * 0.2);
        """
        
        waterPlane.shaderModifiers = [
            .geometry: waveShader,
            .surface: surfaceShader
        ]
    }
    
    private func updateWaterAnimation(speed: Double) {
        // Future: adjust amplitude based on speed
    }
    
    // ─── Sync Logic ───
    
    private func syncFleet() {
        guard let model = model else { return }
        let currentBoatIds = Set(model.fleet.map { $0.id })
        
        // 1. Remove boats no longer in fleet
        for (id, node) in boatNodes where !currentBoatIds.contains(id) {
            node.removeFromParentNode()
            boatNodes.removeValue(forKey: id)
        }
        
        // 2. Add or Update boats
        for boat in model.fleet {
            if let node = boatNodes[boat.id] {
                // Update position (Immediate for now, Phase 3 will add interpolation)
                let pos = mapPointToScenePosition(boat.pos.coordinate.mapPoint)
                node.position = SCNVector3(pos.x, 0, pos.z)
                node.update(state: boat, windDir: model.twd)
            } else {
                let color = colorFromString(boat.color ?? "Blue")
                let node = BoatNode(boatId: boat.id, color: color, teamName: boat.id)
                let pos = mapPointToScenePosition(boat.pos.coordinate.mapPoint)
                node.position = SCNVector3(pos.x, 0, pos.z)
                scene.rootNode.addChildNode(node)
                boatNodes[boat.id] = node
            }
        }
    }
    
    private func syncCourse() {
        guard let model = model else { return }
        
        // 1. Marks
        let currentMarkIds = Set(model.course.marks.map { $0.id })
        for (id, node) in markNodes where !currentMarkIds.contains(id) {
            node.removeFromParentNode()
            markNodes.removeValue(forKey: id)
        }
        
        for mark in model.course.marks {
            if let node = markNodes[mark.id] {
                let pos = mapPointToScenePosition(mark.pos.coordinate.mapPoint)
                node.position = SCNVector3(pos.x, 0, pos.z)
            } else {
                let color = colorFromString(mark.color ?? "Yellow")
                let design = mark.design ?? "cylindrical"
                let node = MarkNode(markId: mark.id, design: design, color: color)
                let pos = mapPointToScenePosition(mark.pos.coordinate.mapPoint)
                node.position = SCNVector3(pos.x, 0, pos.z)
                scene.rootNode.addChildNode(node)
                markNodes[mark.id] = node
            }
        }
        
        // 2. Sponsor Wall (Boundary)
        syncSponsorWall()
    }
    
    private func syncSponsorWall() {
        guard let model = model, let boundary = model.course.courseBoundary, boundary.count > 1 else {
            sponsorWallNode?.removeFromParentNode()
            sponsorWallNode = nil
            return
        }
        
        // Procedurally generate the wall mesh
        let wallHeight: Float = 300.0 // 3 meters
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        let points = boundary.map { mapPointToScenePosition($0.coordinate.mapPoint) }
        
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            
            // Two triangles for this segment
            let v1 = SCNVector3(p1.x, 0, p1.z)
            let v2 = SCNVector3(p1.x, wallHeight, p1.z)
            let v3 = SCNVector3(p2.x, 0, p2.z)
            let v4 = SCNVector3(p2.x, wallHeight, p2.z)
            
            let baseIdx = Int32(vertices.count)
            vertices.append(contentsOf: [v1, v2, v3, v4])
            
            // Triangle 1
            indices.append(contentsOf: [baseIdx, baseIdx + 1, baseIdx + 2])
            // Triangle 2
            indices.append(contentsOf: [baseIdx + 1, baseIdx + 3, baseIdx + 2])
        }
        
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(white: 1.0, alpha: 0.3)
        material.isDoubleSided = true
        material.transparent.contents = 0.4
        geometry.materials = [material]
        
        if let existing = sponsorWallNode {
            existing.geometry = geometry
        } else {
            let node = SCNNode(geometry: geometry)
            scene.rootNode.addChildNode(node)
            sponsorWallNode = node
        }
    }
    
    private func colorFromString(_ color: String) -> NSColor {
        switch color.lowercased() {
        case "red": return .systemRed
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "white": return .white
        case "black": return .black
        default: return .systemBlue
        }
    }
    
    // ─── Coordinate Mapping ───
    
    func mapPointToScenePosition(_ mp: MKMapPoint) -> SCNVector3 {
        // If origin is not set, use the first mark or a default (0,0)
        if originMapPoint == nil {
            if let firstMarkPos = model?.course.marks.first?.pos.coordinate {
                originMapPoint = firstMarkPos.mapPoint
            } else {
                // Fallback to center of course or 0,0 if nothing else
                originMapPoint = MKMapPoint(x: 0, y: 0)
            }
        }
        
        guard let origin = originMapPoint else { return SCNVector3Zero }
        
        let deltaX = mp.x - origin.x
        let deltaY = mp.y - origin.y 
        
        let pointsPerMeter = MKMapPointsPerMeterAtLatitude(origin.coordinate.latitude)
        
        let xMeters = deltaX / pointsPerMeter
        let zMeters = deltaY / pointsPerMeter 
        
        // 1.0 = 1cm precision
        return SCNVector3(xMeters * sceneScale, 0, zMeters * sceneScale)
    }
    
    // Debug: Add a pin at a specific Lat/Lon to verify mapping
    func addDebugPin(at coord: CLLocationCoordinate2D, color: NSColor) {
        let pos = mapPointToScenePosition(coord.mapPoint)
        let sphere = SCNSphere(radius: 50.0) // 50cm pin
        sphere.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(pos.x, 25, pos.z) // slightly above water
        scene.rootNode.addChildNode(node)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Per-frame state sync and interpolation
        updateWakes(atTime: time)
        
        // Update Camera
        if let model = model {
            // Auto-switch based on race status
            if model.raceStatus == .warning || model.raceStatus == .preparatory || model.raceStatus == .oneMinute {
                // Find a start mark for broadcast view
                if let startMark = model.course.marks.first(where: { $0.type == .start }) {
                    cameraManager.setMode(.broadcast(markId: startMark.id))
                }
            } else {
                cameraManager.setMode(.drone(targetId: nil)) // Default drone follow
            }
            
            cameraManager.update(fleet: boatNodes, marks: markNodes, status: model.raceStatus)
        }
    }
    
    private func updateWakes(atTime time: TimeInterval) {
        // Spawn wakes for moving boats
        for boat in model?.fleet ?? [] {
            if boat.speed > 2.0 { // Speed threshold in knots
                spawnWake(at: boat.pos.coordinate)
            }
        }
        
        // Update and cleanup existing wakes
        for node in wakeNodes {
            node.opacity -= 0.01
            node.scale = SCNVector3(node.scale.x * 1.02, 1, node.scale.z * 1.02)
            if node.opacity <= 0 {
                node.removeFromParentNode()
            }
        }
        wakeNodes.removeAll { $0.parent == nil }
    }
    
    private func spawnWake(at coord: CLLocationCoordinate2D) {
        let pos = mapPointToScenePosition(coord.mapPoint)
        let plane = SCNPlane(width: 50, height: 50)
        plane.firstMaterial?.diffuse.contents = NSColor.white
        plane.firstMaterial?.transparent.contents = 0.3
        
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(pos.x, 5, pos.z)
        node.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(node)
        wakeNodes.append(node)
    }
}

extension CLLocationCoordinate2D {
    var mapPoint: MKMapPoint { MKMapPoint(self) }
}
