import SwiftUI
import MapKit

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case log = "Race Log"
    case startProcedure = "Start Procedure"
    case procedureArchitect = "Procedure Architect"
    case courseBuilder = "Course Builder"
    case fleetControl = "Fleet Control"
    case settings = "Settings"
    case regattaLive = "Regatta Live"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .overview: return "map.fill"
        case .log: return "list.bullet.rectangle.portrait"
        case .startProcedure: return "flag.checkered"
        case .procedureArchitect: return "point.topleft.down.curvedto.point.bottomright.up"
        case .courseBuilder: return "ruler"
        case .fleetControl: return "person.3.sequence.fill"
        case .settings: return "gearshape.fill"
        case .regattaLive: return "video.fill"
        }
    }
}

struct MainLayoutView: View {
    @State private var selectedSection: AppSection = .overview
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        ZStack {
            // ─── Background Layer (Tactical Map is always underlying) ────────
            TacticalMapView()
                .ignoresSafeArea()
            
            // ─── Content Layer (Glass Panels) ────────────────────────────────
            HStack(spacing: 20) {
                // Left Navigation Sidebar
                SidebarView(selectedSection: $selectedSection)
                    .allowsHitTesting(true)
                
                // Main Workspace
                VStack(spacing: 20) {
                    // Title Bar / Sub-Header
                    HeaderView(section: selectedSection)
                        .allowsHitTesting(true)
                    
                    // Active Detail View
                    DetailView(section: selectedSection)
                        .allowsHitTesting(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Right Telemetry Wing
                TelemetryWing()
                    .allowsHitTesting(true)
            }
            .padding(24)
            
            // ─── Overlays ────────────────────────────────────────────────────
            // Procedure Architect is now handled in DetailView
        }
        .background(RegattaDesign.Colors.darkNavy)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSection)
    }
}

// ─── Subviews ───────────────────────────────────────────────────────────────

struct SidebarView: View {
    @Binding var selectedSection: AppSection
    
    var body: some View {
        VStack(spacing: 12) {
            // Brand Logo
            Image(systemName: "sailboat.fill")
                .font(.system(size: 24))
                .foregroundStyle(RegattaDesign.Gradients.primary)
                .padding(.vertical, 20)
            
            ForEach(AppSection.allCases.filter { $0 != .procedureArchitect }) { section in
                NavButton(
                    icon: section.iconName,
                    isActive: selectedSection == section,
                    onClick: { selectedSection = section }
                )
            }
            
            // Architect Trigger (Special)
            NavButton(
                icon: AppSection.procedureArchitect.iconName,
                isActive: selectedSection == .procedureArchitect,
                onClick: { selectedSection = .procedureArchitect },
                color: RegattaDesign.Colors.cyan
            )
            
            Spacer()
        }
        .padding(12)
        .frame(width: 72)
        .glassPanel()
    }
}

struct NavButton: View {
    let icon: String
    let isActive: Bool
    let onClick: () -> Void
    var color: Color = RegattaDesign.Colors.electricBlue
    
    var body: some View {
        Button(action: onClick) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .shadow(color: color.opacity(0.3), radius: 8)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? color : .secondary)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
    }
}

struct HeaderView: View {
    let section: AppSection
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("REGATTA PRO")
                    .font(RegattaDesign.Fonts.label)
                    .tracking(4)
                    .foregroundStyle(RegattaDesign.Colors.electricBlue)
                
                Text(section.rawValue.uppercased())
                    .font(.title2)
                    .fontWeight(.black)
                    .italic()
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

struct DetailView: View {
    let section: AppSection
    
    var body: some View {
        ZStack {
            OverviewDashboard()
                .opacity(section == .overview ? 1 : 0)
                .allowsHitTesting(section == .overview)
            
            LogView()
                .opacity(section == .log ? 1 : 0)
                .allowsHitTesting(section == .log)
            
            StartProcedureView()
                .opacity(section == .startProcedure ? 1 : 0)
                .allowsHitTesting(section == .startProcedure)
            
            CourseBuilderView()
                .opacity(section == .courseBuilder ? 1 : 0)
                .allowsHitTesting(section == .courseBuilder)
            
            FleetControlView()
                .opacity(section == .fleetControl ? 1 : 0)
                .allowsHitTesting(section == .fleetControl)
            
            RegattaLiveView()
                .opacity(section == .regattaLive ? 1 : 0)
                .allowsHitTesting(section == .regattaLive)
                
            ProcedureArchitectView()
                .opacity(section == .procedureArchitect ? 1 : 0)
                .allowsHitTesting(section == .procedureArchitect)
            
            if section == .settings {
                Text("Settings Native Coming Soon")
            }
        }
    }
}

struct TelemetryWing: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Wind Panel
            GlassPanel(title: "Wind Environment", icon: "wind") {
                VStack(spacing: 12) {
                    TelemetryValue(label: "Speed", value: String(format: "%.1f", raceState.tws), unit: "kts", color: .white)
                    TelemetryValue(label: "Direction", value: "\(Int(raceState.twd))", unit: "°", color: RegattaDesign.Colors.cyan)
                }
            }
            
            // Fleet Summary
            GlassPanel(title: "Fleet Status", icon: "sailboat") {
                VStack(spacing: 12) {
                    HStack {
                        Text("ACTIVE")
                            .font(RegattaDesign.Fonts.label)
                        Spacer()
                        Text("\(raceState.boats.count)")
                            .font(.headline)
                            .foregroundStyle(RegattaDesign.Colors.electricBlue)
                    }
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(raceState.boats) { boat in
                                BoatTelemetryCard(boatId: boat.id)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 300)
    }
}

struct BoatTelemetryCard: View {
    @EnvironmentObject var raceState: RaceStateModel
    let boatId: String
    
    private var boat: LiveBoat? {
        raceState.boats.first { $0.id == boatId }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Role Icon
            Image(systemName: roleIcon)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(boatId)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(statusText)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            // Mini Telemetry
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", boat?.speed ?? 0))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text("KTS")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    private var roleIcon: String {
        switch boat?.role {
        case .jury: return "scalemessage.fill"
        case .media: return "camera.fill"
        default: return "sailboat.fill"
        }
    }
    
    private var statusText: String {
        "SAFE" // Logic for OCS/Penalty would go here
    }
    
    private var statusColor: Color {
        .green // Logic for OCS/Penalty would go here
    }
}

struct OverviewDashboard: View {
    var body: some View {
        HStack {
            GlassPanel(title: "Race Overview", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Regatta Pro.")
                    Text("Use the navigation on the left to manage the race.")
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// ─── Design System: Apple Liquid Glass ───────────────────────────────────────

struct RegattaDesign {
    
    // Core Colors
    struct Colors {
        static let electricBlue = Color(red: 0.23, green: 0.51, blue: 0.96) // #3B82F6
        static let cyan = Color(red: 0.02, green: 0.71, blue: 0.83)         // #06B6D4
        static let crimson = Color(red: 0.86, green: 0.11, blue: 0.22)      // #DB1C38
        static let amber = Color(red: 0.96, green: 0.61, blue: 0.07)       // #F59E0B
        static let darkNavy = Color(red: 0.02, green: 0.02, blue: 0.03)    // #050507
        static let panelBackground = Color.black.opacity(0.4)
        static let glassBorder = Color.white.opacity(0.1)
    }
    
    // Typography
    struct Fonts {
        static let heading = Font.system(size: 24, weight: .bold, design: .default)
        static let telemetry = Font.system(.title, design: .monospaced).weight(.black)
        static let label = Font.system(size: 10, weight: .bold, design: .default)
        static let mono = Font.system(size: 12, design: .monospaced)
    }
    
    // Gradients
    struct Gradients {
        static let primary = LinearGradient(
            colors: [Colors.electricBlue, Colors.cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let glass = LinearGradient(
            colors: [.white.opacity(0.05), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// ─── Glass View Modifiers ───────────────────────────────────────────────────

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(RegattaDesign.Colors.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

// ─── Reusable Components ────────────────────────────────────────────────────

struct GlassPanel<Content: View>: View {
    let title: String
    let icon: String?
    let content: () -> Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(RegattaDesign.Colors.electricBlue)
                }
                Text(title.uppercased())
                    .font(RegattaDesign.Fonts.label)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.2))
            
            Divider().opacity(0.1)
            
            // Body
            content()
                .padding(16)
        }
        .glassPanel()
    }
}

struct TelemetryValue: View {
    let label: String
    let value: String
    let unit: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(RegattaDesign.Fonts.telemetry)
                    .italic()
                    .foregroundStyle(color)
                if let unit = unit {
                    Text(unit.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Color {
    init(name: String) {
        switch name.lowercased() {
        case "red": self = .red
        case "green": self = .green
        case "yellow": self = .yellow
        case "orange": self = .orange
        case "blue": self = .blue
        case "cyan": self = RegattaDesign.Colors.cyan
        default: self = .yellow
        }
    }
}



struct CourseTemplatesCard: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(RegattaDesign.Colors.cyan)
                Text("COURSE TEMPLATES")
                    .font(RegattaDesign.Fonts.label)
                Spacer()
            }
            
            HStack(spacing: 10) {
                TemplateButton(title: "W/L", icon: "arrow.up.and.down.square.fill") {
                    generateWindwardLeeward()
                }
                
                TemplateButton(title: "TRAPEZOID", icon: "trapezoid.and.line.vertical.fill") {
                    generateTrapezoid()
                }
                
                TemplateButton(title: "GATES", icon: "arrow.left.and.right.square.fill") {
                    generateOptimalGates()
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct TemplateButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 8, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// ─── Template Generation Logic ───────────────────────────────────────────────

extension CourseTemplatesCard {
    
    private func generateWindwardLeeward() {
        let center: CLLocationCoordinate2D
        if let b = raceState.course.courseBoundary, !b.isEmpty {
            center = CLLocationCoordinate2D(latitude: b[0].lat, longitude: b[0].lon)
        } else {
            center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
        
        let twd = raceState.twd
        let distance: Double = 1000 // 1km course
        
        // Clear existing marks
        raceState.course.marks = []
        
        // Top Mark (Windward)
        let topPos = destination(from: center, distance: distance / 2, bearing: twd)
        raceState.course.marks.append(Buoy(id: "M1", type: .mark, name: "Windward", pos: topPos, color: "Red", design: "Cylindrical"))
        
        // Bottom Mark (Leeward)
        let botPos = destination(from: center, distance: distance / 2, bearing: (twd + 180).truncatingRemainder(dividingBy: 360))
        raceState.course.marks.append(Buoy(id: "M2", type: .mark, name: "Leeward", pos: botPos, color: "Yellow", design: "Cylindrical"))
        
        // Center the map
        DispatchQueue.main.async {
            mapInteraction.explicitMapRegion = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        }
    }
    
    private func generateTrapezoid() {
        // Implementation for trapezoid
        generateWindwardLeeward() // Placeholder
    }
    
    private func generateOptimalGates() {
        // Implementation for gates
        generateWindwardLeeward() // Placeholder
    }
    
    private func destination(from: CLLocationCoordinate2D, distance: Double, bearing: Double) -> LatLon {
        let radius = 6371000.0 // Earth radius in meters
        let angularDist = distance / radius
        let bearRad = bearing * .pi / 180
        let latRad = from.latitude * .pi / 180
        let lonRad = from.longitude * .pi / 180
        
        let destLat = asin(sin(latRad) * cos(angularDist) + cos(latRad) * sin(angularDist) * cos(bearRad))
        let destLon = lonRad + atan2(sin(bearRad) * sin(angularDist) * cos(latRad), cos(angularDist) - sin(latRad) * sin(destLat))
        
        return LatLon(lat: destLat * 180 / .pi, lon: destLon * 180 / .pi)
    }
}

struct PerformanceOverlayView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var boat: LiveBoat? {
        raceState.boats.first { $0.id == mapInteraction.selectedBoatId }
    }
    
    var body: some View {
        if let boat = boat {
            VStack(alignment: .leading, spacing: 16) {
                // Header: Boat Identity
                HStack {
                    Image(systemName: "sailboat.fill")
                        .foregroundStyle(RegattaDesign.Colors.electricBlue)
                    Text(boat.id)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Spacer()
                    Button(action: { mapInteraction.selectedBoatId = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider().opacity(0.1)
                
                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    MetricItem(label: "VMG", value: String(format: "%.1f", calculateVMG(boat: boat)), unit: "KTS", color: RegattaDesign.Colors.cyan)
                    MetricItem(label: "POLAR %", value: String(format: "%.0f", calculatePolarEfficiency(boat: boat)), unit: "%", color: .green)
                    MetricItem(label: "HEADING", value: String(format: "%.0f", boat.heading), unit: "°", color: .white)
                    MetricItem(label: "SPEED", value: String(format: "%.1f", boat.speed), unit: "KTS", color: .white)
                }
                
                // Polar Chart Placeholder
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                    
                    // Simple Polar Needle
                    Rectangle()
                        .fill(RegattaDesign.Colors.electricBlue)
                        .frame(width: 2, height: 40)
                        .offset(y: -20)
                        .rotationEffect(.degrees(boat.heading - raceState.twd))
                }
                .frame(height: 100)
                .padding(.top, 10)
            }
            .padding(20)
            .frame(width: 260)
            .glassPanel()
        }
    }
    
    // ─── Calculations ────────────────────────────────────────────────────────
    
    private func calculateVMG(boat: LiveBoat) -> Double {
        let diff = (boat.heading - raceState.twd) * .pi / 180
        return boat.speed * cos(diff)
    }
    
    private func calculatePolarEfficiency(boat: LiveBoat) -> Double {
        // Mock logic: 10kts is 100% for this example
        let targetSpeed = 10.0
        return min(120, (boat.speed / targetSpeed) * 100)
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 3)
            }
        }
    }
}

struct FleetHealthDashboard: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("FLEET DIAGNOSTICS")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(RegattaDesign.Colors.electricBlue)
                Spacer()
                Text("\(raceState.boats.count) TRACKERS ACTIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(raceState.boats) { boat in
                        HealthIndicatorCard(boat: boat)
                    }
                }
            }
        }
    }
}

struct HealthIndicatorCard: View {
    let boat: LiveBoat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Boat ID & Role
            HStack {
                Image(systemName: roleIcon)
                    .foregroundStyle(RegattaDesign.Colors.cyan)
                Text(boat.id)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            
            Divider().opacity(0.1)
            
            // Stats Grid
            VStack(spacing: 6) {
                HealthStatRow(label: "SIGNAL", value: "88%", icon: "antenna.radiowaves.left.and.right", color: .green)
                HealthStatRow(label: "BATTERY", value: "74%", icon: "battery.75", color: .green)
                HealthStatRow(label: "DELAY", value: "120ms", icon: "timer", color: .white)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(statusColor.opacity(0.2), lineWidth: 1))
    }
    
    private var roleIcon: String {
        switch boat.role {
        case .jury: return "scalemessage.fill"
        case .media: return "camera.fill"
        default: return "sailboat.fill"
        }
    }
    
    private var statusColor: Color {
        // Mock status logic
        .green
    }
}

struct HealthStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

struct ConnectivityStatusView: View {
    @EnvironmentObject var connection: ConnectionManager
    
    var body: some View {
        HStack(spacing: 12) {
            ConnectivityPill(label: "SAT", icon: "orbit", status: .healthy)
            ConnectivityPill(label: "5G", icon: "antenna.radiowaves.left.and.right", status: .healthy)
            ConnectivityPill(label: "MESH", icon: "mesh", status: .warning)
            
            Divider().frame(height: 14).opacity(0.2)
            
            Text(String(format: "%.0f ms", connection.latencyMs))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

enum LinkStatus {
    case healthy, warning, critical
}

struct ConnectivityPill: View {
    let label: String
    let icon: String
    let status: LinkStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .black))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

struct BoatSymbolView: View {
    let role: LiveBoat.BoatRole
    let heading: Double // Degrees
    let twd: Double     // True Wind Direction in degrees
    let color: Color
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(RegattaDesign.Colors.cyan, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .blur(radius: 2)
            }
            
            switch role {
            case .sailboat:
                SailboatView(heading: heading, twd: twd, color: color)
            case .jury, .help, .media, .safety:
                RIBView(heading: heading, color: color, role: role)
            }
        }
        .rotationEffect(.degrees(heading))
    }
}

// ─── Sailboat Shape ──────────────────────────────────────────────────────────

struct SailboatView: View {
    let heading: Double
    let twd: Double
    let color: Color
    
    // Calculate sail angle based on wind
    // Sail should be on the downwind side
    private var sailAngle: Double {
        let relativeWind = (twd - heading).truncatingRemainder(dividingBy: 360)
        // Simple logic: if wind is from port, sail is on starboard (and vice versa)
        // If relativeWind is 0..180 (wind from starboard), sail is on port (-30 deg)
        // If relativeWind is 180..360 (wind from port), sail is on starboard (+30 deg)
        let normalizedWind = relativeWind < 0 ? relativeWind + 360 : relativeWind
        return (normalizedWind < 180) ? -25 : 25
    }
    
    var body: some View {
        ZStack {
            // Hull
            SleekHullShape()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 14, height: 32)
            
            // Mast
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .offset(y: -4)
            
            // Sail (Main)
            SailShape()
                .fill(.white.opacity(0.8))
                .frame(width: 2, height: 20)
                .rotationEffect(.degrees(sailAngle), anchor: .top)
                .offset(y: -4)
        }
    }
}

struct SleekHullShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // Bow
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY + 4),
                      control1: CGPoint(x: rect.maxX, y: rect.minY + 4),
                      control2: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY)) // Starboard Stern
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY)) // Port Stern
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 4))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.minX, y: rect.midY),
                      control2: CGPoint(x: rect.minX, y: rect.minY + 4))
        return path
    }
}

struct SailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// ─── RIB Shape ───────────────────────────────────────────────────────────────

struct RIBView: View {
    let heading: Double
    let color: Color
    let role: LiveBoat.BoatRole
    
    var body: some View {
        ZStack {
            // Tubes (The "RIB" part)
            RIBTubeShape()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 16, height: 30)
            
            // Center Console / Deck
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 18)
            
            // Engine
            Rectangle()
                .fill(.black)
                .frame(width: 6, height: 4)
                .offset(y: 14)
            
            // Icon identifier
            Image(systemName: roleIcon)
                .font(.system(size: 6))
                .foregroundStyle(.white)
        }
    }
    
    private var roleIcon: String {
        switch role {
        case .jury: return "scalemessage.fill"
        case .help: return "questionmark.circle.fill"
        case .media: return "camera.fill"
        case .safety: return "lifepreserver.fill"
        default: return "info.circle.fill"
        }
    }
}

struct RIBTubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w, y: 0), control2: CGPoint(x: w, y: h * 0.15))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.3))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: 0, y: h * 0.15), control2: CGPoint(x: 0, y: 0))
        
        return path
    }
}

struct BuoySymbolView: View {
    let buoyId: String
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var buoy: Buoy? {
        raceState.course.marks.first(where: { $0.id == buoyId })
    }
    
    var isSelected: Bool {
        mapInteraction.selectedBuoyId == buoyId
    }
    
    var body: some View {
        Group {
            if let buoy = buoy {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(RegattaDesign.Colors.cyan, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .blur(radius: 2)
                    }
                    
                    if buoy.type == .mark || buoy.type == .gate {
                        if let rounding = buoy.rounding {
                            RoundingIndicator(direction: rounding)
                        }
                    }
                    
                    VStack(spacing: 2) {
                        // The actual 3D-ish Buoy representation
                        ZStack {
                            switch buoy.design ?? "Cylindrical" {
                            case "Spherical":
                                SphericalBuoyShape(color: buoyColor(for: buoy))
                            case "Spar":
                                SparBuoyShape(color: buoyColor(for: buoy))
                            case "MarkSetBot":
                                MarkSetBotShape(color: buoyColor(for: buoy))
                            case "CommitteeBoat":
                                CommitteeBoatShape(color: buoyColor(for: buoy))
                            default:
                                CylindricalBuoyShape(color: buoyColor(for: buoy))
                            }
                        }
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        
                        // Label
                        if let name = buoy.name.isEmpty ? nil : buoy.name {
                            Text(name)
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                }
            }
        }
    }
    
    private func buoyColor(for buoy: Buoy) -> Color {
        Color(name: buoy.color ?? "Yellow")
    }
}

// ─── Indicators ──────────────────────────────────────────────────────────────

struct RoundingIndicator: View {
    let direction: String // "Port" or "Starboard"
    
    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.4) // A 30% arc
            .stroke(
                direction == "Port" ? Color.red : Color.green,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4])
            )
            .frame(width: 38, height: 38)
            .rotationEffect(.degrees(direction == "Port" ? -90 : 90))
            // Add a small arrowhead
            .overlay(
                Image(systemName: "triangle.fill")
                    .resizable()
                    .frame(width: 6, height: 6)
                    .foregroundColor(direction == "Port" ? .red : .green)
                    .offset(y: -19)
                    .rotationEffect(.degrees(direction == "Port" ? -50 : 50))
            )
    }
}

// ─── Buoy Shapes ─────────────────────────────────────────────────────────────

struct CylindricalBuoyShape: View {
    let color: Color
    var body: some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(color.opacity(0.8))
                .frame(height: 6)
            Rectangle()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 14)
            Ellipse()
                .fill(color)
                .frame(height: 6)
        }
    }
}

struct SphericalBuoyShape: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.8), color], center: .topLeading, startRadius: 0, endRadius: 12))
            .frame(width: 18, height: 18)
    }
}

struct SparBuoyShape: View {
    let color: Color
    var body: some View {
        ZStack(alignment: .top) {
            // Pole
            Rectangle()
                .fill(.black)
                .frame(width: 2, height: 20)
            
            // Floating Base
            Capsule()
                .fill(color)
                .frame(width: 8, height: 12)
                .offset(y: 4)
            
            // Flag
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 8)
                .offset(x: 5)
        }
    }
}

struct MarkSetBotShape: View {
    let color: Color
    var body: some View {
        ZStack {
            // Twin Pontoons
            HStack(spacing: 8) {
                Capsule().fill(.black).frame(width: 4, height: 14)
                Capsule().fill(.black).frame(width: 4, height: 14)
            }
            
            // Top Cylinder (low taper)
            CylindricalBuoyShape(color: color)
                .scaleEffect(0.6)
                .offset(y: -2)
        }
    }
}

struct CommitteeBoatShape: View {
    let color: Color
    var body: some View {
        ZStack {
            // Hull
            Capsule()
                .fill(.white)
                .frame(width: 14, height: 28)
                .overlay(Capsule().stroke(color, lineWidth: 2))
            
            // Cockpit / Cabin
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.8))
                .frame(width: 10, height: 12)
                .offset(y: -2)
            
            // RC Flag
            Path { path in
                path.move(to: CGPoint(x: 14, y: 14))
                path.addLine(to: CGPoint(x: 24, y: 14))
                path.addLine(to: CGPoint(x: 24, y: 22))
                path.addLine(to: CGPoint(x: 14, y: 22))
                path.closeSubpath()
            }
            .fill(.yellow)
            
            Text("RC")
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(.black)
                .offset(x: 19, y: 4)
        }
    }
}
