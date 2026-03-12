import SwiftUI

struct RegattaLiveLeaderboardModule: View {
    @EnvironmentObject var raceState: RaceStateModel
    var size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LIVE RACE")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(2)
                Spacer()
                Image(systemName: "cellularbars")
                    .foregroundStyle(RegattaDesign.Colors.cyan)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            
            // Content List
            ScrollView {
                // High frequency spring animations explicitly tied to rank sorting
                LazyVStack(spacing: 6) {
                    let sortedBoats = raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) })
                    ForEach(sortedBoats) { boat in
                        PremiumLeaderboardRow(boat: boat)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                // Implicit animation applies to the collection layout
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: raceState.boats.map { $0.id })
            }
        }
        .background(RegattaDesign.Colors.darkNavy.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.1), radius: 20, y: 10)
    }
}

// ─── Individual Premium Rows ────────────────────────────────────────────────

struct PremiumLeaderboardRow: View {
    let boat: LiveBoat
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(boat.rank ?? 99)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle((boat.rank ?? 99) <= 3 ? RegattaDesign.Colors.amber : .white)
                .frame(width: 30, alignment: .leading)
                .shadow(color: (boat.rank ?? 99) <= 3 ? RegattaDesign.Colors.amber.opacity(0.5) : .clear, radius: 4)
            
            // Color Line
            Rectangle()
                .fill(Color(regattaHex: boat.color ?? "#FFFFFF"))
                .frame(width: 4)
                .cornerRadius(2)
            
            // Team Name
            Text(boat.teamName ?? boat.id)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Speed
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", boat.speed))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)
                Text("KTS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.8))
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Alternating clear/subtle backing
        .background(Color.white.opacity((boat.rank ?? 99) % 2 == 0 ? 0 : 0.03))
        .cornerRadius(12)
    }
}
