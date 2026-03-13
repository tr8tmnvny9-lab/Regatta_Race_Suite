import SwiftUI
import MapKit
import CoreLocation

enum CourseTool: String, CaseIterable, Identifiable {
    case cursor = "Select"
    case dropMark = "Add Mark"
    case dropGate = "Add Gate"
    case dropStart = "Add Start"
    case dropFinish = "Add Finish"
    case drawBoundary = "Draw Boundary"
    case drawRestriction = "Add No-Go Zone"
    case drawLine = "Draw Line"
    case measure = "Measure"
    case selectBox = "Box Select"
    case placeTemplate = "Place Template"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .cursor: return "cursorarrow"
        case .dropMark: return "mappin.circle.fill"
        case .dropGate: return "arrow.left.and.right.circle.fill"
        case .dropStart: return "flag.checkered.2.crossing"
        case .dropFinish: return "flag.checkered"
        case .drawBoundary: return "skew"
        case .drawRestriction: return "exclamationmark.triangle.fill"
        case .drawLine: return "line.diagonal"
        case .measure: return "ruler"
        case .selectBox: return "selection.pin.in.out"
        case .placeTemplate: return "square.dashed.on.square.dashed"
        }
    }
}

struct MeasurementLine: Identifiable, Codable {
    let id: String
    let p1: LatLon
    let p2: LatLon
}

final class MapInteractionModel: ObservableObject {
    @Published var activeTool: CourseTool = .cursor
    @Published var activeTemplate: CourseTemplate?
    @Published var selectedBuoyId: String? // Legacy single select
    @Published var selectedBuoyIds: Set<String> = [] // Phase 16 multi-select
    @Published var selectedBoatId: String?
    @Published var measureStart: CLLocationCoordinate2D?
    @Published var measureEnd: CLLocationCoordinate2D?
    @Published var persistentMeasurements: [MeasurementLine] = []
    @Published var activeRestrictionId: String?
    
    // Smooth Dragging State
    @Published var draggingMarkId: String?
    @Published var draggingCoordinate: CLLocationCoordinate2D?
    
    // For box selection
    @Published var selectionBoxStart: CGPoint?
    @Published var selectionBoxEnd: CGPoint?
    
    @Published var explicitMapRegion: MKCoordinateRegion?
    
    // Default to Helsinki water areas
    @Published var homeWaterRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.2)
    )
    
    // Live Map specific viewport state
    @Published var liveMapRegion: MKCoordinateRegion?
    @Published var isLiveMapAutoTracking: Bool = true
    
    // Performance View Settings (Standard state is ON)
    @Published var showMarkZones: Bool = true
    @Published var markZoneMultiplier: Double = 3.0
    
    @Published var showHeightToMark: Bool = true
    @Published var heightToMarkSpacing: Double = 50.0
    
    // 3D Specific Settings
    @Published var show3DWall: Bool = true
    @Published var show3DLogos: Bool = true
    @Published var sponsorLogoPath: String = "" // Placeholder for dynamic asset
    
    // Persist the last used course zoom to maintain parity between views
    @Published var lastAppliedCourseRegion: MKCoordinateRegion?
    
    init() {
        // Initialization can handle loading from AppStorage if needed, but for now we set the starting region
        self.explicitMapRegion = homeWaterRegion
        self.liveMapRegion = homeWaterRegion
    }
    
    func resetLiveMapToDesigner() {
        if let designerRegion = lastAppliedCourseRegion {
            liveMapRegion = designerRegion
            isLiveMapAutoTracking = false
        }
    }
}
