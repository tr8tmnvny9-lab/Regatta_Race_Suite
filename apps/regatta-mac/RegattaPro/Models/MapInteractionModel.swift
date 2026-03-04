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
    
    // For box selection
    @Published var selectionBoxStart: CGPoint?
    @Published var selectionBoxEnd: CGPoint?
    
    @Published var explicitMapRegion: MKCoordinateRegion? = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
}
