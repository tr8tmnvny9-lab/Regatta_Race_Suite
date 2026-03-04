import SwiftUI

struct PerformanceOverlayView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    var boat: LiveBoat? {
        raceState.boats.first { $0.id == mapInteraction.selectedBoatId }
    }
    
    var body: some View {
        if let boat = boat {
            VStack(alignment: .leading, spacing: 16) {
                // Header: Boat Identity
                HStack {
                    Image(systemName: "sailboat.fill")
                        .foregroundStyle(RegattaDesign.Colors.electricBlue)
                    Text(boat.id)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Spacer()
                    Button(action: { mapInteraction.selectedBoatId = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider().opacity(0.1)
                
                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    MetricItem(label: "VMG", value: String(format: "%.1f", calculateVMG(boat: boat)), unit: "KTS", color: RegattaDesign.Colors.cyan)
                    MetricItem(label: "POLAR %", value: String(format: "%.0f", calculatePolarEfficiency(boat: boat)), unit: "%", color: .green)
                    MetricItem(label: "HEADING", value: String(format: "%.0f", boat.heading), unit: "°", color: .white)
                    MetricItem(label: "SPEED", value: String(format: "%.1f", boat.speed), unit: "KTS", color: .white)
                }
                
                // Polar Chart Placeholder
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                    
                    // Simple Polar Needle
                    Rectangle()
                        .fill(RegattaDesign.Colors.electricBlue)
                        .frame(width: 2, height: 40)
                        .offset(y: -20)
                        .rotationEffect(.degrees(boat.heading - raceState.twd))
                }
                .frame(height: 100)
                .padding(.top, 10)
            }
            .padding(20)
            .frame(width: 260)
            .glassPanel()
        }
    }
    
    // ─── Calculations ────────────────────────────────────────────────────────
    
    private func calculateVMG(boat: LiveBoat) -> Double {
        let diff = (boat.heading - raceState.twd) * .pi / 180
        return boat.speed * cos(diff)
    }
    
    private func calculatePolarEfficiency(boat: LiveBoat) -> Double {
        // Mock logic: 10kts is 100% for this example
        let targetSpeed = 10.0
        return min(120, (boat.speed / targetSpeed) * 100)
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 3)
            }
        }
    }
}
