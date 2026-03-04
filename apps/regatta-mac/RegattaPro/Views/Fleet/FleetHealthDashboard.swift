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
                Text("\(raceState.boats.count) TRACKERS ACTIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(raceState.boats) { boat in
                        HealthIndicatorCard(boat: boat)
                    }
                }
            }
        }
    }
}

struct HealthIndicatorCard: View {
    let boat: LiveBoat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Boat ID & Role
            HStack {
                Image(systemName: roleIcon)
                    .foregroundStyle(RegattaDesign.Colors.cyan)
                Text(boat.id)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            
            Divider().opacity(0.1)
            
            // Stats Grid
            VStack(spacing: 6) {
                HealthStatRow(label: "SIGNAL", value: "88%", icon: "antenna.radiowaves.left.and.right", color: .green)
                HealthStatRow(label: "BATTERY", value: "74%", icon: "battery.75", color: .green)
                HealthStatRow(label: "DELAY", value: "120ms", icon: "timer", color: .white)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(statusColor.opacity(0.2), lineWidth: 1))
    }
    
    private var roleIcon: String {
        switch boat.role {
        case .jury: return "scalemessage.fill"
        case .media: return "camera.fill"
        default: return "sailboat.fill"
        }
    }
    
    private var statusColor: Color {
        // Mock status logic
        .green
    }
}

struct HealthStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
