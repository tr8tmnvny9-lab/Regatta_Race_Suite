import SwiftUI

struct BuoySymbolView: View {
    let buoyId: String
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var buoy: Buoy? {
        raceState.course.marks.first(where: { $0.id == buoyId })
    }
    
    var isSelected: Bool {
        mapInteraction.selectedBuoyIds.contains(buoyId) || mapInteraction.selectedBuoyId == buoyId
    }
    
    var body: some View {
        Group {
            if let buoy = buoy {
                ZStack(alignment: .center) {
                    // Frame: 40x40. Center point (20,20) is the geographic coordinate.
                    
                    // 1. Selection & Decoration
                    if isSelected {
                        Circle()
                            .stroke(RegattaDesign.Colors.cyan, lineWidth: 2)
                            .frame(width: 38, height: 38)
                            .blur(radius: 1)
                    }
                    
                    // 2. Rounding Indicator (anchored to center)
                    if buoy.type == .mark || buoy.type == .gate {
                        if let rounding = buoy.rounding {
                            RoundingIndicator(direction: rounding)
                        }
                    }
                    
                    // 3. The Mark Visuals
                    VStack(spacing: 0) {
                        // The buoy Shape (max height 24)
                        ZStack(alignment: .bottom) {
                            switch buoy.design ?? "Cylindrical" {
                            case "Spherical": SphericalBuoyShape(color: buoyColor(for: buoy))
                            case "Spar": SparBuoyShape(color: buoyColor(for: buoy))
                            case "MarkSetBot": MarkSetBotShape(color: buoyColor(for: buoy))
                            case "CommitteeBoat": CommitteeBoatShape(color: buoyColor(for: buoy))
                            default: CylindricalBuoyShape(color: buoyColor(for: buoy))
                            }
                            
                            // Label (Pushed above the buoy)
                            if let name = buoy.name.isEmpty ? nil : buoy.name {
                                Text(name)
                                    .font(.system(size: 8, weight: .black))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.black.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                                    .offset(y: -28) // Pushed above the 24px buoy
                            }
                        }
                        .frame(width: 30, height: 24)
                        
                        // This spacer ensures the "base" (bottom of the shape) is at height 20
                        Spacer().frame(height: 20)
                    }
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                }
                .frame(width: 40, height: 40)
            }
        }
    }
    
    private func buoyColor(for buoy: Buoy) -> Color {
        Color(name: buoy.color ?? "Yellow")
    }
}

// ─── Indicators ──────────────────────────────────────────────────────────────

struct RoundingIndicator: View {
    let direction: String // "Port" or "Starboard"
    
    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.4) // A 30% arc
            .stroke(
                direction == "Port" ? Color.red : Color.green,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4])
            )
            .frame(width: 38, height: 38)
            .rotationEffect(.degrees(direction == "Port" ? -90 : 90))
            // Add a small arrowhead
            .overlay(
                Image(systemName: "triangle.fill")
                    .resizable()
                    .frame(width: 6, height: 6)
                    .foregroundColor(direction == "Port" ? .red : .green)
                    .offset(y: -19)
                    .rotationEffect(.degrees(direction == "Port" ? -50 : 50))
            )
    }
}

// ─── Buoy Shapes ─────────────────────────────────────────────────────────────

struct CylindricalBuoyShape: View {
    let color: Color
    var body: some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(color.opacity(0.8))
                .frame(height: 6)
            Rectangle()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 14)
            Ellipse()
                .fill(color)
                .frame(height: 6)
        }
    }
}

struct SphericalBuoyShape: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.8), color], center: .topLeading, startRadius: 0, endRadius: 12))
            .frame(width: 18, height: 18)
    }
}

struct SparBuoyShape: View {
    let color: Color
    var body: some View {
        ZStack(alignment: .bottom) {
            // Pole
            Rectangle()
                .fill(.black)
                .frame(width: 2, height: 24)
            
            // Floating Base
            Capsule()
                .fill(color)
                .frame(width: 8, height: 12)
                .offset(y: -4)
            
            // Flag
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 8)
                .offset(x: 5, y: -16)
        }
    }
}

struct MarkSetBotShape: View {
    let color: Color
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Robotic Base (The "Bot" part)
            ZStack {
                // Main chassis
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.3))
                    .frame(width: 22, height: 6)
                
                // Pontoon details
                HStack(spacing: 12) {
                    Capsule().fill(Color(white: 0.2)).frame(width: 4, height: 8)
                    Capsule().fill(Color(white: 0.2)).frame(width: 4, height: 8)
                }
                .offset(y: 1)
                
                // GPS / Antenna Mast
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 1, height: 12)
                    .offset(x: 8, y: -6)
            }
            
            // 2. The Mark (The "Cylinder" part)
            VStack(spacing: 0) {
                // Top cap
                Ellipse()
                    .fill(color.opacity(0.8))
                    .frame(width: 14, height: 4)
                
                // Main body
                Rectangle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 12)
                
                // Connection taper
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 14, y: 0))
                    path.addLine(to: CGPoint(x: 18, y: 3))
                    path.addLine(to: CGPoint(x: -4, y: 3))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.25))
                .frame(width: 14, height: 3)
            }
            .offset(y: -5)
        }
    }
}

struct CommitteeBoatShape: View {
    let color: Color
    var body: some View {
        ZStack {
            // Hull
            Capsule()
                .fill(.white)
                .frame(width: 14, height: 28)
                .overlay(Capsule().stroke(color, lineWidth: 2))
            
            // Cockpit / Cabin
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.8))
                .frame(width: 10, height: 12)
                .offset(y: -2)
            
            // RC Flag
            Path { path in
                path.move(to: CGPoint(x: 14, y: 14))
                path.addLine(to: CGPoint(x: 24, y: 14))
                path.addLine(to: CGPoint(x: 24, y: 22))
                path.addLine(to: CGPoint(x: 14, y: 22))
                path.closeSubpath()
            }
            .fill(.yellow)
            
            Text("RC")
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(.black)
                .offset(x: 19, y: 4)
        }
    }
}
