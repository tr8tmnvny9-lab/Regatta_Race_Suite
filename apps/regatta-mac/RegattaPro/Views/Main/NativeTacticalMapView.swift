import SwiftUI
import MapKit

// Custom tile overlay to inject maritime charts (OpenSeaMap) on top of the dark Apple Map
class MaritimeTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
        self.canReplaceMapContent = false // We just overlay on top of Apple Maps
    }
}

// Data models for Annotations
class BuoyAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var buoyId: String
    var title: String?
    
    init(buoy: Buoy) {
        self.coordinate = buoy.pos.coordinate
        self.buoyId = buoy.id
        self.title = buoy.name
        super.init()
    }
}

class BoatAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var boatId: String
    var title: String?
    
    init(boat: LiveBoat) {
        self.coordinate = boat.pos.coordinate
        self.boatId = boat.id
        self.title = boat.id
        super.init()
    }
}

// Representable Wrapper for MKMapView
struct NativeTacticalMap: NSViewRepresentable {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    // An optional closure to handle map click events
    var onMapClick: ((CLLocationCoordinate2D) -> Void)?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Use a dark, muted map style to make the colorful maritime layer pop
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        
        // Add OpenSeaMap Maritime Overlay
        let seaMapOverlay = MaritimeTileOverlay()
        mapView.addOverlay(seaMapOverlay, level: .aboveLabels)
        
        // Handle Clicks
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapClick(_:)))
        mapView.addGestureRecognizer(clickGesture)
        
        // Disable rotation and pitch to keep a pure tactical top-down view
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Sync Annotations
        updateAnnotations(on: mapView)
        
        // Sync Overlays (Boundaries, Zones, Lines)
        updateOverlays(on: mapView)
        
        // Sync Camera if instructed explicitly
        if let region = mapInteraction.explicitMapRegion {
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                mapInteraction.explicitMapRegion = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // --- Data Sync Logic ---
    private func updateAnnotations(on mapView: MKMapView) {
        var existingBuoys = [String: BuoyAnnotation]()
        var existingBoats = [String: BoatAnnotation]()
        
        for annotation in mapView.annotations {
            if let b = annotation as? BuoyAnnotation { existingBuoys[b.buoyId] = b }
            if let b = annotation as? BoatAnnotation { existingBoats[b.boatId] = b }
        }
        
        var toAdd: [MKAnnotation] = []
        var toRemove: [MKAnnotation] = []
        var keepBuoyIds = Set<String>()
        var keepBoatIds = Set<String>()
        
        // Update Buoys
        for buoy in raceState.course.marks {
            keepBuoyIds.insert(buoy.id)
            if let existing = existingBuoys[buoy.id] {
                // Update coordinate natively to animate
                UIView.animate(withDuration: 0.2) {
                    existing.coordinate = buoy.pos.coordinate
                }
            } else {
                toAdd.append(BuoyAnnotation(buoy: buoy))
            }
        }
        
        // Update Boats
        for boat in raceState.boats {
            keepBoatIds.insert(boat.id)
            if let existing = existingBoats[boat.id] {
                // Update coordinate natively to animate
                UIView.animate(withDuration: 0.2) {
                    existing.coordinate = boat.pos.coordinate
                }
                // HACK: MKAnnotation coordinate change doesn't auto-update views if we need rotation
                // We'd tell the view to rotate in the coordinator, or force a redraw
            } else {
                toAdd.append(BoatAnnotation(boat: boat))
            }
        }
        
        // Find removals
        for b in existingBuoys.values { if !keepBuoyIds.contains(b.buoyId) { toRemove.append(b) } }
        for b in existingBoats.values { if !keepBoatIds.contains(b.boatId) { toRemove.append(b) } }
        
        mapView.removeAnnotations(toRemove)
        mapView.addAnnotations(toAdd)
    }
    
    private func updateOverlays(on mapView: MKMapView) {
        // Very basic replace-all for custom shape overlays to keep sync simple initially
        // We preserve the TileOverlay
        let nonTileOverlays = mapView.overlays.filter { !($0 is MKTileOverlay) }
        mapView.removeOverlays(nonTileOverlays)
        
        // 1. Course Boundary
        if let boundary = raceState.course.courseBoundary, boundary.count > 2 {
            let coords = boundary.map { $0.coordinate }
            let polygon = CustomPolygon(coordinates: coords, count: coords.count)
            polygon.type = .boundary
            mapView.addOverlay(polygon)
        }
        
        // 2. Restriction Zones
        for zone in raceState.course.restrictionZones {
            let coords = zone.points.map { $0.coordinate }
            let polygon = CustomPolygon(coordinates: coords, count: coords.count)
            polygon.type = .restriction
            polygon.colorHex = zone.color
            mapView.addOverlay(polygon)
        }
        
        // 3. Current Measuring Line
        if let start = mapInteraction.measureStart, let end = mapInteraction.measureEnd {
            let polyline = CustomPolyline(coordinates: [start, end], count: 2)
            polyline.type = .measure
            mapView.addOverlay(polyline)
        }
        
        // 4. Start / Finish Lines
        if let sl = raceState.course.startLine, let p1 = sl.p1, let p2 = sl.p2 {
            let line = CustomPolyline(coordinates: [p1.coordinate, p2.coordinate], count: 2)
            line.type = .startLine
            mapView.addOverlay(line)
        }
    }
    
    // --- Coordinator ---
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeTacticalMap
        
        init(_ parent: NativeTacticalMap) {
            self.parent = parent
        }
        
        @objc func handleMapClick(_ gesture: NSClickGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapClick?(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            
            if let polyline = overlay as? CustomPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                switch polyline.type {
                case .measure:
                    renderer.strokeColor = .cyan
                    renderer.lineWidth = 2
                case .startLine:
                    renderer.strokeColor = .systemYellow
                    renderer.lineWidth = 3
                    renderer.lineDashPattern = [10, 5]
                default: break
                }
                return renderer
            }
            
            if let polygon = overlay as? CustomPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                switch polygon.type {
                case .boundary:
                    renderer.strokeColor = NSColor.cyan.withAlphaComponent(0.5)
                    renderer.fillColor = NSColor.cyan.withAlphaComponent(0.1)
                    renderer.lineWidth = 2
                case .restriction:
                    // Rough mapping of color string to NSColor
                    renderer.strokeColor = NSColor.systemYellow
                    renderer.fillColor = NSColor.systemYellow.withAlphaComponent(0.15)
                    renderer.lineWidth = 2
                    renderer.lineDashPattern = [5, 5]
                default: break
                }
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // We'll wrap SwiftUI views inside NSHostingView within the MKAnnotationView for seamless integration
            if let buoyAnn = annotation as? BuoyAnnotation {
                let identifier = "BuoyAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                guard let buoy = parent.raceState.course.marks.first(where: { $0.id == buoyAnn.buoyId }) else { return view }
                
                // NSHostingView injection
                let isSelected = parent.mapInteraction.selectedBuoyId == buoy.id
                let swiftUIView = BuoySymbolView(buoy: buoy, isSelected: isSelected)
                    .environmentObject(parent.raceState)
                    .environmentObject(parent.mapInteraction)
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                // Clear out old subviews
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                
                // Important: Anchor to bottom-center as requested (0.5, 1.0)
                view?.centerOffset = CGPoint(x: 0, y: -20) // Adjust based on frame size
                
                return view
            }
            
            if let boatAnn = annotation as? BoatAnnotation {
                let identifier = "BoatAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                guard let boat = parent.raceState.boats.first(where: { $0.id == boatAnn.boatId }) else { return view }
                
                let swiftUIView = BoatSymbolView(role: boat.role, heading: boat.heading, twd: parent.raceState.twd, color: Color(name: boat.color ?? "Blue"))
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                view?.centerOffset = CGPoint(x: 0, y: 0) // Center
                
                return view
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let buoyAnn = view.annotation as? BuoyAnnotation {
                parent.mapInteraction.selectedBuoyId = buoyAnn.buoyId
            }
            if let boatAnn = view.annotation as? BoatAnnotation {
                parent.mapInteraction.selectedBoatId = boatAnn.boatId
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if let buoyAnn = view.annotation as? BuoyAnnotation, parent.mapInteraction.selectedBuoyId == buoyAnn.buoyId {
                parent.mapInteraction.selectedBuoyId = nil
            }
            if let boatAnn = view.annotation as? BoatAnnotation, parent.mapInteraction.selectedBoatId == boatAnn.boatId {
                parent.mapInteraction.selectedBoatId = nil
            }
        }
    }
}

// Minimal subclasses to attach types to overlays
class CustomPolyline: MKPolyline {
    enum PolyType { case startLine, finishLine, gateLine, measure, layline }
    var type: PolyType = .measure
}

class CustomPolygon: MKPolygon {
    enum PolyType { case boundary, restriction }
    var type: PolyType = .boundary
    var colorHex: String = "Yellow"
}

