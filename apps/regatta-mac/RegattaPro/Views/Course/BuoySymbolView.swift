import SwiftUI

struct BuoySymbolView: View {
    let buoyId: String
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var buoy: Buoy? {
        raceState.course.marks.first(where: { $0.id == buoyId })
    }
    
    var isSelected: Bool {
        mapInteraction.selectedBuoyId == buoyId
    }
    
    var body: some View {
        Group {
            if let buoy = buoy {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(RegattaDesign.Colors.cyan, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .blur(radius: 2)
                    }
                    
                    if buoy.type == .mark || buoy.type == .gate {
                        if let rounding = buoy.rounding {
                            RoundingIndicator(direction: rounding)
                        }
                    }
                    
                    VStack(spacing: 2) {
                        // The actual 3D-ish Buoy representation
                        ZStack {
                            switch buoy.design ?? "Cylindrical" {
                            case "Spherical":
                                SphericalBuoyShape(color: buoyColor(for: buoy))
                            case "Spar":
                                SparBuoyShape(color: buoyColor(for: buoy))
                            case "MarkSetBot":
                                MarkSetBotShape(color: buoyColor(for: buoy))
                            case "CommitteeBoat":
                                CommitteeBoatShape(color: buoyColor(for: buoy))
                            default:
                                CylindricalBuoyShape(color: buoyColor(for: buoy))
                            }
                        }
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        
                        // Label
                        if let name = buoy.name.isEmpty ? nil : buoy.name {
                            Text(name)
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                }
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
        ZStack(alignment: .top) {
            // Pole
            Rectangle()
                .fill(.black)
                .frame(width: 2, height: 20)
            
            // Floating Base
            Capsule()
                .fill(color)
                .frame(width: 8, height: 12)
                .offset(y: 4)
            
            // Flag
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 8)
                .offset(x: 5)
        }
    }
}

struct MarkSetBotShape: View {
    let color: Color
    var body: some View {
        ZStack {
            // Twin Pontoons
            HStack(spacing: 8) {
                Capsule().fill(.black).frame(width: 4, height: 14)
                Capsule().fill(.black).frame(width: 4, height: 14)
            }
            
            // Top Cylinder (low taper)
                CylindricalBuoyShape(color: color)
                .scaleEffect(0.6)
                .offset(y: -2)
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
