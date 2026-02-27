import SwiftUI

// Local mocks until connected to Rust structures
struct ProcedureNode: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var title: String
    var duration: TimeInterval?
    var isTrigger: Bool = false
}

struct ProcedureArchitectView: View {
    @State private var nodes: [ProcedureNode] = [
        ProcedureNode(position: CGPoint(x: 100, y: 100), title: "Standby Start", isTrigger: true),
        ProcedureNode(position: CGPoint(x: 350, y: 100), title: "5 Min Warning", duration: 300),
        ProcedureNode(position: CGPoint(x: 600, y: 100), title: "4 Min Prep", duration: 240)
    ]
    
    @State private var canvasOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var draggedNodeId: UUID?

    var body: some View {
        HStack(spacing: 0) {
            // Left Toolbar
            VStack(alignment: .leading, spacing: 20) {
                Text("Library")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                LibraryDraggableItem(icon: "clock.fill", title: "Timer Node")
                LibraryDraggableItem(icon: "flag.fill", title: "Flag Node")
                LibraryDraggableItem(icon: "speaker.wave.3.fill", title: "Sound Trigger")
                LibraryDraggableItem(icon: "link", title: "Sequence Link")
                
                Spacer()
            }
            .padding()
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Infinite Graph Canvas
            GeometryReader { geo in
                ZStack {
                    // Grid Background
                    GridBackgroundView()
                        .offset(x: canvasOffset.width + dragOffset.width,
                                y: canvasOffset.height + dragOffset.height)
                    
                    // Bezier Connections (Mock Static Implementation)
                    if nodes.count > 1 {
                        Path { path in
                            for i in 0..<(nodes.count - 1) {
                                let start = CGPoint(
                                    x: nodes[i].position.x + canvasOffset.width + 120, // Right edge
                                    y: nodes[i].position.y + canvasOffset.height + 40
                                )
                                let end = CGPoint(
                                    x: nodes[i+1].position.x + canvasOffset.width, // Left edge
                                    y: nodes[i+1].position.y + canvasOffset.height + 40
                                )
                                path.move(to: start)
                                path.addCurve(to: end,
                                              control1: CGPoint(x: start.x + 100, y: start.y),
                                              control2: CGPoint(x: end.x - 100, y: end.y))
                            }
                        }
                        .stroke(Color.gray.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    
                    // Render Nodes
                    ForEach(nodes) { node in
                        NodeUICell(node: node)
                            .position(
                                x: node.position.x + canvasOffset.width + (draggedNodeId == nil ? dragOffset.width : 0),
                                y: node.position.y + canvasOffset.height + (draggedNodeId == nil ? dragOffset.height : 0)
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if draggedNodeId == nil { draggedNodeId = node.id }
                                        if let index = nodes.firstIndex(where: { $0.id == draggedNodeId }) {
                                            nodes[index].position.x += value.translation.width
                                            nodes[index].position.y += value.translation.height
                                        }
                                    }
                                    .onEnded { _ in
                                        draggedNodeId = nil
                                    }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Canvas Panning Gesture
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if draggedNodeId == nil {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if draggedNodeId == nil {
                                canvasOffset.width += value.translation.width
                                canvasOffset.height += value.translation.height
                                dragOffset = .zero
                            }
                        }
                )
                .clipped()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .navigationTitle("Procedure Architect")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: saveGraph) {
                    Label("Save Procedure", systemImage: "arrow.up.doc.fill")
                }
            }
        }
    }
    
    // --- Logic ---
    private func saveGraph() {
        print("Saving Procedure Graph to Backend...")
    }
}

// Helper: Node UI Block
struct NodeUICell: View {
    let node: ProcedureNode
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(node.isTrigger ? .green : .blue)
                    .frame(width: 10, height: 10)
                Text(node.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            
            if let duration = node.duration {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("\(Int(duration))s")
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(node.isTrigger ? Color.green : Color.blue.opacity(0.5), lineWidth: 2)
        )
    }
}

// Helper: Grid Canvas Background
struct GridBackgroundView: View {
    let gridSize: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Extremely massive bounds to simulate infinite pan
                let cols = Int(4000 / gridSize)
                let rows = Int(4000 / gridSize)
                
                for i in -cols...cols {
                    let x = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: x, y: -4000))
                    path.addLine(to: CGPoint(x: x, y: 4000))
                }
                for i in -rows...rows {
                    let y = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: -4000, y: y))
                    path.addLine(to: CGPoint(x: 4000, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        }
    }
}

// Helper: Library Tool Row
struct LibraryDraggableItem: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            Text(title)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        // Drag interaction would go here
    }
}
