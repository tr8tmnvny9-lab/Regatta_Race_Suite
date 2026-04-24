import SwiftUI
import MapKit
import Foundation
import CoreLocation



struct CourseBuilderView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    @State private var showDrawer: Bool = true
    
    var body: some View {
        HStack(spacing: 0) {
            if showDrawer {
                HStack(spacing: 0) {
                    // Main Column: Object Palette, Templates, & Inspector
                    VStack(alignment: .leading, spacing: 20) {
                        Text("COURSE OBJECTS")
                            .font(RegattaDesign.Fonts.label)
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        
                        ScrollView {
                            VStack(spacing: 12) {
                                BoundaryControlCard()
                                
                                WindControlCard()
                                    .padding(.top, 8)
                                    
                                ObjectPaletteCard()
                                    .padding(.top, 8)
                                    
                                SavedTemplatesCard()
                                    .padding(.top, 8)
                                
                                ForEach(raceState.course.marks) { buoy in
                                    MarkListCard(buoy: buoy, isSelected: mapInteraction.selectedBuoyIds.contains(buoy.id) || mapInteraction.selectedBuoyId == buoy.id) {
                                        selectMark(buoy.id)
                                    }
                                }
                            }
                        }
                        
                        // Show Inspector(s)
                        VStack(spacing: 0) {
                            if !mapInteraction.selectedBuoyIds.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: { 
                                        mapInteraction.selectedBuoyIds = []
                                        mapInteraction.selectedBuoyId = nil
                                    }) {
                                        Text("DESELECT ALL")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                                .padding(.top, 10)
                            }

                            if let selectedId = mapInteraction.selectedBuoyId ?? mapInteraction.selectedBuoyIds.first,
                               let buoy = raceState.course.marks.first(where: { $0.id == selectedId }) {
                                BuoyInspector(buoy: Binding(
                                    get: { buoy },
                                    set: { updated in
                                        if let idx = raceState.course.marks.firstIndex(where: { $0.id == selectedId }) {
                                            raceState.course.marks[idx] = updated
                                            raceEngine.updateBuoyConfig(buoy: updated)
                                        }
                                    }
                                ), onDelete: {
                                    deleteBuoy(id: selectedId)
                                })
                            }
                            
                            if mapInteraction.selectedBuoyIds.count > 1 {
                                GroupInspector(selectedIds: mapInteraction.selectedBuoyIds)
                                    .padding(.top, 10)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .frame(width: 320)
                }
                .glassPanel()
                .transition(.move(edge: .leading))
                .allowsHitTesting(true)
            }
            
            // Toggle Button
            VStack {
                Spacer()
                Button(action: { withAnimation { showDrawer.toggle() } }) {
                    Image(systemName: showDrawer ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.ultraThinMaterial)
                        .background(Circle().fill(RegattaDesign.Colors.electricBlue))
                }
                .buttonStyle(.plain)
                .padding(20)
                Spacer()
            }
            .allowsHitTesting(true)
            
            Spacer()
        }
    }
    
    private func selectMark(_ id: String) {
        let buoy = raceState.course.marks.first(where: { $0.id == id })
        
        var idsToSelect = Set<String>([id])
        
        // Find sibling if it's a paired mark
        if let b = buoy {
            let isSibling: (Buoy) -> Bool = { other in
                if other.id == b.id { return false }
                if other.type != b.type { return false }
                
                // Unified prefix cleaning for Gates, Start, and Finish marks
                let suffixes = [" P", " S", " Pin", " Boat", " (Port)", " (Starboard)"]
                var cleanA = b.name
                var cleanB = other.name
                for s in suffixes {
                    if cleanA.hasSuffix(s) { cleanA = String(cleanA.dropLast(s.count)) }
                    if cleanB.hasSuffix(s) { cleanB = String(cleanB.dropLast(s.count)) }
                }
                return cleanA == cleanB
            }
            
            if let sibling = raceState.course.marks.first(where: isSibling) {
                idsToSelect.insert(sibling.id)
            }
        }
        
        // Handle selection mechanics
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            // Toggle logic for multi-select
            if mapInteraction.selectedBuoyIds.isSuperset(of: idsToSelect) {
                mapInteraction.selectedBuoyIds.subtract(idsToSelect)
            } else {
                mapInteraction.selectedBuoyIds.formUnion(idsToSelect)
            }
        } else {
            // Isolate selection
            mapInteraction.selectedBuoyIds = idsToSelect
            mapInteraction.selectedBuoyId = id // Primary focus
            
            if let b = buoy {
                DispatchQueue.main.async {
                    mapInteraction.explicitMapRegion = MKCoordinateRegion(
                        center: b.pos.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
    
    private func deleteBuoy(id: String) {
        raceState.course.marks.removeAll(where: { $0.id == id })
        if mapInteraction.selectedBuoyId == id { mapInteraction.selectedBuoyId = nil }
        mapInteraction.selectedBuoyIds.remove(id)
        
        // Sync deletions to backend
        raceEngine.overrideMarks(marks: raceState.course.marks)
    }
}

struct WindControlCard: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wind")
                Text("WIND ENVIRONMENT")
                Spacer()
                Text("\(Int(raceState.twd))°").font(.system(.body, design: .monospaced, weight: .bold)).foregroundStyle(RegattaDesign.Colors.cyan)
            }
            .font(RegattaDesign.Fonts.label)
            .foregroundStyle(.white)
            
            Slider(
                value: $raceState.twd,
                in: 0.0...359.0,
                step: 1.0,
                onEditingChanged: { editing in
                    if !editing {
                        raceEngine.setWind(speed: raceState.tws, direction: raceState.twd)
                    }
                }
            )
            .tint(RegattaDesign.Colors.cyan)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ObjectPaletteCard: View {
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "plus.square.dashed").foregroundStyle(.cyan)
                Text("ADD OBJECTS").font(RegattaDesign.Fonts.label)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PaletteButton(title: "Single Mark", iconSystemName: "triangle.fill", tool: .dropMark)
                PaletteButton(title: "Gate", iconSystemName: nil, tool: .dropGate)
                PaletteButton(title: "Start Line", iconSystemName: nil, tool: .dropStart)
                PaletteButton(title: "Finish Line", iconSystemName: "flag.checkered", tool: .dropFinish)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PaletteButton: View {
    @EnvironmentObject var mapInteraction: MapInteractionModel
    let title: String
    let iconSystemName: String?
    let tool: CourseTool
    
    var body: some View {
        Button(action: { mapInteraction.activeTool = mapInteraction.activeTool == tool ? .cursor : tool }) {
            VStack(spacing: 8) {
                if tool == .dropGate {
                    CustomIconGate(isActive: mapInteraction.activeTool == tool)
                        .frame(height: 20)
                } else if tool == .dropStart {
                    CustomIconStartLine(isActive: mapInteraction.activeTool == tool)
                        .frame(height: 20)
                } else {
                    Image(systemName: iconSystemName ?? "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(mapInteraction.activeTool == tool ? RegattaDesign.Colors.cyan : .white)
                }
                
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(mapInteraction.activeTool == tool ? RegattaDesign.Colors.cyan : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(mapInteraction.activeTool == tool ? RegattaDesign.Colors.electricBlue.opacity(0.2) : Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(mapInteraction.activeTool == tool ? RegattaDesign.Colors.electricBlue : Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct CustomIconGate: View {
    var isActive: Bool
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(isActive ? RegattaDesign.Colors.cyan : .white).frame(width: 8)
            Circle().fill(isActive ? RegattaDesign.Colors.cyan : .white).frame(width: 8)
        }
    }
}

struct CustomIconStartLine: View {
    var isActive: Bool
    var body: some View {
        HStack(spacing: 4) {
            // Pin End (Flag)
            Image(systemName: "flag.fill")
                .font(.system(size: 10))
            
            // Dashed Line
            Rectangle()
                .fill(Color.clear)
                .frame(width: 15, height: 2)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [2]))
                )
            
            // Boat End (Hull shape)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 8, y: 0))
                path.addLine(to: CGPoint(x: 10, y: 4))
                path.addLine(to: CGPoint(x: 5, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 10))
                path.closeSubpath()
            }
            .fill(isActive ? RegattaDesign.Colors.cyan : .white)
            .frame(width: 10, height: 10)
        }
        .foregroundStyle(isActive ? RegattaDesign.Colors.cyan : .white)
    }
}

struct MarkListCard: View {
    let buoy: Buoy
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill").foregroundStyle(Color(name: buoy.color ?? "Yellow"))
                VStack(alignment: .leading) {
                    Text(buoy.name).font(.system(size: 13, weight: .bold))
                    Text(buoy.type.rawValue).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(12).background(isSelected ? Color.white.opacity(0.1) : Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? RegattaDesign.Colors.electricBlue : .clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct BoundaryControlCard: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "skew").foregroundStyle(.cyan); Text("COURSE BOUNDARY").font(RegattaDesign.Fonts.label); Spacer() }
            Button(action: { mapInteraction.activeTool = .drawBoundary }) {
                Text(mapInteraction.activeTool == .drawBoundary ? "TAP ON MAP" : "DRAW MANUALLY").font(.caption2).bold().frame(maxWidth: .infinity).padding(8)
                    .background(mapInteraction.activeTool == .drawBoundary ? Color.cyan.opacity(0.4) : RegattaDesign.Colors.electricBlue.opacity(0.2)).clipShape(Capsule())
            }.buttonStyle(.plain)
            Button(action: { mapInteraction.activeTool = .drawRestriction }) {
                Text(mapInteraction.activeTool == .drawRestriction ? "DRAWING ZONE..." : "ADD NO-GO ZONE").font(.caption2).bold().frame(maxWidth: .infinity).padding(8)
                    .background(mapInteraction.activeTool == .drawRestriction ? Color.yellow.opacity(0.4) : RegattaDesign.Colors.electricBlue.opacity(0.1)).clipShape(Capsule())
            }.buttonStyle(.plain)
            if mapInteraction.activeTool == .drawRestriction || mapInteraction.activeTool == .drawBoundary {
                Button(action: { mapInteraction.activeRestrictionId = nil; mapInteraction.activeTool = .cursor }) {
                    Text("FINISH DRAWING").font(.caption2).bold().frame(maxWidth: .infinity).padding(8).background(Color.green.opacity(0.3)).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            if raceState.course.courseBoundary != nil || !raceState.course.restrictionZones.isEmpty {
                Button(action: { raceState.course.courseBoundary = nil; raceEngine.setBoundary(points: []) }) {
                    Text("CLEAR BOUNDARY").font(.caption2).bold().foregroundStyle(.red).frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
                Button(action: { raceState.course.restrictionZones = [] }) {
                    Text("CLEAR ALL ZONES").font(.caption2).bold().foregroundStyle(.red).frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }.padding(12).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BuoyInspector: View {
    @Binding var buoy: Buoy
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    var onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Text("PROPERTIES: \(buoy.name.uppercased())").font(RegattaDesign.Fonts.label).foregroundStyle(RegattaDesign.Colors.electricBlue)
            VStack(spacing: 10) {
                CustomTextField(label: "NAME", text: $buoy.name) // Name changes don't sync to avoid breaking pairs
                HStack { Text("COLOR").font(RegattaDesign.Fonts.label); Spacer(); ColorPickerStrip(selection: binding(for: \.color)) }
                HStack {
                    Text("DESIGN").font(RegattaDesign.Fonts.label); Spacer()
                    Picker("", selection: binding(for: \.design)) {
                        Text("Cylinder").tag("Cylindrical" as String?)
                        Text("Sphere").tag("Spherical" as String?)
                        Text("Spar").tag("Spar" as String?)
                        Text("Bot").tag("MarkSetBot" as String?)
                        Text("Committee Boat").tag("CommitteeBoat" as String?)
                    }.labelsHidden()
                }
                HStack {
                    Text("ROUNDING").font(RegattaDesign.Fonts.label); Spacer()
                    Picker("", selection: binding(for: \.rounding)) { Text("Port").tag("Port" as String?); Text("Starboard").tag("Starboard" as String?) }.pickerStyle(.segmented).frame(width: 150)
                }
                Toggle(isOn: binding(for: \.showLaylines)) { Text("LAYLINES").font(RegattaDesign.Fonts.label) }.toggleStyle(SwitchToggleStyle(tint: RegattaDesign.Colors.cyan))
                if buoy.showLaylines {
                    HStack {
                        Text("DIRECTION").font(RegattaDesign.Fonts.label); Spacer()
                        Picker("", selection: binding(for: \.laylineDirection)) { Text("Upwind").tag(0.0); Text("Downwind").tag(180.0) }.pickerStyle(.segmented).frame(width: 150)
                    }
                }
                Button(role: .destructive, action: onDelete) { Label("Delete Mark", systemImage: "trash").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            }
        }
    }
    
    // Proxy binding to intercept changes and apply them to both marks in a pair simultaneously
    private func binding<T>(for keyPath: WritableKeyPath<Buoy, T>) -> Binding<T> {
        Binding(
            get: { buoy[keyPath: keyPath] },
            set: { newValue in
                buoy[keyPath: keyPath] = newValue
                syncPair(changedKeyPath: keyPath, newValue: newValue)
            }
        )
    }
    
    private func syncPair<T>(changedKeyPath: WritableKeyPath<Buoy, T>, newValue: T) {
        let updatedBuoy = buoy
        let isSibling: (Buoy) -> Bool = { other in
            if other.id == updatedBuoy.id { return false }
            if updatedBuoy.type == .start && other.type == .start { return true }
            if updatedBuoy.type == .finish && other.type == .finish { return true }
            if updatedBuoy.type == .gate && other.type == .gate {
                return String(updatedBuoy.name.dropLast(2)) == String(other.name.dropLast(2))
            }
            return false
        }
        
        for i in raceState.course.marks.indices {
            if isSibling(raceState.course.marks[i]) {
                var sibling = raceState.course.marks[i]
                
                // Rely on the generic keypath assignment which covers all types safely
                sibling[keyPath: changedKeyPath] = newValue
                
                raceState.course.marks[i] = sibling
                raceEngine.updateBuoyConfig(buoy: sibling)
            }
        }
        
        // Final nudge to ensure RaceState publishes the change
        let temp = raceState.course
        raceState.course = temp
    }
}

struct CustomTextField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(RegattaDesign.Fonts.label).foregroundStyle(.secondary)
            TextField("", text: $text).textFieldStyle(.plain).padding(8).background(Color.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ColorPickerStrip: View {
    @Binding var selection: String?
    let colors = ["Red", "Green", "Yellow", "Orange", "Blue"]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.self) { color in
                Circle().fill(Color(name: color)).frame(width: 18, height: 18).overlay(Circle().stroke(.white, lineWidth: selection == color ? 2 : 0)).onTapGesture { selection = color }
            }
        }
    }
}

struct GroupInspector: View {
    let selectedIds: Set<String>
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @State private var rotationAngle: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Text("GROUP PROPERTIES (\(selectedIds.count) MARKS)").font(RegattaDesign.Fonts.label).foregroundStyle(RegattaDesign.Colors.cyan)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "rotate.3d")
                    Text("ROTATE GROUP")
                    Spacer()
                    Text("\(Int(rotationAngle))°").font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(.secondary)
                
                Slider(
                    value: $rotationAngle,
                    in: -180...180,
                    step: 1.0,
                    onEditingChanged: { editing in
                        if !editing {
                            applyRotation(degrees: rotationAngle)
                            rotationAngle = 0 // Reset slider after apply
                        }
                    }
                )
                .tint(RegattaDesign.Colors.electricBlue)
                
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete Group", systemImage: "trash").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).padding(.top, 8)
            }
        }
    }
    
    // Rotate marks around their shared centroid via standard 2D Rotation Matrix
    private func applyRotation(degrees: Double) {
        let marks = raceState.course.marks.filter { selectedIds.contains($0.id) }
        guard marks.count > 1 else { return }
        
        let rads = -degrees * .pi / 180.0 // Negative for intuitive MapKit rotation
        let cosTheta = cos(rads)
        let sinTheta = sin(rads)
        
        // Find Centroid
        let avgLat = marks.map { $0.pos.lat }.reduce(0, +) / Double(marks.count)
        let avgLon = marks.map { $0.pos.lon }.reduce(0, +) / Double(marks.count)
        
        // Convert to rough metric coordinates based on Earth radius to fix Lat/Lon distortion
        let latToMeters = 111320.0
        let lonToMeters = 111320.0 * cos(avgLat * .pi / 180.0)
        
        DispatchQueue.main.async {
            for id in selectedIds {
                if let idx = raceState.course.marks.firstIndex(where: { $0.id == id }) {
                    let buoy = raceState.course.marks[idx]
                    
                    let dx = (buoy.pos.lon - avgLon) * lonToMeters
                    let dy = (buoy.pos.lat - avgLat) * latToMeters
                    
                    let rotatedX = dx * cosTheta - dy * sinTheta
                    let rotatedY = dx * sinTheta + dy * cosTheta
                    
                    let newLat = avgLat + (rotatedY / latToMeters)
                    let newLon = avgLon + (rotatedX / lonToMeters)
                    
                    let newPos = LatLon(lat: newLat, lon: newLon)
                    raceState.course.marks[idx].pos = newPos
                    raceEngine.updateBuoyConfig(buoy: raceState.course.marks[idx])
                }
            }
        }
    }
    
    private func deleteSelected() {
        raceState.course.marks.removeAll(where: { selectedIds.contains($0.id) })
        raceEngine.overrideMarks(marks: raceState.course.marks) // Provide a mass sync
    }
}

struct SavedTemplatesCard: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    // Store templates directly in AppStorage as a JSON string for simplicity
    @AppStorage("savedCourseTemplates") private var templatesData: Data = Data()
    
    @State private var templates: [CourseTemplate] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.dashed.on.square.dashed").foregroundStyle(.cyan)
                Text("TEMPLATES").font(RegattaDesign.Fonts.label)
                Spacer()
            }
            
            if !templates.isEmpty {
                ForEach(templates) { template in
                    HStack {
                        Text(template.name).font(.system(size: 11, weight: .bold))
                        Spacer()
                        Button(action: {
                            if mapInteraction.activeTemplate?.id == template.id && mapInteraction.activeTool == .placeTemplate {
                                mapInteraction.activeTool = .cursor
                                mapInteraction.activeTemplate = nil
                            } else {
                                mapInteraction.activeTemplate = template
                                mapInteraction.activeTool = .placeTemplate
                            }
                        }) {
                            Text(mapInteraction.activeTemplate?.id == template.id && mapInteraction.activeTool == .placeTemplate ? "PLACING..." : "PLACE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(mapInteraction.activeTemplate?.id == template.id && mapInteraction.activeTool == .placeTemplate ? Color.green : RegattaDesign.Colors.electricBlue)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                        
                        Button(action: {
                            deleteTemplate(id: template.id)
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("No templates saved.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            
            Button(action: saveCurrentCourse) {
                Label("Save Current As Template", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(raceState.course.marks.isEmpty)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear(perform: loadTemplates)
    }
    
    private func loadTemplates() {
        if let decoded = try? JSONDecoder().decode([CourseTemplate].self, from: templatesData) {
            templates = decoded
        }
    }
    
    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            templatesData = encoded
        }
    }
    
    private func deleteTemplate(id: String) {
        templates.removeAll(where: { $0.id == id })
        saveTemplates()
    }
    
    private func saveCurrentCourse() {
        let marks = raceState.course.marks
        guard !marks.isEmpty else { return }
        
        // Find Centroid
        let avgLat = marks.map { $0.pos.lat }.reduce(0, +) / Double(marks.count)
        let avgLon = marks.map { $0.pos.lon }.reduce(0, +) / Double(marks.count)
        
        let latToMeters = 111320.0
        let lonToMeters = 111320.0 * cos(avgLat * .pi / 180.0)
        
        var templateMarks: [CourseTemplate.TemplateMark] = []
        for buoy in marks {
            let dx = (buoy.pos.lon - avgLon) * lonToMeters
            let dy = (buoy.pos.lat - avgLat) * latToMeters
            
            templateMarks.append(CourseTemplate.TemplateMark(
                type: buoy.type,
                name: buoy.name,
                relativeX: dx,
                relativeY: dy,
                color: buoy.color,
                design: buoy.design,
                rounding: buoy.rounding,
                showLaylines: buoy.showLaylines,
                laylineDirection: buoy.laylineDirection
            ))
        }
        
        var templateBoundary: [CourseTemplate.TemplatePoint] = []
        if let boundary = raceState.course.courseBoundary {
            for pt in boundary {
                let dx = (pt.lon - avgLon) * lonToMeters
                let dy = (pt.lat - avgLat) * latToMeters
                templateBoundary.append(CourseTemplate.TemplatePoint(relativeX: dx, relativeY: dy))
            }
        }
        
        let name = "Course \(templates.count + 1)"
        let newTemplate = CourseTemplate(
            id: UUID().uuidString,
            name: name,
            marks: templateMarks,
            boundary: templateBoundary.isEmpty ? nil : templateBoundary
        )
        
        templates.append(newTemplate)
        saveTemplates()
    }
}
