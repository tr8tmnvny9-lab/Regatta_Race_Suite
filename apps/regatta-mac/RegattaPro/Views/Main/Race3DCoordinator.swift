import SceneKit
import MapKit
import Combine
import SwiftUI
import SpriteKit

/// Final production-grade 3D Race Coordinator.
/// Features: Action View (Auto-switching), Premium Tiled Sponsor Wall, and high-precision Floating Origin water.
final class Race3DCoordinator: NSObject, SCNSceneRendererDelegate {
    
    var scene: SCNScene
    var cameraNode: SCNNode
    var cameraManager: CameraManager
    var waterNode: SCNNode
    private var windHUDNode: SCNNode?
    
    private var model: RaceStateModel?
    private var mapInteraction: MapInteractionModel?
    private weak var scnView: SCNView?
    private var cancellables = Set<AnyCancellable>()
    
    // Node cache
    private var boatNodes: [String: BoatNode] = [:]
    private var markNodes: [String: MarkNode] = [:]
    private var wakeNodes: [String: SCNNode] = [:]
    private var sponsorWallNode: SCNNode?
    private var startLineNode: LineNode?
    private var finishLineNode: LineNode?
    private var gateLineNodes: [String: LineNode] = [:]
    private var dtmNodes: [String: LineNode] = [:]
    
    // Coordinate Mapping
    private var originMapPoint: MKMapPoint?
    private let sceneScale: CGFloat = 100.0 // 1 unit = 1cm (sub-3cm precision)
    
    // Auto-Action State
    private var lastObservedStatus: RaceStatus?
    private var hasAutoFocusedVirtualBoat = false
    
    // Thread Safety
    private let nodeLock = NSRecursiveLock()
    private var isTornDown = false
    
    override init() {
        self.scene = SCNScene()
        
        // ─── Sky Environment ─────────────────────────────────────────────
        // Gradient sky for proper PBR reflections and much better visuals
        let skySize = CGSize(width: 1024, height: 512)
        let skyImage = NSImage(size: skySize, flipped: false) { rect in
            let gradient = NSGradient(colorsAndLocations:
                (NSColor(red: 0.12, green: 0.16, blue: 0.40, alpha: 1.0), 0.0),   // Horizon deep
                (NSColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1.0), 0.25),   // Low sky
                (NSColor(red: 0.55, green: 0.78, blue: 0.96, alpha: 1.0), 0.5),    // Mid sky
                (NSColor(red: 0.70, green: 0.88, blue: 0.98, alpha: 1.0), 0.75),   // Upper sky
                (NSColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1.0), 1.0)     // Zenith
            )
            gradient?.draw(in: rect, angle: 90)
            return true
        }
        scene.background.contents = skyImage
        scene.lightingEnvironment.contents = skyImage
        scene.lightingEnvironment.intensity = 1.5
        
        // ─── Lighting ────────────────────────────────────────────────────
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 350
        ambient.color = NSColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1800
        sun.color = NSColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1.0) // Warm sunlight
        sun.castsShadow = true
        sun.shadowSampleCount = 16
        sun.shadowRadius = 8.0
        sun.maximumShadowDistance = 500000
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.8, -0.5, 0) // Sun from upper front-left
        scene.rootNode.addChildNode(sunNode)
        
        // Fill light from opposite side (soft)
        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 400
        fill.color = NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-0.3, 2.0, 0)
        scene.rootNode.addChildNode(fillNode)
        
        // ─── Camera ──────────────────────────────────────────────────────
        self.cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 10000000
        cameraNode.camera?.zNear = 1.0
        cameraNode.camera?.fieldOfView = 60
        // Slight bloom for premium look
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.3
        cameraNode.camera?.bloomThreshold = 0.8
        cameraNode.camera?.colorFringeIntensity = 0.5
        cameraNode.camera?.vignettingIntensity = 0.3
        cameraNode.camera?.vignettingPower = 1.5
        scene.rootNode.addChildNode(cameraNode)
        
        self.cameraManager = CameraManager(cameraNode: cameraNode)
        
        // ─── Water ───────────────────────────────────────────────────────
        // Large plane with Metal-compatible animated wave shader
        let waterPlane = SCNPlane(width: 5000000, height: 5000000) // 50km x 50km
        waterPlane.widthSegmentCount = 64
        waterPlane.heightSegmentCount = 64
        
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor(red: 0.02, green: 0.12, blue: 0.28, alpha: 1.0)
        waterMaterial.lightingModel = .physicallyBased
        waterMaterial.metalness.contents = 0.05
        waterMaterial.roughness.contents = 0.35
        waterMaterial.specular.contents = NSColor.white
        // Subtle glow for deep water
        waterMaterial.emission.contents = NSColor(red: 0.0, green: 0.03, blue: 0.08, alpha: 1.0)
        
        // Metal-compatible wave shader: minor high frequency chopping to prevent Z-fighting with flat overlays
        let waveShader = """
        #pragma body
        float t = scn_frame.time;
        float wave1 = sin(_geometry.position.x * 0.15 + t * 2.0) * 0.02;
        float wave2 = sin(_geometry.position.y * 0.22 + t * 2.5) * 0.015;
        _geometry.position.z += wave1 + wave2;
        
        float nx = cos(_geometry.position.x * 0.15 + t * 2.0) * 0.015;
        float ny = cos(_geometry.position.y * 0.22 + t * 2.5) * 0.010;
        _geometry.normal = normalize(_geometry.normal + float3(nx, ny, 0.0));
        """
        waterMaterial.shaderModifiers = [.geometry: waveShader]
        
        self.waterNode = SCNNode(geometry: waterPlane)
        waterNode.eulerAngles.x = -.pi / 2
        
        super.init()
        
        waterPlane.materials = [waterMaterial]
        scene.rootNode.addChildNode(waterNode)
        setupWindHUD()
    }
    
    private func setupWindHUD() {
        let arrow = SCNCone(topRadius: 0, bottomRadius: 100, height: 800)
        arrow.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.4)
        arrow.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: arrow)
        node.eulerAngles.x = .pi / 2
        let container = SCNNode()
        container.addChildNode(node)
        windHUDNode = container
        scene.rootNode.addChildNode(container)
    }
    
    func forceAutoFocus() {
        hasAutoFocusedVirtualBoat = false
        print("📸 [DEBUG] Force Auto-Focus triggered")
    }
    
    func setup(with model: RaceStateModel, settings: MapInteractionModel, scnView: SCNView) {
        self.model = model
        self.mapInteraction = settings
        self.scnView = scnView
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ForceCameraSnap"), object: nil, queue: .main) { _ in
            self.forceAutoFocus()
        }
        
        model.objectWillChange
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.syncEverything()
            }
            .store(in: &cancellables)
            
        // Reset origin when marks change significantly
        model.$course
            .map { $0.marks.map { $0.id } }
            .removeDuplicates()
            .sink { [weak self] _ in
                print("🏁 Course changed: Resetting 3D Scene Origin")
                self?.originMapPoint = nil
            }
            .store(in: &cancellables)
            
        setupGestures(for: scnView)
        
        // Initial sync to catch fallback marks/boats even if no updates arrive
        DispatchQueue.main.async {
            self.syncEverything()
        }
    }
    
    func updateSettings(_ settings: MapInteractionModel) {
        self.mapInteraction = settings
        syncEverything()
    }
    
    func teardown() {
        nodeLock.lock()
        isTornDown = true
        nodeLock.unlock()
        
        cancellables.removeAll()
        
        nodeLock.lock()
        scene.rootNode.enumerateChildNodes { (node, _) in
            node.geometry = nil
            node.removeFromParentNode()
        }
        boatNodes.removeAll()
        markNodes.removeAll()
        wakeNodes.removeAll()
        gateLineNodes.removeAll()
        startLineNode = nil
        finishLineNode = nil
        sponsorWallNode = nil
        nodeLock.unlock()
    }
    
    // ─── Sync Logic ───
    
    private func syncEverything() {
        nodeLock.lock()
        if isTornDown { 
            nodeLock.unlock()
            return 
        }
        nodeLock.unlock()
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        syncFleet()
        syncCourse()
        autoSwitchCamera()
        SCNTransaction.commit()
    }
    
    private func autoSwitchCamera() {
        guard let model = model, mapInteraction?.isLiveMapAutoTracking == true else { return }
        
        // Only switch camera if the race state has actually changed
        if lastObservedStatus == model.status { return }
        lastObservedStatus = model.status
        
        switch model.status {
        case .preparatory, .oneMinute:
            // Focus on start line
            if let startMark = model.course.marks.first(where: { $0.type == .start }) {
                cameraManager.setMode(.broadcast(markId: startMark.id))
            }
        case .racing:
            // Focus on lead boat
            if let lead = model.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) }).first {
                cameraManager.setMode(.drone(targetId: lead.id))
            }
        default:
            cameraManager.setMode(.orbital)
        }
    }
    
    private func syncFleet() {
        guard let model = model else { return }
        let currentIds = Set(model.boats.map { $0.id })
        
        nodeLock.lock()
        for (id, node) in boatNodes where !currentIds.contains(id) {
            node.removeFromParentNode()
            boatNodes.removeValue(forKey: id)
            wakeNodes[id]?.removeFromParentNode()
            wakeNodes.removeValue(forKey: id)
        }
        let boatLength = model.boatProfiles.first?.maxLengthHull ?? 7.0
        for boat in model.boats {
            let pos = mapPointToScenePosition(boat.pos.coordinate.mapPoint)
            if boat.id == "virtual-boat-1" {
                print("🎥 [D6-MAC-3D] Heartbeat: virtual-boat-1 rendering at Scene Position: \(pos)")
                DispatchQueue.main.async {
                    self.model?.diagnosticHeartbeats["D6", default: 0] += 1
                }
            }
            if let node = boatNodes[boat.id] {
                node.position = pos
                node.update(state: boat, detail: model.boatStates[boat.id], twd: model.twd)
                updateWake(for: boat.id, at: pos, heading: boat.heading, speed: boat.speed)
                
                if boat.id == "virtual-boat-1" {
                    node.setBeaconVisible(true)
                    if !hasAutoFocusedVirtualBoat {
                        hasAutoFocusedVirtualBoat = true
                        cameraManager.setMode(.drone(targetId: boat.id))
                        print("🎯 [Race3DCoordinator] Auto-focusing on virtual boat!")
                    }
                }
            } else {
                // Determine color: use telemetry color, league boat color, or palette fallback
                let boatColor: NSColor
                if let hexColor = boat.color {
                    boatColor = NSColor(Color(regattaHex: hexColor))
                } else if let leagueBoat = model.leagueBoats.first(where: { $0.id == boat.id }) {
                    boatColor = NSColor(Color(regattaHex: leagueBoat.color))
                } else {
                    let palette: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
                    boatColor = palette[boatNodes.count % palette.count]
                }
                let teamName = boat.teamName ?? boat.id
                let node = BoatNode(boatId: boat.id, color: boatColor, teamName: teamName, boatNumber: boat.id, hullLength: boatLength)
                node.position = pos
                scene.rootNode.addChildNode(node)
                boatNodes[boat.id] = node
                createWake(for: boat.id)
                if boat.id == "virtual-boat-1" { node.setBeaconVisible(true) }
            }
        }
        
        #if DEBUG
        // 🛥️ DEVELOPMENT PRE-SPAWN: Ensure virtual-boat-1 is immediately visible for testing
        if boatNodes["virtual-boat-1"] == nil {
            let marks = model.course.marks
            if !marks.isEmpty {
            let spawnPos = marks[0].pos
            let scnPos = mapPointToScenePosition(spawnPos.coordinate.mapPoint)
            
            let node = BoatNode(boatId: "virtual-boat-1", color: .systemBlue, teamName: "VIRTUAL TEST", boatNumber: "V1", hullLength: 7.0)
            node.position = SCNVector3(scnPos.x + 4, scnPos.y, scnPos.z + 4) // offset 4m from the mark
            
            scene.rootNode.addChildNode(node)
            boatNodes["virtual-boat-1"] = node
            createWake(for: "virtual-boat-1")
            node.setBeaconVisible(true)
            print("🛥️ [RACE-3D] Pre-spawned virtual-boat-1 at course for visual confirmation.")
            }
        }
        #endif
        
        // ─── DTM Line Visualization ───
        if !model.course.marks.isEmpty {
            for boat in model.boats {
                let currentMarkIdx = min(max(0, Int(boat.legIndex ?? 0)), model.course.marks.count - 1)
                let targetMark = model.course.marks[currentMarkIdx]
                let targetPos = mapPointToScenePosition(targetMark.pos.coordinate.mapPoint)
                let pos = mapPointToScenePosition(boat.pos.coordinate.mapPoint)
                
                let boatColor = boatNodes[boat.id]?.color ?? .systemYellow
                let lineNode = dtmNodes[boat.id] ?? LineNode(color: boatColor.withAlphaComponent(0.4), width: 1.0)
                if dtmNodes[boat.id] == nil {
                    scene.rootNode.addChildNode(lineNode)
                    dtmNodes[boat.id] = lineNode
                }
                
                lineNode.setColor(boatColor.withAlphaComponent(0.4))
                lineNode.update(from: pos, to: targetPos)
            }
        }
        
        nodeLock.unlock()
    }
    
    private func createWake(for id: String) {
        let wake = SCNPlane(width: 450, height: 2500)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(white: 1.0, alpha: 0.2)
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        // Use clean Metal syntax (float2 instead of vec2, scn_frame.time instead of u_time)
        let scrollShader = """
        #pragma transparent
        float t = scn_frame.time * 2.5;
        _surface.transparent.a *= (0.5 + 0.5 * sin(_surface.diffuseTexcoord.y * 10.0 + t));
        """
        mat.shaderModifiers = [.surface: scrollShader]
        wake.materials = [mat]
        let node = SCNNode(geometry: wake)
        node.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(node)
        wakeNodes[id] = node
    }
    
    private func updateWake(for id: String, at pos: SCNVector3, heading: Double, speed: Double) {
        guard let wake = wakeNodes[id] else { return }
        wake.position = pos
        wake.eulerAngles.z = CGFloat((-heading).degreesToRadians)
        wake.opacity = CGFloat(min(1.0, speed / 3.0) * 0.6)
        wake.scale.y = CGFloat(1.0 + speed * 0.3)
    }
    
    private func syncCourse() {
        guard let model = model else { return }
        let currentIds = Set(model.course.marks.map { $0.id })
        
        nodeLock.lock()
        for (id, node) in markNodes where !currentIds.contains(id) {
            node.removeFromParentNode()
            markNodes.removeValue(forKey: id)
        }
        let boatLength = model.boatProfiles.first?.maxLengthHull ?? 7.0
        
        // 🚨 FALLBACK: If course is empty, inject a dummy mark at the origin so we know rendering works
        var marksToRender = model.course.marks
        if marksToRender.isEmpty {
            print("⚠️ [RACE-3D] Course is empty. Injecting a fallback Demo Mark at origin.")
            let fallbackMark = Buoy(id: "demo-mark-1", type: .mark, name: "Demo", pos: LatLon(lat: 60.1699, lon: 24.9384))
            marksToRender.append(fallbackMark)
        }
        
        for mark in marksToRender {
            let pos = mapPointToScenePosition(mark.pos.coordinate.mapPoint)
            if let node = markNodes[mark.id] {
                node.position = pos
                node.update(buoy: mark, showZones: model.course.settings.showMarkZones, multiplier: model.course.settings.markZoneMultiplier, twd: model.twd, boatLength: boatLength)
            } else {
                let node = MarkNode(markId: mark.id, design: mark.design ?? "cylindrical", color: .systemYellow)
                node.position = pos
                scene.rootNode.addChildNode(node)
                markNodes[mark.id] = node
                node.update(buoy: mark, showZones: model.course.settings.showMarkZones, multiplier: model.course.settings.markZoneMultiplier, twd: model.twd, boatLength: boatLength)
            }
        }
        nodeLock.unlock()
        syncStartFinishLines()
        syncSponsorWall()
    }
    
    private func syncStartFinishLines() {
        guard let model = model else { return }
        
        nodeLock.lock()
        defer { nodeLock.unlock() }

        // ─── Start Line ───
        var startP1: SCNVector3?
        var startP2: SCNVector3?
        
        // Priority 1: Explicitly defined line segments
        if let line = model.course.startLine, let p1 = line.p1, let p2 = line.p2 {
            startP1 = mapPointToScenePosition(p1.coordinate.mapPoint)
            startP2 = mapPointToScenePosition(p2.coordinate.mapPoint)
        } else {
            // Priority 2: Collect any marks with "start" type (at least 2)
            let starts = model.course.marks.filter { $0.type == .start }
            if starts.count >= 2 {
                startP1 = mapPointToScenePosition(starts[0].pos.coordinate.mapPoint)
                startP2 = mapPointToScenePosition(starts[1].pos.coordinate.mapPoint)
            }
        }
        
        if let p1 = startP1, let p2 = startP2 {
            if startLineNode == nil {
                let ln = LineNode(color: .systemYellow, width: 80.0) // 0.8m wide
                scene.rootNode.addChildNode(ln)
                startLineNode = ln
            }
            startLineNode?.update(from: p1, to: p2)
            // Extra visibility: lift it 10cm above water to stay above Waves/Clipping and buoys
            startLineNode?.position.y = 10.0 
        } else {
            startLineNode?.removeFromParentNode()
            startLineNode = nil
        }

        // ─── Finish Line ───
        var finishP1: SCNVector3?
        var finishP2: SCNVector3?
        
        if let line = model.course.finishLine, let p1 = line.p1, let p2 = line.p2 {
            finishP1 = mapPointToScenePosition(p1.coordinate.mapPoint)
            finishP2 = mapPointToScenePosition(p2.coordinate.mapPoint)
        } else {
            let finishes = model.course.marks.filter { $0.type == .finish }
            if finishes.count >= 2 {
                finishP1 = mapPointToScenePosition(finishes[0].pos.coordinate.mapPoint)
                finishP2 = mapPointToScenePosition(finishes[1].pos.coordinate.mapPoint)
            }
        }
        
        if let p1 = finishP1, let p2 = finishP2 {
            if finishLineNode == nil {
                let ln = LineNode(color: .white, width: 80.0)
                scene.rootNode.addChildNode(ln)
                finishLineNode = ln
            }
            finishLineNode?.update(from: p1, to: p2)
            finishLineNode?.position.y = 10.0
        } else {
            finishLineNode?.removeFromParentNode()
            finishLineNode = nil
        }
        
        // Gates (Siblings sync)
        let gates = model.course.marks.filter { $0.type == .gate }
        var processed = Set<String>()
        var activeGateIds = Set<String>()
        
        for m in gates {
            if processed.contains(m.id) { continue }
            let nameParts = m.name.components(separatedBy: " ")
            let prefix = nameParts.dropLast().joined(separator: " ")
            if !prefix.isEmpty, let sibling = gates.first(where: { $0.id != m.id && !processed.contains($0.id) && $0.name.hasPrefix(prefix) }) {
                let gateKey = "\(m.id)_\(sibling.id)"
                activeGateIds.insert(gateKey)
                
                if gateLineNodes[gateKey] == nil {
                    let ln = LineNode(color: .systemYellow, width: 40.0) // Thinner for gates
                    scene.rootNode.addChildNode(ln)
                    gateLineNodes[gateKey] = ln
                }
                
                let p1 = mapPointToScenePosition(m.pos.coordinate.mapPoint)
                let p2 = mapPointToScenePosition(sibling.pos.coordinate.mapPoint)
                gateLineNodes[gateKey]?.update(from: p1, to: p2)
                
                processed.insert(m.id)
                processed.insert(sibling.id)
            }
        }
        
        // Cleanup old gates
        let toRemove = gateLineNodes.keys.filter { !activeGateIds.contains($0) }
        for key in toRemove {
            gateLineNodes[key]?.removeFromParentNode()
            gateLineNodes.removeValue(forKey: key)
        }
    }
    
    private func syncSponsorWall() {
        guard let model = model, model.course.settings.show3DWall, let boundary = model.course.courseBoundary, boundary.count > 2 else {
            sponsorWallNode?.removeFromParentNode()
            sponsorWallNode = nil
            return
        }
        if sponsorWallNode == nil {
            let points = boundary.map { mapPointToScenePosition($0.coordinate.mapPoint) }
            let wall = createWallMesh(points: points)
            let node = SCNNode(geometry: wall)
            scene.rootNode.addChildNode(node)
            sponsorWallNode = node
        }
    }
    
    private func createWallMesh(points: [SCNVector3]) -> SCNGeometry {
        let height: CGFloat = 650.0
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        var texCoords: [CGPoint] = []
        
        for i in 0..<points.count {
            let p1 = points[i]; let p2 = points[(i+1)%points.count]
            let segLen = CGFloat(distance(p1, p2)) / 500.0 // Tile every 5m
            let base = Int32(vertices.count)
            vertices.append(contentsOf: [SCNVector3(p1.x, 0, p1.z), SCNVector3(p1.x, height, p1.z), SCNVector3(p2.x, 0, p2.z), SCNVector3(p2.x, height, p2.z)])
            texCoords.append(contentsOf: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: segLen, y: 0), CGPoint(x: segLen, y: 1)])
            indices.append(contentsOf: [base, base+1, base+2, base+1, base+3, base+2])
        }
        let srcV = SCNGeometrySource(vertices: vertices)
        let srcT = SCNGeometrySource(textureCoordinates: texCoords)
        let elm = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [srcV, srcT], elements: [elm])
        
        let mat = SCNMaterial()
        // Procedural Tiling Logo Logic
        let logoSize = CGSize(width: 512, height: 256)
        let scene = SKScene(size: logoSize)
        scene.backgroundColor = NSColor(white: 0.1, alpha: 0.6)
        let label = SKLabelNode(text: "REGATTA PRO")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 60
        label.position = CGPoint(x: 256, y: 128)
        scene.addChild(label)
        
        mat.diffuse.contents = scene
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.isDoubleSided = true
        geo.materials = [mat]
        return geo
    }
    
    // Shaders have been replaced by Physical Primitives (Phase 22) for 100% visual stability.
    
    private func mapPointToScenePosition(_ mp: MKMapPoint) -> SCNVector3 {
        if originMapPoint == nil || (originMapPoint?.x == 0 && originMapPoint?.y == 0) {
            // Use the centroid of current course marks as origin — fallback to Helsinki
            if let model = model, !model.course.marks.isEmpty {
                let marks = model.course.marks
                var sumLat = 0.0, sumLon = 0.0
                for m in marks { sumLat += m.pos.lat; sumLon += m.pos.lon }
                let centroid = CLLocationCoordinate2D(latitude: sumLat / Double(marks.count), longitude: sumLon / Double(marks.count))
                originMapPoint = MKMapPoint(centroid)
                print("📍 [Race3D] Origin set to course centroid: \(centroid.latitude), \(centroid.longitude)")
            } else {
                originMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384))
            }
        }
        
        guard let origin = originMapPoint else { return SCNVector3(0,0,0) }
        
        let ppm = MKMapPointsPerMeterAtLatitude(origin.coordinate.latitude)
        let dx = (mp.x - origin.x) / ppm
        let dy = (mp.y - origin.y) / ppm
        
        return SCNVector3(CGFloat(dx) * sceneScale, 0, CGFloat(dy) * sceneScale)
    }
    
    private func setupGestures(for view: SCNView) {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)
        let zoom = NSMagnificationGestureRecognizer(target: self, action: #selector(handleZoom(_:)))
        view.addGestureRecognizer(zoom)
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        unlockAutoTrack()
        let location = gesture.location(in: gesture.view)
        let translation = gesture.translation(in: gesture.view)
        
        if gesture.state == .began {
            if let hitPos = hitTestWater(at: location, in: gesture.view as? SCNView) {
                cameraManager.setPivot(to: hitPos)
            }
        }
        
        let sensitivity = Float(mapInteraction?.mapSensitivity ?? 1.0)
        
        if NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.option) {
            cameraManager.rotate(deltaX: Float(translation.x) * sensitivity, deltaY: Float(translation.y) * sensitivity)
        } else {
            cameraManager.pan(deltaX: Float(translation.x) * sensitivity, deltaY: Float(translation.y) * sensitivity)
        }
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc private func handleZoom(_ gesture: NSMagnificationGestureRecognizer) { 
        unlockAutoTrack()
        let location = gesture.location(in: gesture.view)
        let sensitivity = Float(mapInteraction?.mapSensitivity ?? 1.0)
        if let hitPos = hitTestWater(at: location, in: gesture.view as? SCNView) {
            cameraManager.zoomToward(point: hitPos, delta: Float(gesture.magnification) * sensitivity)
        } else {
            cameraManager.zoom(delta: Float(gesture.magnification) * sensitivity)
        }
    }
    
    func handleScrollWheel(with event: NSEvent, in view: SCNView) { 
        unlockAutoTrack()
        let location = view.convert(event.locationInWindow, from: nil)
        let sensitivity = Float(mapInteraction?.mapSensitivity ?? 1.0)
        if let hitPos = hitTestWater(at: location, in: view) {
            cameraManager.zoomToward(point: hitPos, delta: Float(event.scrollingDeltaY) * 0.1 * sensitivity)
        } else {
            cameraManager.zoom(delta: Float(event.scrollingDeltaY) * 0.1 * sensitivity)
        }
    }
    
    private func hitTestWater(at point: CGPoint, in view: SCNView?) -> SCNVector3? {
        guard let scnView = view else { return nil }
        // Options to only hit-test the water plane
        let results = scnView.hitTest(point, options: [
            .rootNode: waterNode,
            .searchMode: SCNHitTestSearchMode.closest.rawValue
        ])
        return results.first?.worldCoordinates
    }
    
    private func unlockAutoTrack() {
        // If user interacts, we must stop auto-tracking to prevent fighting
        if mapInteraction?.isLiveMapAutoTracking == true {
            DispatchQueue.main.async {
                self.mapInteraction?.isLiveMapAutoTracking = false
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        nodeLock.lock()
        if isTornDown {
            nodeLock.unlock()
            return
        }
        
        cameraManager.update(fleet: boatNodes, marks: markNodes)
        
        // Sync environment nodes to follow camera/target smoothly
        let target = cameraManager.smoothedTarget
        windHUDNode?.position = SCNVector3(target.x, 1500, target.z)
        if let model = model {
            windHUDNode?.eulerAngles.y = CGFloat(model.twd).degreesToRadians
        }
        waterNode.position = SCNVector3(target.x, 0, target.z)
        
        resolveHUDOverlaps(renderer: renderer)
        nodeLock.unlock()
    }
    
    private func resolveHUDOverlaps(renderer: SCNSceneRenderer) {
        let boats = Array(boatNodes.values)
        if boats.isEmpty { return }
        for b in boats { b.adjustHUDHeight(offset: 0) }
        let projected = boats.compactMap { b -> (BoatNode, SCNVector3)? in
            let pos = renderer.projectPoint(b.convertPosition(SCNVector3(0, 1150, 0), to: nil))
            if pos.z > 1.0 || pos.z < 0.0 { return nil }
            return (b, pos)
        }.sorted { $0.1.x < $1.1.x }
        if projected.count < 2 { return }
        var offsets: [String: CGFloat] = [:]
        for i in 0..<projected.count {
            let (boatA, posA) = projected[i]
            for j in (i+1)..<projected.count {
                let (boatB, posB) = projected[j]
                if abs(posA.x - posB.x) < 140 && abs(posA.y - posB.y) < 60 {
                    let curA = offsets[boatA.boatId] ?? 0; let curB = offsets[boatB.boatId] ?? 0
                    let newOff = max(curB, curA + 160); offsets[boatB.boatId] = newOff; boatB.adjustHUDHeight(offset: newOff)
                }
            }
        }
    }
    
    private func distance(_ p1: SCNVector3, _ p2: SCNVector3) -> Float {
        return Float(sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2) + pow(p1.z - p2.z, 2)))
    }
}
extension Double { var degreesToRadians: Double { self * .pi / 180 } }
extension CGFloat { var degreesToRadians: CGFloat { self * .pi / 180 } }
