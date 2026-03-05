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
