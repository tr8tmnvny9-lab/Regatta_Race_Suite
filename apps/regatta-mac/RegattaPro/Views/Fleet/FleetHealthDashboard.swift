import SwiftUI

struct FleetHealthDashboard: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("FLEET DIAGNOSTICS")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(RegattaDesign.Colors.electricBlue)
                Spacer()
                Text("\(raceState.boats.filter { !$0.isGhosted }.count) ACTIVE / \(raceState.boats.count) TOTAL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                    ForEach(raceState.boats) { boat in
                        DiagnosticCard(boat: boat)
                    }
                }
            }
        }
    }
}

struct DiagnosticCard: View {
    let boat: LiveBoat
    @EnvironmentObject var raceState: RaceStateModel
    @ObservedObject private var videoSys = LiveVideoSystem.shared
    
    // Derived Diagnostic States
    var hasGPS: Bool { boat.pos.lat != 0 && boat.pos.lon != 0 }
    var hasVideo: Bool { videoSys.frames[boat.id] != nil }
    var isGhosted: Bool { boat.isGhosted }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Hierarchy: Team > Boat > Tracker
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(boat.teamName?.uppercased() ?? "UNKNOWN TEAM")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text("BOAT: \(boat.id)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: boat.color ?? "#00FFFF"))
                        
                        Text("TRK: \(boat.id)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                // Ghost Indicator
                if isGhosted {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.yellow)
                }
            }
            
            Divider().opacity(0.1)
            
            // Diagnostic KPI Blocks
            HStack(spacing: 6) {
                StatusBox(label: "GPS", isActive: hasGPS, isGhosted: isGhosted)
                StatusBox(label: "VIDEO", isActive: hasVideo, isGhosted: isGhosted)
                StatusBox(label: "ORIENT", isActive: true, isGhosted: isGhosted) // Assumed if telemetry is sending
            }
        }
        .padding(12)
        .background(isGhosted ? Color.black.opacity(0.4) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isGhosted ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        .opacity(isGhosted ? 0.6 : 1.0)
    }
}

struct StatusBox: View {
    let label: String
    let isActive: Bool
    let isGhosted: Bool
    
    var statusColor: Color {
        if isGhosted { return .yellow } // Deadzone timeout warning
        return isActive ? .green : .red  // Explicit missing capability
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            
            Rectangle()
                .fill(statusColor)
                .frame(height: 4)
                .cornerRadius(2)
        }
        .padding(6)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}
