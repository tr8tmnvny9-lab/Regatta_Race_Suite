import SceneKit
import AppKit

class LineNode: SCNNode {
    private var color: NSColor
    private var lineWidth: CGFloat
    private var cylinderNode: SCNNode?
    
    init(color: NSColor = .white, width: CGFloat = 2.0) {
        self.color = color
        self.lineWidth = width
        super.init()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func update(from p1: SCNVector3, to p2: SCNVector3) {
        let distance = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2) + pow(p2.z - p1.z, 2))
        guard distance > 1 else { return }
        
        cylinderNode?.removeFromParentNode()
        
        let box = SCNBox(width: lineWidth, height: lineWidth, length: CGFloat(distance), chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = color
        box.firstMaterial?.lightingModel = .constant
        box.firstMaterial?.emission.contents = color.withAlphaComponent(0.8)
        
        let cNode = SCNNode(geometry: box)
        cNode.position = SCNVector3(
            (p1.x + p2.x) / 2,
            max(0.5, (p1.y + p2.y) / 2),
            (p1.z + p2.z) / 2
        )
        cNode.look(at: p2, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        
        self.addChildNode(cNode)
        self.cylinderNode = cNode
    }
    
    func setColor(_ newColor: NSColor) {
        self.color = newColor
    }
    
    func setWidth(_ newWidth: CGFloat) {
        self.lineWidth = newWidth
    }
}
