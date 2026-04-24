import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case fleet = "Fleet Profiles"
    case map = "Map & Navigation"
    case network = "Network & Cloud"
    case trackers = "Trackers & Sensors"
    case identity = "Identity"
    case developer = "Developer Tools"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .fleet: return "sailboat.fill"
        case .map: return "map.fill"
        case .network: return "network"
        case .trackers: return "qrcode.viewfinder"
        case .identity: return "person.crop.circle.fill"
        case .developer: return "hammer.fill"
        }
    }
}

struct SettingsContainerView: View {
    @State private var activeSection: SettingsSection = .fleet
    @AppStorage("showDebugMenu") private var showDebugMenu = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Nested Sidebar
            VStack(alignment: .leading, spacing: 12) {
                Text("SETTINGS")
                    .font(RegattaDesign.Fonts.label)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                
                ForEach(SettingsSection.allCases) { section in
                    if section != .developer || showDebugMenu {
                        SettingsNavButton(
                            title: section.rawValue,
                            icon: section.icon,
                            isActive: activeSection == section,
                            onClick: { activeSection = section }
                        )
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .frame(width: 220)
            .background(Color.black.opacity(0.2))
            
            Divider().opacity(0.1)
            
            // Content Area
            ZStack {
                Color.black.opacity(0.1).ignoresSafeArea()
                
                switch activeSection {
                case .fleet:
                    BoatBuilderView()
                        .transition(.opacity)
                case .map:
                    MapSettingsView()
                        .transition(.opacity)
                case .network:
                    NetworkSettingsView()
                        .transition(.opacity)
                case .trackers:
                    TrackersAndSensorsSettingsView()
                        .transition(.opacity)
                case .identity:
                    IdentitySettingsView()
                        .transition(.opacity)
                case .developer:
                    DeveloperSettingsView()
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeSection)
        }
        .glassPanel()
    }
}

struct SettingsNavButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 20)
                
                Text(title.uppercased())
                    .font(RegattaDesign.Fonts.label)
                    .tracking(1)
                
                Spacer()
                
                if isActive {
                    Circle()
                        .fill(RegattaDesign.Colors.electricBlue)
                        .frame(width: 6, height: 6)
                        .shadow(color: RegattaDesign.Colors.electricBlue, radius: 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                }
            }
            .foregroundStyle(isActive ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
