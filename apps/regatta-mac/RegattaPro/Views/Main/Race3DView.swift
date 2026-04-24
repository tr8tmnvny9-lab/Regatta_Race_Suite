import SwiftUI
import SceneKit

/// A high-performance 3D visualization of the race course.
struct Race3DView: NSViewRepresentable {
    @ObservedObject var model: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    func makeCoordinator() -> Race3DCoordinator {
        return Race3DCoordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scnView = InteractionSCNView()
        scnView.scene = context.coordinator.scene
        scnView.delegate = context.coordinator
        scnView.coordinator = context.coordinator
        scnView.allowsCameraControl = false
        scnView.backgroundColor = NSColor(red: 0.12, green: 0.16, blue: 0.40, alpha: 1.0) // Match sky horizon
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.isPlaying = true
        scnView.loops = true
        scnView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(scnView)
        
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: container.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        context.coordinator.setup(with: model, settings: mapInteraction, scnView: scnView)
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Safe dispatch
        DispatchQueue.main.async {
            context.coordinator.updateSettings(mapInteraction)
        }
    }
    
    // Custom SCNView subclass to catch scroll events
    class InteractionSCNView: SCNView {
        weak var coordinator: Race3DCoordinator?
        
        override func scrollWheel(with event: NSEvent) {
            coordinator?.handleScrollWheel(with: event, in: self)
            super.scrollWheel(with: event)
        }
        
        override var acceptsFirstResponder: Bool { true }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Race3DCoordinator) {
        // Find the SCNView in subviews (it was added in makeNSView)
        guard let scnView = nsView.subviews.compactMap({ $0 as? SCNView }).first else { 
            coordinator.teardown()
            return 
        }
        
        // 1. Stop rendering logic immediately
        scnView.isPlaying = false
        scnView.stop(nil)
        
        // 2. Sever all connections BEFORE clearing data
        scnView.delegate = nil
        if let interactionView = scnView as? InteractionSCNView {
            interactionView.coordinator = nil
        }
        
        // 3. Force coordinator to remove all nodes from root with its internal lock
        coordinator.teardown()
        
        // 4. Clear MSAA resolve textures
        scnView.antialiasingMode = .none
        
        // 5. Clear the scene within a transaction and flush to Metal
        SCNTransaction.begin()
        scnView.scene = nil
        scnView.pointOfView = nil
        SCNTransaction.commit()
    }
}

// HUD Removed

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// ─── Preview for Development ───

struct Race3DView_Previews: PreviewProvider {
    static var previews: some View {
        Race3DView(model: RaceStateModel())
            .frame(width: 800, height: 600)
    }
}
