import SwiftUI
import CoreLocation
import MapKit

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
        guard let center = mapInteraction.explicitMapRegion?.center ?? mapInteraction.lastAppliedCourseRegion?.center else { return }
        
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
        
        // Sync to backend
        raceEngine.overrideMarks(marks: raceState.course.marks)
        
        // Center the map
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        mapInteraction.explicitMapRegion = region
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
