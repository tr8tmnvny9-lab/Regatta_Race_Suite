import SwiftUI
import MapKit
import CoreLocation

struct TacticalMapView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var body: some View {
        ZStack {
            NativeTacticalMap(onMapClick: { coord in
                handleMapTap(at: coord)
            })
            
            // ─── Tactical Overlays ──────────────────────────────────────────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    PerformanceOverlayView()
                }
            }
        }
        .onChange(of: mapInteraction.activeTool) { oldTool, newTool in
            if oldTool == .drawBoundary && newTool != .drawBoundary {
                if let boundary = raceState.course.courseBoundary, !boundary.isEmpty {
                    var minLat = boundary[0].lat
                    var maxLat = boundary[0].lat
                    var minLon = boundary[0].lon
                    var maxLon = boundary[0].lon
                    for pt in boundary {
                        if pt.lat < minLat { minLat = pt.lat }
                        if pt.lat > maxLat { maxLat = pt.lat }
                        if pt.lon < minLon { minLon = pt.lon }
                        if pt.lon > maxLon { maxLon = pt.lon }
                    }
                    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
                    let span = MKCoordinateSpan(latitudeDelta: max(abs(maxLat - minLat) * 1.5, 0.01), longitudeDelta: max(abs(maxLon - minLon) * 1.5, 0.01))
                    mapInteraction.explicitMapRegion = MKCoordinateRegion(center: center, span: span)
                }
            }
        }
    }
    
    // ─── Interaction Handlers ────────────────────────────────────────────────
    
    private func handleMapTap(at location: CLLocationCoordinate2D) {
        
        DispatchQueue.main.async {
            switch mapInteraction.activeTool {
            case .dropMark:
                createBuoy(at: location, type: .mark, name: "Mark \(raceState.course.marks.count + 1)")
                mapInteraction.activeTool = .cursor
            case .dropGate:
                let p1 = offsetCoordinate(location, metersLat: 0, metersLon: -40)
                let p2 = offsetCoordinate(location, metersLat: 0, metersLon: 40)
                createBuoy(at: p1, type: .gate, name: "Gate \(raceState.course.marks.count/2 + 1) P")
                createBuoy(at: p2, type: .gate, name: "Gate \(raceState.course.marks.count/2 + 1) S")
                mapInteraction.activeTool = .cursor
            case .dropStart:
                let p1 = offsetCoordinate(location, metersLat: 0, metersLon: -40)
                let p2 = offsetCoordinate(location, metersLat: 0, metersLon: 40)
                createBuoy(at: p1, type: .start, name: "Start Pin")
                createBuoy(at: p2, type: .start, name: "Start Boat")
                mapInteraction.activeTool = .cursor
            case .dropFinish:
                let p1 = offsetCoordinate(location, metersLat: 0, metersLon: -40)
                let p2 = offsetCoordinate(location, metersLat: 0, metersLon: 40)
                createBuoy(at: p1, type: .finish, name: "Finish Pin")
                createBuoy(at: p2, type: .finish, name: "Finish Boat")
                mapInteraction.activeTool = .cursor
            case .drawBoundary:
                if raceState.course.courseBoundary == nil { raceState.course.courseBoundary = [] }
                let isFirstPoint = raceState.course.courseBoundary!.isEmpty
                raceState.course.courseBoundary?.append(LatLon(lat: location.latitude, lon: location.longitude))
                if let boundary = raceState.course.courseBoundary { raceEngine.setBoundary(points: boundary.map { $0.coordinate }) }
                
                if isFirstPoint {
                    mapInteraction.explicitMapRegion = MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            case .drawRestriction:
                if mapInteraction.activeRestrictionId == nil {
                    let newId = UUID().uuidString
                    raceState.course.restrictionZones.append(RestrictionZone(id: newId, points: [LatLon(lat: location.latitude, lon: location.longitude)], color: "Yellow"))
                    mapInteraction.activeRestrictionId = newId
                } else if let idx = raceState.course.restrictionZones.firstIndex(where: { $0.id == mapInteraction.activeRestrictionId }) {
                    raceState.course.restrictionZones[idx].points.append(LatLon(lat: location.latitude, lon: location.longitude))
                }
            case .measure:
                if mapInteraction.measureStart == nil {
                    mapInteraction.measureStart = location
                    mapInteraction.measureEnd = location
                } else {
                    let p1 = LatLon(lat: mapInteraction.measureStart!.latitude, lon: mapInteraction.measureStart!.longitude)
                    let p2 = LatLon(lat: location.latitude, lon: location.longitude)
                    mapInteraction.persistentMeasurements.append(MeasurementLine(id: UUID().uuidString, p1: p1, p2: p2))
                    mapInteraction.measureStart = nil
                    mapInteraction.measureEnd = nil
                }
            case .placeTemplate:
                if let template = mapInteraction.activeTemplate {
                    // Convert relative offsets (m) to Lat/Lon drops based on the click 'location' centroid
                    let latDeltaToMeters = 111320.0
                    let lonDeltaToMeters = 111320.0 * cos(location.latitude * .pi / 180.0)
                    
                    for tm in template.marks {
                        let newLat = location.latitude + (tm.relativeY / latDeltaToMeters)
                        let newLon = location.longitude + (tm.relativeX / lonDeltaToMeters)
                        
                        let newBuoy = Buoy(
                            id: UUID().uuidString,
                            type: tm.type,
                            name: tm.name,
                            pos: LatLon(lat: newLat, lon: newLon),
                            color: tm.color ?? "Yellow",
                            rounding: tm.rounding ?? "Port",
                            design: tm.design ?? "Cylindrical",
                            showLaylines: false,
                            laylineDirection: 0.0
                        )
                        raceState.course.marks.append(newBuoy)
                        raceEngine.updateBuoyConfig(buoy: newBuoy)
                    }
                }
                mapInteraction.activeTool = .cursor
                mapInteraction.activeTemplate = nil
            case .cursor:
                mapInteraction.selectedBuoyId = nil; mapInteraction.selectedBoatId = nil; mapInteraction.measureStart = nil; mapInteraction.measureEnd = nil
                mapInteraction.persistentMeasurements = []
            default: break
            }
        }
    }
    
    // ─── Helpers ─────────────────────────────────────────────────────────────
    
    private func createBuoy(at: CLLocationCoordinate2D, type: BuoyType, name: String) {
        let newBuoy = Buoy(id: UUID().uuidString, type: type, name: name, pos: LatLon(lat: at.latitude, lon: at.longitude), color: "Yellow", design: "Cylindrical")
        raceState.course.marks.append(newBuoy)
        raceEngine.updateBuoyConfig(buoy: newBuoy)
    }
    
    private func moveBuoy(id: String, to: CLLocationCoordinate2D) {
        if let idx = raceState.course.marks.firstIndex(where: { $0.id == id }) {
            raceState.course.marks[idx].pos = LatLon(lat: to.latitude, lon: to.longitude)
            raceEngine.updateBuoyConfig(buoy: raceState.course.marks[idx])
        }
    }
    
    private func midpoint(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (p1.latitude + p2.latitude) / 2, longitude: (p1.longitude + p2.longitude) / 2)
    }
    
    private func offsetCoordinate(_ coord: CLLocationCoordinate2D, metersLat: Double, metersLon: Double) -> CLLocationCoordinate2D {
        let latDelta = metersLat / 111320.0
        let lonDelta = metersLon / (111320.0 * cos(coord.latitude * .pi / 180))
        return CLLocationCoordinate2D(latitude: coord.latitude + latDelta, longitude: coord.longitude + lonDelta)
    }
    
}

// ─── Mathematical Helpers ───────────────────────────────────────────────────

fileprivate func calculateLaylinePoints(from buoy: Buoy, twd: Double, boundary: [LatLon]?) -> [[CLLocationCoordinate2D]] {
    let angle = buoy.laylineDirection // 0 for upwind, 180 for downwind
    let b1 = angle == 0 ? twd - 135 : twd - 45
    let b2 = angle == 0 ? twd + 135 : twd + 45
    
    let p1 = destination(from: buoy.pos.coordinate, distance: 10000.0, bearing: b1)
    let p2 = destination(from: buoy.pos.coordinate, distance: 10000.0, bearing: b2)
    
    var end1 = p1
    var end2 = p2
    
    if let boundary = boundary, boundary.count > 2 {
        var minDist1 = Double.greatestFiniteMagnitude
        var minDist2 = Double.greatestFiniteMagnitude
        for i in 0..<boundary.count {
            let p3 = boundary[i].coordinate
            let p4 = boundary[(i + 1) % boundary.count].coordinate
            
            if let i1 = lineIntersect(p1: buoy.pos.coordinate, p2: p1, p3: p3, p4: p4) {
                let d = distanceSquared(buoy.pos.coordinate, i1)
                if d < minDist1 { minDist1 = d; end1 = i1 }
            }
            if let i2 = lineIntersect(p1: buoy.pos.coordinate, p2: p2, p3: p3, p4: p4) {
                let d = distanceSquared(buoy.pos.coordinate, i2)
                if d < minDist2 { minDist2 = d; end2 = i2 }
            }
        }
    }
    
    return [[buoy.pos.coordinate, end1], [buoy.pos.coordinate, end2]]
}

fileprivate func lineIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
    let x1 = p1.longitude, y1 = p1.latitude
    let x2 = p2.longitude, y2 = p2.latitude
    let x3 = p3.longitude, y3 = p3.latitude
    let x4 = p4.longitude, y4 = p4.latitude
    let den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if den == 0 { return nil }
    let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den
    if t > 0 && t < 1 && u > 0 && u < 1 { return CLLocationCoordinate2D(latitude: y1 + t * (y2 - y1), longitude: x1 + t * (x2 - x1)) }
    return nil
}

fileprivate func distanceSquared(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> Double {
    let d1 = p1.latitude - p2.latitude
    let d2 = p1.longitude - p2.longitude
    return d1 * d1 + d2 * d2
}

fileprivate func destination(from: CLLocationCoordinate2D, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
    let radius = 6371000.0
    let angularDist = distance / radius
    let bearRad = bearing * .pi / 180
    let latRad = from.latitude * .pi / 180
    let lonRad = from.longitude * .pi / 180
    let destLat = asin(sin(latRad) * cos(angularDist) + cos(latRad) * sin(angularDist) * cos(bearRad))
    let destLon = lonLonAndBearing(lonRad: lonRad, bearRad: bearRad, angularDist: angularDist, latRad: latRad, destLat: destLat)
    return CLLocationCoordinate2D(latitude: destLat * 180 / .pi, longitude: destLon * 180 / .pi)
}

fileprivate func lonLonAndBearing(lonRad: Double, bearRad: Double, angularDist: Double, latRad: Double, destLat: Double) -> Double {
    lonRad + atan2(sin(bearRad) * sin(angularDist) * cos(latRad), cos(angularDist) - sin(latRad) * sin(destLat))
}

struct MeasurementBubble: View {
    let p1: CLLocationCoordinate2D
    let p2: CLLocationCoordinate2D
    var body: some View {
        let dist = distance(p1, p2)
        let bear = bearing(p1, p2)
        VStack(spacing: 2) {
            Text(String(format: "%.2f NM", dist / 1852.0)).font(.system(size: 10, weight: .bold))
            Text(String(format: "%03.0f°", bear)).font(.system(size: 8)).foregroundStyle(.secondary)
        }.padding(6).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.1), lineWidth: 1))
    }
    private func distance(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: p1.latitude, longitude: p1.longitude).distance(from: CLLocation(latitude: p2.latitude, longitude: p2.longitude))
    }
    private func bearing(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> Double {
        let lat1 = p1.latitude * .pi / 180; let lon1 = p1.longitude * .pi / 180
        let lat2 = p2.latitude * .pi / 180; let lon2 = p2.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
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
    @objc dynamic var coordinate: CLLocationCoordinate2D
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
    @EnvironmentObject var raceEngine: RaceEngineClient
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
        
        // Handle custom Drags
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
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
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    existing.coordinate = buoy.pos.coordinate
                }, completionHandler: nil)
                
                // Force update the SwiftUI View to reflect color/shape changes
                if let annView = mapView.view(for: existing),
                   let hostingView = annView.subviews.first as? NSHostingView<AnyView> {
                   let swiftUIView = AnyView(BuoySymbolView(buoyId: buoy.id)
                        .environmentObject(raceState)
                        .environmentObject(mapInteraction)
                        .allowsHitTesting(false))
                   hostingView.rootView = swiftUIView
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
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    existing.coordinate = boat.pos.coordinate
                }, completionHandler: nil)
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
        
        // 4. Start / Finish / Gate Lines
        let starts = raceState.course.marks.filter { $0.type == .start }
        if starts.count == 2 {
            let line = CustomPolyline(coordinates: [starts[0].pos.coordinate, starts[1].pos.coordinate], count: 2)
            line.type = .startLine
            mapView.addOverlay(line)
        }
        
        let finishes = raceState.course.marks.filter { $0.type == .finish }
        if finishes.count == 2 {
            let line = CustomPolyline(coordinates: [finishes[0].pos.coordinate, finishes[1].pos.coordinate], count: 2)
            line.type = .startLine
            mapView.addOverlay(line)
        }
        
        let gates = raceState.course.marks.filter { $0.type == .gate }
        let groupedGates = Dictionary(grouping: gates, by: { String($0.name.dropLast(2)) })
        for (_, pair) in groupedGates {
            if pair.count == 2 {
                let line = CustomPolyline(coordinates: [pair[0].pos.coordinate, pair[1].pos.coordinate], count: 2)
                line.type = .startLine // Use same dashed line style
                mapView.addOverlay(line)
            }
        }
        
        // 5. Laylines
        for buoy in raceState.course.marks {
            if buoy.showLaylines {
                let laylines = calculateLaylinePoints(from: buoy, twd: raceState.twd, boundary: raceState.course.courseBoundary)
                for lines in laylines {
                    let polyline = CustomPolyline(coordinates: lines, count: 2)
                    polyline.type = .layline
                    mapView.addOverlay(polyline)
                }
            }
        }
        
        // 6. Selection Box
        if let start = mapInteraction.selectionBoxStart, let end = mapInteraction.selectionBoxEnd {
            let startCoord = mapView.convert(start, toCoordinateFrom: mapView)
            let endCoord = mapView.convert(end, toCoordinateFrom: mapView)
            
            let coords = [
                CLLocationCoordinate2D(latitude: startCoord.latitude, longitude: startCoord.longitude),
                CLLocationCoordinate2D(latitude: startCoord.latitude, longitude: endCoord.longitude),
                CLLocationCoordinate2D(latitude: endCoord.latitude, longitude: endCoord.longitude),
                CLLocationCoordinate2D(latitude: endCoord.latitude, longitude: startCoord.longitude)
            ]
            let polygon = CustomPolygon(coordinates: coords, count: 4)
            polygon.type = .selectionBox
            mapView.addOverlay(polygon)
        }
    }
    
    // --- Coordinator ---
    class Coordinator: NSObject, MKMapViewDelegate, NSGestureRecognizerDelegate {
        var parent: NativeTacticalMap
        var draggedAnnotation: BuoyAnnotation?
        var dragOffset: CGPoint = .zero
        
        init(_ parent: NativeTacticalMap) {
            self.parent = parent
        }
        
        @objc func handleMapClick(_ gesture: NSClickGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            
            var didHitAnnotation = false
            for annotation in mapView.annotations {
                if let buoyAnn = annotation as? BuoyAnnotation {
                    let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                    if hypot(point.x - annPoint.x, point.y - annPoint.y) < 25 {
                        
                        // If shift is held or something, maybe add. For now, replace single select.
                        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                            if parent.mapInteraction.selectedBuoyIds.contains(buoyAnn.buoyId) {
                                parent.mapInteraction.selectedBuoyIds.remove(buoyAnn.buoyId)
                            } else {
                                parent.mapInteraction.selectedBuoyIds.insert(buoyAnn.buoyId)
                            }
                        } else {
                            if !parent.mapInteraction.selectedBuoyIds.contains(buoyAnn.buoyId) {
                                parent.mapInteraction.selectedBuoyIds = [buoyAnn.buoyId]
                            }
                        }
                        
                        parent.mapInteraction.selectedBuoyId = buoyAnn.buoyId // Legacy fallback
                        didHitAnnotation = true
                        break
                    }
                }
            }
            
            if !didHitAnnotation {
                if parent.mapInteraction.activeTool != .selectBox {
                    parent.mapInteraction.selectedBuoyIds.removeAll()
                    parent.mapInteraction.selectedBuoyId = nil // Deselect on blank map click
                }
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                parent.onMapClick?(coordinate)
            }
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            if let panGesture = gestureRecognizer as? NSPanGestureRecognizer, let mapView = panGesture.view as? MKMapView {
                let point = panGesture.location(in: mapView)
                
                // Allow drag if Select Box tool is active
                if parent.mapInteraction.activeTool == .selectBox {
                    return true
                }
                
                for annotation in mapView.annotations {
                    if let buoyAnn = annotation as? BuoyAnnotation {
                        let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                        if hypot(point.x - annPoint.x, point.y - annPoint.y) < 25 {
                            return true // Accept drag because we hit a buoy
                        }
                    }
                }
                return false // Reject drag, allow map to pan normally
            }
            return true
        }

        @objc func handleMapPan(_ gesture: NSPanGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            
            if parent.mapInteraction.activeTool == .selectBox {
                switch gesture.state {
                case .began:
                    parent.mapInteraction.selectionBoxStart = point
                    parent.mapInteraction.selectionBoxEnd = point
                case .changed:
                    parent.mapInteraction.selectionBoxEnd = point
                case .ended, .cancelled:
                    if let start = parent.mapInteraction.selectionBoxStart {
                        let rect = CGRect(
                            x: min(start.x, point.x),
                            y: min(start.y, point.y),
                            width: abs(point.x - start.x),
                            height: abs(point.y - start.y)
                        )
                        
                        var newSelection = Set<String>()
                        for annotation in mapView.annotations {
                            if let buoyAnn = annotation as? BuoyAnnotation {
                                let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                                if rect.contains(annPoint) {
                                    newSelection.insert(buoyAnn.buoyId)
                                }
                            }
                        }
                        
                        if !newSelection.isEmpty {
                            parent.mapInteraction.selectedBuoyIds = newSelection
                            parent.mapInteraction.selectedBuoyId = newSelection.first // Legacy fallback
                            parent.mapInteraction.activeTool = .cursor // Revert tool
                        }
                    }
                    parent.mapInteraction.selectionBoxStart = nil
                    parent.mapInteraction.selectionBoxEnd = nil
                default: break
                }
                return
            }

            // Normal Drag Logic (Includes Group Drag)
            switch gesture.state {
            case .began:
                for annotation in mapView.annotations {
                    if let buoyAnn = annotation as? BuoyAnnotation {
                        let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                        if hypot(point.x - annPoint.x, point.y - annPoint.y) < 25 {
                            draggedAnnotation = buoyAnn
                            
                            // If dragging an unselected mark, select it.
                            if !parent.mapInteraction.selectedBuoyIds.contains(buoyAnn.buoyId) {
                                parent.mapInteraction.selectedBuoyIds = [buoyAnn.buoyId]
                            }
                            
                            dragOffset = CGPoint(x: point.x - annPoint.x, y: point.y - annPoint.y)
                            return
                        }
                    }
                }
            case .changed:
                if let _ = draggedAnnotation {
                    let newPoint = CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)
                    let newCoordinate = mapView.convert(newPoint, toCoordinateFrom: mapView)
                    
                    if parent.mapInteraction.selectedBuoyIds.count > 1 {
                        // Complex Group Drag: Calculate lat/lon delta based on primary clicked annotation
                        if let primaryAnn = draggedAnnotation {
                            let latDelta = newCoordinate.latitude - primaryAnn.coordinate.latitude
                            let lonDelta = newCoordinate.longitude - primaryAnn.coordinate.longitude
                            
                            for id in parent.mapInteraction.selectedBuoyIds {
                                if let ann = mapView.annotations.first(where: { ($0 as? BuoyAnnotation)?.buoyId == id }) as? BuoyAnnotation {
                                    ann.coordinate = CLLocationCoordinate2D(latitude: ann.coordinate.latitude + latDelta, longitude: ann.coordinate.longitude + lonDelta)
                                }
                            }
                        }
                    } else {
                        // Single Drag
                        draggedAnnotation?.coordinate = newCoordinate
                    }
                }
            case .ended, .cancelled:
                if draggedAnnotation != nil {
                    // Final sync for ALL selected markers
                    let idsToSync = parent.mapInteraction.selectedBuoyIds
                    DispatchQueue.main.async {
                        for id in idsToSync {
                            // Find the map annotation coordinate
                            if let finalAnn = mapView.annotations.first(where: { ($0 as? BuoyAnnotation)?.buoyId == id }) as? BuoyAnnotation {
                                if let idx = self.parent.raceState.course.marks.firstIndex(where: { $0.id == id }) {
                                    // Update State
                                    self.parent.raceState.course.marks[idx].pos = LatLon(lat: finalAnn.coordinate.latitude, lon: finalAnn.coordinate.longitude)
                                    // Ship to rust
                                    self.parent.raceEngine.updateBuoyConfig(buoy: self.parent.raceState.course.marks[idx])
                                }
                            }
                        }
                    }
                    draggedAnnotation = nil
                }
            default: break
            }
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
                case .layline:
                    renderer.strokeColor = .green.withAlphaComponent(0.6)
                    renderer.lineWidth = 2
                    renderer.lineDashPattern = [10, 10]
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
                case .selectionBox:
                    renderer.strokeColor = NSColor.white
                    renderer.fillColor = NSColor.white.withAlphaComponent(0.1)
                    renderer.lineWidth = 1
                    renderer.lineDashPattern = [4, 4]
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
                
                // NSHostingView injection. Turn off allowsHitTesting so dragging passes through to MKAnnotationView
                let swiftUIView = AnyView(BuoySymbolView(buoyId: buoy.id)
                    .environmentObject(parent.raceState)
                    .environmentObject(parent.mapInteraction)
                    .allowsHitTesting(false))
                
                let hostingView: NSHostingView<AnyView>
                if let existing = view?.subviews.first as? NSHostingView<AnyView> {
                    hostingView = existing
                    hostingView.rootView = swiftUIView
                } else {
                    hostingView = NSHostingView(rootView: swiftUIView)
                    hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                    view?.subviews.forEach { $0.removeFromSuperview() }
                    view?.addSubview(hostingView)
                }
                
                view?.frame = CGRect(x: 0, y: 0, width: 40, height: 40) // Explicit frame for native MKMapView drag hit rect
                
                // Important: Anchor to center for layline geometry alignment
                view?.centerOffset = CGPoint(x: 0, y: 0)
                
                return view
            }
            
            if let boatAnn = annotation as? BoatAnnotation {
                let identifier = "BoatAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                // Boats should generally not be manually draggable unless intended, but adding property
                view?.isDraggable = false
                
                guard let boat = parent.raceState.boats.first(where: { $0.id == boatAnn.boatId }) else { return view }
                
                let swiftUIView = BoatSymbolView(role: boat.role, heading: boat.heading, twd: parent.raceState.twd, color: Color(name: boat.color ?? "Blue"))
                    .allowsHitTesting(false)
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                
                view?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                view?.centerOffset = CGPoint(x: 0, y: 0) // Center
                
                return view
            }
            
            return nil
        }
    }
}

// Minimal subclasses to attach types to overlays
class CustomPolyline: MKPolyline {
    enum PolyType { case startLine, finishLine, gateLine, measure, layline }
    var type: PolyType = .measure
}

class CustomPolygon: MKPolygon {
    enum PolyType { case boundary, restriction, selectionBox }
    var type: PolyType = .boundary
    var colorHex: String = "Yellow"
}

