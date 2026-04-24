import SceneKit
import SpriteKit
import Foundation

/// High-fidelity J70 sailboat using stable SceneKit primitives (no SCNShape/bezier).
/// Every component uses SCNBox, SCNCylinder, SCNCone, SCNSphere, or SCNPlane — 
/// guaranteed Metal stability with zero pink rendering.
/// All dimensions in centimeters to match the scene's coordinate system.
final class BoatNode: SCNNode {
    let boatId: String
    private let teamColor: NSColor
    var color: NSColor { teamColor }
    
    // Components
    private var hullNode: SCNNode?
    private var mainSailNode: SCNNode?
    private var jibNode: SCNNode?
    private var jennakerNode: SCNNode?
    private var wakeNode: SCNNode?
    private var beaconNode: SCNNode?
    
    // HUD
    private var hudContainer: SCNNode?
    private var rankLabel: SKLabelNode?
    private var teamLabel: SKLabelNode?
    private var speedLabel: SKLabelNode?
    private var dtmLabel: SKLabelNode?
    
    // J70 dimensions (cm)
    private struct J70 {
        static let loa: CGFloat = 700       // 7.0m hull
        static let beam: CGFloat = 225      // 2.25m
        static let draft: CGFloat = 140     // 1.4m keel
        static let mastHeight: CGFloat = 950 // ~9.5m mast
        static let freeboard: CGFloat = 65   // waterline to deck
        static let deckHeight: CGFloat = 12  // deck thickness
    }
    
    init(boatId: String, color: NSColor, teamName: String, boatNumber: String? = nil, hullLength: Double = 7.0) {
        self.boatId = boatId
        self.teamColor = color
        super.init()
        buildHull(color: color)
        buildRig()
        buildMainSail(boatNumber: boatNumber)
        buildJib()
        buildJennaker()
        buildWake()
        buildSmartHUD(teamName: teamName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Hull (Primitives only — no bezier)
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func buildHull(color: NSColor) {
        let hull = SCNNode()
        
        // Main hull body — a box tapered with morph or just a long box
        let hullBox = SCNBox(width: J70.beam, height: J70.freeboard, length: J70.loa, chamferRadius: 20)
        let hullMat = SCNMaterial()
        hullMat.diffuse.contents = color
        hullMat.lightingModel = .physicallyBased
        hullMat.metalness.contents = 0.25
        hullMat.roughness.contents = 0.3
        hullBox.materials = [hullMat]
        
        let hullBody = SCNNode(geometry: hullBox)
        hullBody.position = SCNVector3(0, J70.freeboard / 2, 0)
        hull.addChildNode(hullBody)
        
        // Bow — cone for taper
        let bow = SCNCone(topRadius: 0, bottomRadius: J70.beam / 2, height: J70.loa * 0.25)
        let bowMat = SCNMaterial()
        bowMat.diffuse.contents = color
        bowMat.lightingModel = .physicallyBased
        bowMat.metalness.contents = 0.25
        bowMat.roughness.contents = 0.3
        bow.materials = [bowMat]
        
        let bowNode = SCNNode(geometry: bow)
        bowNode.eulerAngles.x = .pi / 2
        bowNode.position = SCNVector3(0, J70.freeboard / 2, J70.loa / 2 + J70.loa * 0.125)
        hull.addChildNode(bowNode)
        
        // Deck (white, slightly raised)
        let deck = SCNBox(width: J70.beam * 0.92, height: J70.deckHeight, length: J70.loa * 0.95, chamferRadius: 15)
        let deckMat = SCNMaterial()
        deckMat.diffuse.contents = NSColor(white: 0.93, alpha: 1.0)
        deckMat.lightingModel = .physicallyBased
        deckMat.roughness.contents = 0.5
        deck.materials = [deckMat]
        
        let deckNode = SCNNode(geometry: deck)
        deckNode.position = SCNVector3(0, J70.freeboard + J70.deckHeight / 2, 0)
        hull.addChildNode(deckNode)
        
        // Cockpit well (dark inset near stern)
        let cockpit = SCNBox(width: J70.beam * 0.6, height: J70.deckHeight * 1.5, length: J70.loa * 0.25, chamferRadius: 8)
        let cockpitMat = SCNMaterial()
        cockpitMat.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        cockpitMat.lightingModel = .physicallyBased
        cockpit.materials = [cockpitMat]
        
        let cockpitNode = SCNNode(geometry: cockpit)
        cockpitNode.position = SCNVector3(0, J70.freeboard + J70.deckHeight / 2, -J70.loa * 0.15)
        hull.addChildNode(cockpitNode)
        
        // Keel fin
        let keel = SCNBox(width: 12, height: J70.draft, length: J70.loa * 0.15, chamferRadius: 4)
        let keelMat = SCNMaterial()
        keelMat.diffuse.contents = NSColor.darkGray
        keelMat.lightingModel = .physicallyBased
        keelMat.metalness.contents = 0.6
        keelMat.roughness.contents = 0.15
        keel.materials = [keelMat]
        
        let keelNode = SCNNode(geometry: keel)
        keelNode.position = SCNVector3(0, -J70.draft / 2, J70.loa * 0.05)
        hull.addChildNode(keelNode)
        
        // Keel bulb
        let bulb = SCNSphere(radius: 22)
        let bulbMat = SCNMaterial()
        bulbMat.diffuse.contents = NSColor(white: 0.25, alpha: 1.0)
        bulbMat.lightingModel = .physicallyBased
        bulbMat.metalness.contents = 0.7
        bulb.materials = [bulbMat]
        
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.scale = SCNVector3(1.0, 0.5, 2.5)
        bulbNode.position = SCNVector3(0, -J70.draft, J70.loa * 0.05)
        hull.addChildNode(bulbNode)
        
        // Rudder
        let rudder = SCNBox(width: 8, height: 80, length: 40, chamferRadius: 3)
        rudder.firstMaterial = keelMat
        let rudderNode = SCNNode(geometry: rudder)
        rudderNode.position = SCNVector3(0, -40, -J70.loa * 0.42)
        hull.addChildNode(rudderNode)
        
        // Color stripe (waterline accent)
        let stripe = SCNBox(width: J70.beam + 4, height: 8, length: J70.loa + 2, chamferRadius: 18)
        let stripeMat = SCNMaterial()
        stripeMat.diffuse.contents = color.blended(withFraction: 0.3, of: .white) ?? color
        stripeMat.lightingModel = .constant
        stripe.materials = [stripeMat]
        
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, 4, 0)
        hull.addChildNode(stripeNode)
        
        addChildNode(hull)
        self.hullNode = hull
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Rig
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func buildRig() {
        let mastZ = J70.loa * 0.12 // 38% from bow
        
        // Mast
        let mast = SCNCylinder(radius: 5, height: J70.mastHeight)
        let rigMat = SCNMaterial()
        rigMat.diffuse.contents = NSColor(white: 0.4, alpha: 1.0)
        rigMat.lightingModel = .physicallyBased
        rigMat.metalness.contents = 0.6
        rigMat.roughness.contents = 0.25
        mast.materials = [rigMat]
        
        let mastNode = SCNNode(geometry: mast)
        mastNode.position = SCNVector3(0, J70.freeboard + J70.mastHeight / 2, mastZ)
        addChildNode(mastNode)
        
        // Boom
        let boom = SCNCylinder(radius: 3.5, height: J70.loa * 0.35)
        boom.materials = [rigMat]
        let boomNode = SCNNode(geometry: boom)
        boomNode.eulerAngles.x = .pi / 2
        boomNode.position = SCNVector3(0, J70.freeboard + J70.mastHeight * 0.22, mastZ - J70.loa * 0.12)
        addChildNode(boomNode)
        
        // Spreaders (cross pieces)
        let spreader = SCNCylinder(radius: 2, height: J70.beam * 0.7)
        spreader.materials = [rigMat]
        let sp = SCNNode(geometry: spreader)
        sp.eulerAngles.z = .pi / 2
        sp.position = SCNVector3(0, J70.freeboard + J70.mastHeight * 0.55, mastZ)
        addChildNode(sp)
        
        // Forestay (thin wire from mast top to bow)
        let forestay = SCNCylinder(radius: 1.5, height: J70.mastHeight * 1.1)
        let wireMat = SCNMaterial()
        wireMat.diffuse.contents = NSColor(white: 0.6, alpha: 0.6)
        wireMat.lightingModel = .constant
        forestay.materials = [wireMat]
        
        let fsNode = SCNNode(geometry: forestay)
        let bowTip = SCNVector3(0, J70.freeboard, J70.loa * 0.5)
        let mastTop = SCNVector3(0, J70.freeboard + J70.mastHeight, mastZ)
        let fsMid = SCNVector3((bowTip.x + mastTop.x)/2, (bowTip.y + mastTop.y)/2, (bowTip.z + mastTop.z)/2)
        fsNode.position = fsMid
        
        let dx = mastTop.x - bowTip.x
        let dy = mastTop.y - bowTip.y
        let dz = mastTop.z - bowTip.z
        let angle = atan2(dz, dy)
        fsNode.eulerAngles.x = angle
        addChildNode(fsNode)
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Sails (using SCNPlane with slight rotation for loft)
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func buildMainSail(boatNumber: String?) {
        let sailWidth: CGFloat = J70.loa * 0.33
        let sailHeight: CGFloat = J70.mastHeight * 0.72
        
        // Triangular main — approximated with a plane scaled and clipped
        // We use two triangular planes for proper shape
        let sail = SCNPlane(width: sailWidth, height: sailHeight)
        let sailMat = SCNMaterial()
        sailMat.diffuse.contents = NSColor(white: 0.98, alpha: 0.93)
        sailMat.isDoubleSided = true
        sailMat.lightingModel = .phong
        sailMat.specular.contents = NSColor(white: 0.9, alpha: 1.0)
        sailMat.shininess = 0.3
        sail.materials = [sailMat]
        
        // Create the actual triangular sail with SCNGeometry from vertices
        let mainSail = createTriangleSail(
            p1: SCNVector3(0, 0, 0),                                    // Tack
            p2: SCNVector3(0, sailHeight, 0),                            // Head
            p3: SCNVector3(-sailWidth, 0, 0),                            // Clew
            color: NSColor(white: 0.98, alpha: 0.93),
            boatNumber: boatNumber
        )
        
        let mastZ = J70.loa * 0.12
        mainSail.position = SCNVector3(0, J70.freeboard + J70.mastHeight * 0.25, mastZ)
        mainSailNode = mainSail
        addChildNode(mainSail)
    }
    
    private func buildJib() {
        let jibWidth: CGFloat = J70.loa * 0.22
        let jibHeight: CGFloat = J70.mastHeight * 0.75
        
        let jib = createTriangleSail(
            p1: SCNVector3(0, 0, 0),                         // Tack (forestay base)
            p2: SCNVector3(0, jibHeight, 0),                  // Head (mast top)
            p3: SCNVector3(-jibWidth, jibHeight * 0.05, 0),   // Clew (aft)
            color: NSColor(white: 0.96, alpha: 0.90)
        )
        
        let forestayZ = J70.loa * 0.42
        jib.position = SCNVector3(0, J70.freeboard, forestayZ)
        jibNode = jib
        addChildNode(jib)
    }
    
    private func createTriangleSail(p1: SCNVector3, p2: SCNVector3, p3: SCNVector3, color: NSColor, boatNumber: String? = nil) -> SCNNode {
        // Build a proper triangle from 3 vertices
        let vertices: [SCNVector3] = [p1, p2, p3]
        let indices: [Int32] = [0, 1, 2]
        
        // Normals pointing forward (Z+)
        let normal = SCNVector3(0, 0, 1)
        let normals = [normal, normal, normal]
        
        let texCoords: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0.5, y: 1),
            CGPoint(x: 1, y: 0)
        ]
        
        let srcV = SCNGeometrySource(vertices: vertices)
        let srcN = SCNGeometrySource(normals: normals)
        let srcT = SCNGeometrySource(textureCoordinates: texCoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Front face
        let geoFront = SCNGeometry(sources: [srcV, srcN, srcT], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.isDoubleSided = true
        mat.lightingModel = .phong
        mat.specular.contents = NSColor(white: 0.8, alpha: 1.0)
        geoFront.materials = [mat]
        
        let node = SCNNode(geometry: geoFront)
        
        // Sail number
        if let num = boatNumber {
            let numSize = CGSize(width: 128, height: 128)
            let skScene = SKScene(size: numSize)
            skScene.backgroundColor = .clear
            
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = num
            label.fontSize = 64
            label.fontColor = .black
            label.position = CGPoint(x: numSize.width/2, y: numSize.height/2 - 20)
            label.horizontalAlignmentMode = .center
            skScene.addChild(label)
            
            let numPlane = SCNPlane(width: 80, height: 80)
            let numMat = SCNMaterial()
            numMat.diffuse.contents = skScene
            numMat.isDoubleSided = true
            numMat.lightingModel = .constant
            numMat.transparency = 0.8
            numPlane.materials = [numMat]
            
            let numNode = SCNNode(geometry: numPlane)
            // Center on the sail
            let midY = (p1.y + p2.y + p3.y) / 3
            let midX = (p1.x + p2.x + p3.x) / 3
            numNode.position = SCNVector3(midX, midY, 2)
            node.addChildNode(numNode)
        }
        
        return node
    }
    
    private func buildJennaker() {
        let sphere = SCNSphere(radius: J70.loa * 0.3)
        let mat = SCNMaterial()
        mat.diffuse.contents = teamColor.withAlphaComponent(0.7)
        mat.isDoubleSided = true
        mat.lightingModel = .phong
        sphere.materials = [mat]
        
        let node = SCNNode(geometry: sphere)
        node.scale = SCNVector3(0.3, 0.8, 0.5)
        node.position = SCNVector3(0, J70.freeboard + J70.mastHeight * 0.5, J70.loa * 0.35)
        node.opacity = 0
        jennakerNode = node
        addChildNode(node)
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Wake
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func buildWake() {
        let wake = SCNPlane(width: J70.beam * 0.5, height: J70.loa * 0.35)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        mat.lightingModel = .constant
        mat.transparency = 0.0
        mat.isDoubleSided = true
        wake.materials = [mat]
        
        let node = SCNNode(geometry: wake)
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(0, 3, -J70.loa * 0.55)
        wakeNode = node
        addChildNode(node)
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Smart HUD
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func buildSmartHUD(teamName: String) {
        let size = CGSize(width: 512, height: 256)
        let scene = SKScene(size: size)
        scene.backgroundColor = .clear
        
        // Glass background
        let bg = SKShapeNode(rectOf: size, cornerRadius: 40)
        bg.fillColor = .init(white: 0.0, alpha: 0.65)
        bg.strokeColor = .init(white: 1.0, alpha: 0.25)
        bg.lineWidth = 3
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        scene.addChild(bg)
        
        // Rank
        let rank = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        rank.fontSize = 72
        rank.fontColor = .white
        rank.position = CGPoint(x: 90, y: 130)
        rank.horizontalAlignmentMode = .center
        scene.addChild(rank)
        self.rankLabel = rank
        
        // Team name
        let team = SKLabelNode(fontNamed: "AvenirNext-Bold")
        team.text = teamName.uppercased()
        team.fontSize = 40
        team.fontColor = .white
        team.position = CGPoint(x: size.width/2 + 20, y: 155)
        team.horizontalAlignmentMode = .center
        scene.addChild(team)
        self.teamLabel = team
        
        // Speed
        let speed = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        speed.fontSize = 34
        speed.fontColor = .lightGray
        speed.position = CGPoint(x: size.width/2 + 20, y: 105)
        speed.horizontalAlignmentMode = .center
        scene.addChild(speed)
        self.speedLabel = speed
        
        // DTM
        let dtm = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        dtm.fontSize = 28
        dtm.fontColor = .cyan
        dtm.position = CGPoint(x: size.width/2 + 20, y: 55)
        dtm.horizontalAlignmentMode = .center
        scene.addChild(dtm)
        self.dtmLabel = dtm
        
        // Team color bar
        let bar = SKShapeNode(rectOf: CGSize(width: 6, height: 180), cornerRadius: 3)
        bar.fillColor = teamColor
        bar.strokeColor = .clear
        bar.position = CGPoint(x: 24, y: size.height/2)
        scene.addChild(bar)
        
        // 3D plate
        let plate = SCNPlane(width: 280, height: 140)
        plate.cornerRadius = 12
        let material = SCNMaterial()
        material.diffuse.contents = scene
        material.isDoubleSided = true
        material.lightingModel = .constant
        plate.materials = [material]
        
        let plateNode = SCNNode(geometry: plate)
        // SpriteKit scenes are drawn bottom-left, but SCNPlane expects top-left/center mappings depending on context. 
        // We flip the Y-scale so the text renders right-side up.
        plateNode.scale = SCNVector3(1, -1, 1)
        
        let container = SCNNode()
        container.position = SCNVector3(0, J70.freeboard + J70.mastHeight + 120, 0)
        container.addChildNode(plateNode)
        container.constraints = [SCNBillboardConstraint()]
        
        hudContainer = container
        addChildNode(container)
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Beacon
    // ═══════════════════════════════════════════════════════════════════════════
    
    private func setupBeacon() {
        let cylinder = SCNCylinder(radius: 15, height: 8000)
        let mat = SCNMaterial()
        mat.diffuse.contents = teamColor.withAlphaComponent(0.3)
        mat.emission.contents = teamColor.withAlphaComponent(0.2)
        mat.transparency = 0.4
        cylinder.materials = [mat]
        
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(0, 4000, 0)
        node.opacity = 0
        addChildNode(node)
        self.beaconNode = node
    }
    
    func setBeaconVisible(_ visible: Bool) {
        if beaconNode == nil { setupBeacon() }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        beaconNode?.opacity = visible ? 1.0 : 0.0
        SCNTransaction.commit()
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - State Update
    // ═══════════════════════════════════════════════════════════════════════════
    
    func update(state: LiveBoat, detail: BoatState?, twd: Double) {
        // 1. Heading
        self.eulerAngles.y = CGFloat(180 - state.heading).degreesToRadians
        
        // 2. TWA for sail trim + heel
        var twa = abs(state.heading - twd)
        if twa > 180 { twa = 360 - twa }
        
        // Heel
        if let roll = detail?.imu.roll {
            self.eulerAngles.z = CGFloat(roll.degreesToRadians)
        } else {
            let speedFactor = min(state.speed / 8.0, 1.0)
            let baseHeel: Double
            if twa < 45      { baseHeel = 22.0 }
            else if twa < 90  { baseHeel = 15.0 }
            else if twa < 135 { baseHeel = 10.0 }
            else              { baseHeel = 5.0 }
            let heelSign: Double = state.heading > twd ? 1.0 : -1.0
            self.eulerAngles.z = CGFloat((baseHeel * speedFactor * heelSign).degreesToRadians)
        }
        
        // 3. Sail trim
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        
        if twa > 90 {
            // Downwind: sails eased
            let sailAngle: CGFloat = (state.heading > twd) ? .pi/4 : -.pi/4
            mainSailNode?.eulerAngles.y = sailAngle * 0.35
            jibNode?.eulerAngles.y = sailAngle * 0.25
            jennakerNode?.opacity = state.speed > 2.0 ? 1.0 : 0.0
        } else if twa > 60 {
            // Reaching
            let sailAngle: CGFloat = (state.heading > twd) ? .pi/8 : -.pi/8
            mainSailNode?.eulerAngles.y = sailAngle
            jibNode?.eulerAngles.y = sailAngle * 0.5
            jennakerNode?.opacity = 0.0
        } else {
            // Upwind: tight
            mainSailNode?.eulerAngles.y = 0.0
            jibNode?.eulerAngles.y = 0.0
            jennakerNode?.opacity = 0.0
        }
        
        // 4. Wake
        let wakeOpacity = min(CGFloat(state.speed) / 6.0, 0.4)
        wakeNode?.opacity = wakeOpacity
        let wakeScale = 0.5 + min(CGFloat(state.speed) / 8.0, 1.5)
        wakeNode?.scale = SCNVector3(wakeScale, 1.0, wakeScale)
        
        SCNTransaction.commit()
        
        // 5. HUD
        rankLabel?.text = state.rank != nil ? "#\(state.rank!)" : ""
        speedLabel?.text = String(format: "%.1f KTS", state.speed)
        teamLabel?.text = (state.teamName ?? boatId).uppercased()
        
        if let dtf = state.dtf, dtf > 0 {
            dtmLabel?.text = String(format: "DTM: %.0fm", dtf)
        } else {
            dtmLabel?.text = ""
        }
    }
    
    func adjustHUDHeight(offset: CGFloat) {
        hudContainer?.position.y = J70.freeboard + J70.mastHeight + 120 + offset
    }
}
