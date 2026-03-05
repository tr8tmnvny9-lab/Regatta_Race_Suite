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
    case systemArchitecture = "System Architecture"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .overview:             return "map.fill"
        case .log:                  return "list.bullet.rectangle.portrait"
        case .startProcedure:       return "flag.checkered"
        case .procedureArchitect:   return "point.topleft.down.curvedto.point.bottomright.up"
        case .courseBuilder:        return "ruler"
        case .fleetControl:         return "person.3.sequence.fill"
        case .settings:             return "gearshape.fill"
        case .regattaLive:          return "video.fill"
        case .systemArchitecture:   return "point.3.connected.trianglepath.dotted"
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
            
            ForEach(AppSection.allCases.filter {
                $0 != .procedureArchitect && $0 != .systemArchitecture
            }) { section in
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
            
            // System Architecture (Special - AWS/SNPN awareness)
            NavButton(
                icon: AppSection.systemArchitecture.iconName,
                isActive: selectedSection == .systemArchitecture,
                onClick: { selectedSection = .systemArchitecture },
                color: .teal
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

            SystemArchitectureView()
                .opacity(section == .systemArchitecture ? 1 : 0)
                .allowsHitTesting(section == .systemArchitecture)
            
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


