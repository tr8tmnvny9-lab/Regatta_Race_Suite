import SwiftUI
import MapKit

enum CourseTool: String, CaseIterable, Identifiable {
    case cursor = "Select"
    case dropMark = "Add Mark"
    case dropGate = "Add Gate"
    case drawLine = "Draw Line"
    case measure = "Measure"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .cursor: return "cursorarrow"
        case .dropMark: return "mappin.circle.fill"
        case .dropGate: return "arrow.left.and.right.circle.fill"
        case .drawLine: return "line.diagonal"
        case .measure: return "ruler"
        }
    }
}

// Temporary Data Models to mock engine geometry
struct CourseNode: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var name: String
    var type: NodeType
    
    enum NodeType {
        case mark, gate, startLinePin
    }
}

struct CourseBuilderView: View {
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    
    @State private var activeTool: CourseTool = .cursor
    @State private var nodes: [CourseNode] = []
    @State private var selectedNodeId: UUID?

    var body: some View {
        ZStack {
            // Main Interactive Map
            MapReader { reader in
                Map(position: $position, selection: $selectedNodeId) {
                    ForEach(nodes) { node in
                        Annotation(node.name, coordinate: node.coordinate) {
                            NodeAnnotationView(node: node, isSelected: selectedNodeId == node.id)
                        }
                        .tag(node.id)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { screenCoord in
                    handleMapTap(at: screenCoord, mapReader: reader)
                }
            }
            
            // UI Overlay
            VStack {
                HStack(alignment: .top) {
                    // Tool Palette
                    VStack(spacing: 8) {
                        ForEach(CourseTool.allCases) { tool in
                            Button(action: { activeTool = tool }) {
                                Image(systemName: tool.iconName)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(activeTool == tool ? Color.blue : Color(NSColor.controlBackgroundColor))
                                    .foregroundStyle(activeTool == tool ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .help(tool.rawValue)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Context Inspector (Visible if a node is selected)
                    if selectedNodeId != nil {
                        InspectorPanel()
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .navigationTitle("Course Builder")
    }
    
    // --- Logic Stub ---
    private func handleMapTap(at screenCoord: CGPoint, mapReader: MapProxy) {
        guard let location = mapReader.convert(screenCoord, from: .local) else { return }
        
        switch activeTool {
        case .dropMark:
            let newNode = CourseNode(coordinate: location, name: "Mark \(nodes.count + 1)", type: .mark)
            nodes.append(newNode)
            selectedNodeId = newNode.id
            activeTool = .cursor
        case .dropGate:
            let newNode = CourseNode(coordinate: location, name: "Gate \(nodes.count + 1)", type: .gate)
            nodes.append(newNode)
            selectedNodeId = newNode.id
            activeTool = .cursor
        case .cursor, .drawLine, .measure:
            // Handled differently or deselects
            selectedNodeId = nil
        }
    }
}

// Helper annotation renderer
struct NodeAnnotationView: View {
    let node: CourseNode
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.orange)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: isSelected ? 4 : 2)
            
            if isSelected {
                Circle()
                    .stroke(Color.blue.opacity(0.5), lineWidth: 4)
                    .frame(width: 30, height: 30)
            }
        }
    }
}

// Helper Inspector
struct InspectorPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROPERTIES")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            TextField("Mark Name", text: .constant("Mark 1"))
                .textFieldStyle(.roundedBorder)
            
            Picker("Rounding", selection: .constant("Port")) {
                Text("Port").tag("Port")
                Text("Starboard").tag("Starboard")
            }
            .pickerStyle(.menu)
            
            Button("Delete Node") {
                // TODO: Delete
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}
