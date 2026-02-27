import SwiftUI

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
        case .procedureArchitect: return "rectangle.hierarchy"
        case .courseBuilder: return "ruler"
        case .fleetControl: return "person.3.sequence.fill"
        case .settings: return "gearshape.fill"
        case .regattaLive: return "video.fill"
        }
    }
}

struct MainLayoutView: View {
    @State private var selectedSection: AppSection? = .overview
    @EnvironmentObject var connection: ConnectionManager
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(AppSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.iconName)
                    }
                }
            }
            .navigationTitle("Regatta Pro")
            .listStyle(.sidebar)
        } detail: {
            if let selectedSection {
                // Placeholder router for the different native views
                switch selectedSection {
                case .overview:
                    TacticalMapView()
                case .log:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .startProcedure:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .procedureArchitect:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .courseBuilder:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .fleetControl:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .settings:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .regattaLive:
                    Text("Mac Native: \(selectedSection.rawValue) coming soon")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a section from the sidebar")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
