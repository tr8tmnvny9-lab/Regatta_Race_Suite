import SwiftUI

struct BoatSymbolView: View {
    let role: LiveBoat.BoatRole
    let heading: Double // Degrees
    let twd: Double     // True Wind Direction in degrees
    let color: Color
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(RegattaDesign.Colors.cyan, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .blur(radius: 2)
            }
            
            switch role {
            case .sailboat:
                SailboatView(heading: heading, twd: twd, color: color)
            case .jury, .help, .media, .safety:
                RIBView(heading: heading, color: color, role: role)
            }
        }
        .rotationEffect(.degrees(heading))
    }
}

// ─── Sailboat Shape ──────────────────────────────────────────────────────────

struct SailboatView: View {
    let heading: Double
    let twd: Double
    let color: Color
    
    // Calculate sail angle based on wind
    // Sail should be on the downwind side
    private var sailAngle: Double {
        let relativeWind = (twd - heading).truncatingRemainder(dividingBy: 360)
        // Simple logic: if wind is from port, sail is on starboard (and vice versa)
        // If relativeWind is 0..180 (wind from starboard), sail is on port (-30 deg)
        // If relativeWind is 180..360 (wind from port), sail is on starboard (+30 deg)
        let normalizedWind = relativeWind < 0 ? relativeWind + 360 : relativeWind
        return (normalizedWind < 180) ? -25 : 25
    }
    
    var body: some View {
        ZStack {
            // Hull
            SleekHullShape()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 14, height: 32)
            
            // Mast
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .offset(y: -4)
            
            // Sail (Main)
            SailShape()
                .fill(.white.opacity(0.8))
                .frame(width: 2, height: 20)
                .rotationEffect(.degrees(sailAngle), anchor: .top)
                .offset(y: -4)
        }
    }
}

struct SleekHullShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // Bow
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY + 4),
                      control1: CGPoint(x: rect.maxX, y: rect.minY + 4),
                      control2: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY)) // Starboard Stern
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY)) // Port Stern
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 4))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.minX, y: rect.midY),
                      control2: CGPoint(x: rect.minX, y: rect.minY + 4))
        return path
    }
}

struct SailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// ─── RIB Shape ───────────────────────────────────────────────────────────────

struct RIBView: View {
    let heading: Double
    let color: Color
    let role: LiveBoat.BoatRole
    
    var body: some View {
        ZStack {
            // Tubes (The "RIB" part)
            RIBTubeShape()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 16, height: 30)
            
            // Center Console / Deck
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 18)
            
            // Engine
            Rectangle()
                .fill(.black)
                .frame(width: 6, height: 4)
                .offset(y: 14)
            
            // Icon identifier
            Image(systemName: roleIcon)
                .font(.system(size: 6))
                .foregroundStyle(.white)
        }
    }
    
    private var roleIcon: String {
        switch role {
        case .jury: return "scalemessage.fill"
        case .help: return "questionmark.circle.fill"
        case .media: return "camera.fill"
        case .safety: return "lifepreserver.fill"
        default: return "info.circle.fill"
        }
    }
}

struct RIBTubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w, y: 0), control2: CGPoint(x: w, y: h * 0.15))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.3))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: 0, y: h * 0.15), control2: CGPoint(x: 0, y: 0))
        
        return path
    }
}
