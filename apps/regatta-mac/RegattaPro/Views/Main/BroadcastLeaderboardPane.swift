import SwiftUI

/// Left-edge pane displaying the high-density SailGP-style Live Leaderboard
struct BroadcastLeaderboardPane: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Tab
            HStack {
                Text("LIVE RANKINGS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.3))
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    let sortedBoats = raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) })
                    ForEach(sortedBoats) { boat in
                        BroadcastLeaderboardRow(boat: boat)
                    }
                }
                .padding(.top, 4)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: raceState.boats.map { $0.id })
            }
        }
        .background(.clear)
    }
}

// Compact, high-contrast row design
struct BroadcastLeaderboardRow: View {
    let boat: LiveBoat
    
    var body: some View {
        HStack(spacing: 0) {
            // Rank Number Block
            Text("\(boat.rank ?? 99)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle((boat.rank ?? 99) <= 3 ? .black : .white)
                .frame(width: 36, height: 36)
                .background((boat.rank ?? 99) <= 3 ? Color.yellow : Color.white.opacity(0.1))
            
            // Thin Color Bar Identifier
            Rectangle()
                .fill(Color(regattaHex: boat.color ?? "#FFFFFF"))
                .frame(width: 4, height: 36)
            
            // Team Identity
            Text(boat.teamName ?? boat.id)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, 12)
            
            Spacer()
            
            // Compact telemetry pill
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", boat.speed))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.cyan)
                Text("kN")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 12)
        }
        .background(.white.opacity((boat.rank ?? 99) % 2 == 0 ? 0.05 : 0.0))
    }
}
