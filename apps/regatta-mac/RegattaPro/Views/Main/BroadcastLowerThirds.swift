import SwiftUI

/// Bottom-edge graphical ticker and sponsor bar
struct BroadcastLowerThirds: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    // Simulate scrolling ticker text
    @State private var tickerOffset: CGFloat = 800
    
    private var tickerString: String {
        let leaderName = raceState.boats.first(where: { $0.rank == 1 })?.teamName ?? "LEADER"
        let tws = String(format: "%.1f", raceState.tws)
        let raceName = "REGATTA PRO SERIES"
        return "\(raceName) • \(leaderName.uppercased()) CURRENTLY IN 1ST PLACE • WINDSPEED AVERAGING \(tws) KTS ON COURSE • NO PENALTIES REPORTED"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: High contrast focus box (Speed of current leader)
            HStack(alignment: .firstTextBaseline) {
                if let leader = raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) }).first {
                    Text(String(format: "%.1f", leader.speed))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Color(regattaHex: leader.color ?? "#FFFFFF"))
                    Text("KTS")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 280, alignment: .center) // Match Left Edge pane width exactly
            .background(.black.opacity(0.4))
            
            // Middle: Animated Broadcast Ticker
            GeometryReader { geo in
                Text(tickerString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .textCase(.uppercase)
                    .tracking(2)
                    .lineLimit(1)
                    .frame(width: geo.size.width * 2, alignment: .leading)
                    .offset(x: tickerOffset)
                    .onAppear {
                        // Continuous scrolling effect
                        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                            tickerOffset = -geo.size.width * 1.5
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .background(.ultraThinMaterial)
            .clipped()
            
            // Right Control Footer Placeholder (Matches right edge pane)
            HStack {
                Text("AUTO-DIRECTOR")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.cyan)
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.cyan)
            }
            .frame(width: 280, alignment: .center) // Match Right Edge pane width exactly
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .background(.clear) // Transparent backing to allow floating
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
