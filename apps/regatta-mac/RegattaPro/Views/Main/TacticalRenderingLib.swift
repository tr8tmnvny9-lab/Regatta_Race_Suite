import SwiftUI
import MapKit
import QuartzCore

// --- Shared Tactical Protocols ---

protocol TacticalProvider: AnyObject {
    var raceState: RaceStateModel { get }
    var mapInteraction: MapInteractionModel { get }
}

// --- Shared Data Models & Annotations ---

class MaritimeTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
        self.canReplaceMapContent = false
    }
}

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
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var boatId: String
    var title: String?
    
    init(boat: LiveBoat) {
        self.coordinate = boat.pos.coordinate
        self.boatId = boat.id
        self.title = boat.teamName ?? boat.id
        super.init()
    }
}

class CustomPolyline: MKPolyline {
    enum PolyType { case startLine, finishLine, gateLine, measure, layline }
    var type: PolyType = .measure
}

class CustomPolygon: MKPolygon {
    enum PolyType { case boundary, restriction }
    var type: PolyType = .boundary
    var colorHex: String = "Yellow"
}

struct DiamondEnvelope {
    let uS: CGPoint
    let uP: CGPoint
    let minS: Double
    let maxS: Double
    let minP: Double
    let maxP: Double
}

// --- High Performance Shared Renderer ---

class DynamicTacticalOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var boundingMapRect: MKMapRect = .world
}

class DynamicTacticalRenderer: MKOverlayRenderer {
    weak var provider: TacticalProvider? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Direct drag properties to bypass SwiftUI latency for interactive views
    var dragMarkId: String? = nil
    var dragCoordinate: CLLocationCoordinate2D? = nil
    
    init(overlay: MKOverlay, provider: TacticalProvider) {
        self.provider = provider
        super.init(overlay: overlay)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let raceState = provider?.raceState else { return }
        
        context.setLineJoin(.round)
        context.setLineCap(.round)
        
        drawBoundaries(in: context, zoomScale: zoomScale)
        drawCourseLines(in: context, zoomScale: zoomScale)
        drawLaylines(in: context, zoomScale: zoomScale)
        
        if let mapInteraction = provider?.mapInteraction,
           let start = mapInteraction.measureStart, let end = mapInteraction.measureEnd {
            context.setStrokeColor(NSColor.cyan.cgColor)
            context.setLineWidth(2.0 / zoomScale)
            let p1 = point(for: MKMapPoint(start))
            let p2 = point(for: MKMapPoint(end))
            context.strokeLineSegments(between: [p1, p2])
        }
    }
    
    private func getCoord(_ buoy: Buoy) -> CLLocationCoordinate2D {
        if dragMarkId == buoy.id, let coord = dragCoordinate {
            return coord
        }
        return buoy.pos.coordinate
    }
    
    private func drawBoundaries(in context: CGContext, zoomScale: MKZoomScale) {
        guard let raceState = provider?.raceState else { return }
        
        // Boundaries
        if let boundary = raceState.course.courseBoundary, boundary.count > 2 {
            context.beginPath()
            let firstPt = point(for: MKMapPoint(boundary[0].coordinate))
            context.move(to: firstPt)
            for i in 1..<boundary.count {
                let pt = point(for: MKMapPoint(boundary[i].coordinate))
                context.addLine(to: pt)
            }
            context.closePath()
            context.setStrokeColor(NSColor.cyan.withAlphaComponent(0.5).cgColor)
            context.setFillColor(NSColor.cyan.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(2.0 / zoomScale)
            context.drawPath(using: .fillStroke)
        }
        
        // Restriction Zones
        for zone in raceState.course.restrictionZones {
            if zone.points.count < 3 { continue }
            context.beginPath()
            let firstPt = point(for: MKMapPoint(zone.points[0].coordinate))
            context.move(to: firstPt)
            for i in 1..<zone.points.count {
                let pt = point(for: MKMapPoint(zone.points[i].coordinate))
                context.addLine(to: pt)
            }
            context.closePath()
            let color = NSColor(named: zone.color) ?? .systemYellow
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.withAlphaComponent(0.15).cgColor)
            context.setLineWidth(2.0 / zoomScale)
            context.setLineDash(phase: 0, lengths: [5.0 / zoomScale, 5.0 / zoomScale])
            context.drawPath(using: .fillStroke)
            context.setLineDash(phase: 0, lengths: [])
        }
    }
    
    private func drawCourseLines(in context: CGContext, zoomScale: MKZoomScale) {
        guard let raceState = provider?.raceState else { return }
        
        func strokeLine(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, color: NSColor, dash: [CGFloat] = []) {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2.0 / zoomScale)
            if !dash.isEmpty {
                context.setLineDash(phase: 0, lengths: dash.map { $0 / zoomScale })
            }
            let pt1 = point(for: MKMapPoint(p1))
            let pt2 = point(for: MKMapPoint(p2))
            context.strokeLineSegments(between: [pt1, pt2])
            context.setLineDash(phase: 0, lengths: [])
        }
        
        let marks = raceState.course.marks
        
        // Start Lines
        let starts = marks.filter { $0.type == .start }
        if starts.count == 2 {
            strokeLine(p1: getCoord(starts[0]), p2: getCoord(starts[1]), color: .systemYellow, dash: [10, 5])
        }
        
        // Finish Lines
        let finishes = marks.filter { $0.type == .finish }
        if finishes.count == 2 {
            strokeLine(p1: getCoord(finishes[0]), p2: getCoord(finishes[1]), color: .white, dash: [10, 5])
        }
        
        // Gates
        let gates = marks.filter { $0.type == .gate }
        var processed = Set<String>()
        for m in gates {
            if processed.contains(m.id) { continue }
            let nameParts = m.name.components(separatedBy: " ")
            let prefix = nameParts.dropLast().joined(separator: " ")
            if !prefix.isEmpty, let sibling = gates.first(where: { $0.id != m.id && !processed.contains($0.id) && $0.name.hasPrefix(prefix) }) {
                strokeLine(p1: getCoord(m), p2: getCoord(sibling), color: NSColor.systemYellow.withAlphaComponent(0.8), dash: [5, 5])
                processed.insert(m.id)
                processed.insert(sibling.id)
            }
        }
    }
    
    private func drawLaylines(in context: CGContext, zoomScale: MKZoomScale) {
        guard let raceState = provider?.raceState else { return }
        
        let activeMarks = raceState.course.marks.filter { $0.showLaylines }
        guard !activeMarks.isEmpty else { return }
        
        let globalEnvelope = findDiamondEnvelope(marks: raceState.course.marks, twd: raceState.twd)
        
        context.setStrokeColor(NSColor.cyan.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5 / zoomScale)
        context.setLineDash(phase: 0, lengths: [2.0 / zoomScale, 4.0 / zoomScale])
        
        for buoy in activeMarks {
            let buoyCoord = getCoord(buoy)
            let segments = calculateLaylinePoints(
                from: buoy,
                coordinate: buoyCoord,
                twd: raceState.twd,
                boundary: raceState.course.courseBoundary,
                envelope: globalEnvelope
            )
            for seg in segments {
                let p1 = point(for: MKMapPoint(seg[0]))
                let p2 = point(for: MKMapPoint(seg[1]))
                context.strokeLineSegments(between: [p1, p2])
            }
        }
        context.setLineDash(phase: 0, lengths: [])
    }
}

// --- Mathematical Helpers ---

func findDiamondEnvelope(marks: [Buoy], twd: Double) -> DiamondEnvelope? {
    guard !marks.isEmpty else { return nil }
    
    let radS = (twd + 45) * .pi / 180
    let radP = (twd - 45) * .pi / 180
    let uS = CGPoint(x: sin(radS), y: -cos(radS))
    let uP = CGPoint(x: sin(radP), y: -cos(radP))
    
    func getS(_ pt: MKMapPoint) -> Double { Double(uS.x) * pt.x + Double(uS.y) * pt.y }
    func getP(_ pt: MKMapPoint) -> Double { Double(uP.x) * pt.x + Double(uP.y) * pt.y }
    
    var minS = Double.greatestFiniteMagnitude, maxS = -Double.greatestFiniteMagnitude
    var minP = Double.greatestFiniteMagnitude, maxP = -Double.greatestFiniteMagnitude
    
    for m in marks {
        let mp = MKMapPoint(m.pos.coordinate)
        let s = getS(mp); let p = getP(mp)
        if s < minS { minS = s }; if s > maxS { maxS = s }
        if p < minP { minP = p }; if p > maxP { maxP = p }
    }
    
    return DiamondEnvelope(uS: uS, uP: uP, minS: minS, maxS: maxS, minP: minP, maxP: maxP)
}

func calculateLaylinePoints(from buoy: Buoy, coordinate: CLLocationCoordinate2D? = nil, twd: Double, boundary: [LatLon]?, envelope: DiamondEnvelope? = nil) -> [[CLLocationCoordinate2D]] {
    let startCoord = coordinate ?? buoy.pos.coordinate
    let mp0 = MKMapPoint(startCoord)
    let isUpwind = buoy.laylineDirection == 0
    
    var end1 = destination(from: startCoord, distance: 30000.0, bearing: isUpwind ? twd - 135 : twd - 45)
    var end2 = destination(from: startCoord, distance: 30000.0, bearing: isUpwind ? twd + 135 : twd + 45)
    
    if let env = envelope {
        let s0 = Double(env.uS.x) * mp0.x + Double(env.uS.y) * mp0.y
        let p0 = Double(env.uP.x) * mp0.x + Double(env.uP.y) * mp0.y
        
        if isUpwind {
            let mpStar = MKMapPoint(x: mp0.x + (env.minP - p0) * Double(env.uP.x), y: mp0.y + (env.minP - p0) * Double(env.uP.y))
            let mpPort = MKMapPoint(x: mp0.x + (env.minS - s0) * Double(env.uS.x), y: mp0.y + (env.minS - s0) * Double(env.uS.y))
            end2 = mpStar.coordinate
            end1 = mpPort.coordinate
        } else {
            let mpStar = MKMapPoint(x: mp0.x + (env.maxS - s0) * Double(env.uS.x), y: mp0.y + (env.maxS - s0) * Double(env.uS.y))
            let mpPort = MKMapPoint(x: mp0.x + (env.maxP - p0) * Double(env.uP.x), y: mp0.y + (env.maxP - p0) * Double(env.uP.y))
            end2 = mpStar.coordinate
            end1 = mpPort.coordinate
        }
    }
    
    if let boundary = boundary, boundary.count > 2 {
        for i in 0..<boundary.count {
            let p3 = boundary[i].coordinate
            let p4 = boundary[(i + 1) % boundary.count].coordinate
            if let intersect1 = lineIntersect(p1: startCoord, p2: end1, p3: p3, p4: p4) { end1 = intersect1 }
            if let intersect2 = lineIntersect(p1: startCoord, p2: end2, p3: p3, p4: p4) { end2 = intersect2 }
        }
    }
    
    return [[startCoord, end1], [startCoord, end2]]
}

func lineIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
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

func destination(from: CLLocationCoordinate2D, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
    let radius = 6371000.0
    let angularDist = distance / radius
    let bearRad = bearing * .pi / 180
    let latRad = from.latitude * .pi / 180
    let lonRad = from.longitude * .pi / 180
    let destLat = asin(sin(latRad) * cos(angularDist) + cos(latRad) * sin(angularDist) * cos(bearRad))
    let destLon = lonRad + atan2(sin(bearRad) * sin(angularDist) * cos(latRad), cos(angularDist) - sin(latRad) * sin(destLat))
    return CLLocationCoordinate2D(latitude: destLat * 180 / .pi, longitude: destLon * 180 / .pi)
}
