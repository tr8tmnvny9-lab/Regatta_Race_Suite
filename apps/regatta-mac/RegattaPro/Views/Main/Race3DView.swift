import SwiftUI
import SceneKit

/// A high-performance 3D visualization of the race course.
struct Race3DView: NSViewRepresentable {
    @ObservedObject var model: RaceStateModel
    @StateObject private var coordinator = Race3DCoordinator()
    
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = coordinator.scene
        scnView.delegate = coordinator
        scnView.allowsCameraControl = true // Enable manual override by default
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        
        // Setup coordinating logic
        coordinator.setup(with: model)
        
        return scnView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Handle updates if necessary
    }
}

// ─── Preview for Development ───

struct Race3DView_Previews: PreviewProvider {
    static var previews: some View {
        Race3DView(model: RaceStateModel())
            .frame(width: 800, height: 600)
    }
}
