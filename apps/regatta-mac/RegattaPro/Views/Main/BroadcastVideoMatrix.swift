import SwiftUI

/// Central video multi-view matrix for the broadcast layout
struct BroadcastVideoMatrix: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    // Default quad split using grid
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        GeometryReader { geo in
            LazyVGrid(columns: columns, spacing: 2) {
                // In a real broadcast, this maps to the active cameras selected in the right pane.
                // For now, we take the top 4 real boats.
                ForEach(raceState.boats.sorted(by: { ($0.rank ?? 999) < ($1.rank ?? 999) }).prefix(4)) { boat in
                    BroadcastVideoFeedNode(boat: boat)
                        .frame(height: geo.size.height / 2) // Quads fit exactly to grid
                }
            }
        }
        .background(Color.black) // Gutters are black
    }
}

// Individual stylized video stream with premium lower third overlay
struct BroadcastVideoFeedNode: View {
    let boat: LiveBoat?
    var customLabel: String? = nil
    @State private var pulse: Bool = false
    
    private var isUnassigned: Bool {
        if let label = customLabel, (label == "JURY VIEW" || label == "REPLAY") {
            // Replay is usually active if it's there, but Jury can be inactive.
            // Following user request: "jurry view should have a not active state that matches the boat live view unactive views style"
            // For now, let's assume if it's Jury View we might toggle an 'active' flag. 
            // Simplified: If it's a special view without a specific boat, we can check if it's "Ready"
            return false // Default to active for these unless we add more state
        }
        return boat == nil || boat?.id == "EMPTY" || boat?.id == "X"
    }
    
    // Explicitly handle "NOT ACTIVE" state for Jury
    private var isJuryInactive: Bool {
        customLabel == "JURY VIEW" && (boat == nil) // Just an example logic: Jury view without boat context is inactive
    }
    
    private var rankString: String {
        if let label = customLabel { return label }
        guard let rank = boat?.rank else { return "X TH" }
        switch rank {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(rank)TH"
        }
    }
    
    var body: some View {
        ZStack {
            // Simulated Video Feed (Deep Dark Gradient with subtle scanning artifacts)
            Rectangle()
                .fill(
                    LinearGradient(colors: [
                        Color(white: 0.05),
                        Color(white: 0.1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            // "Camera Feed" Recording Icon Layer
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "video.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.1))
                        .padding(24)
                }
                Spacer()
            }
            
            // Premium Lower Third Identity Block
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    // Left Identity Tab: Team Name + Boat ID
                    HStack(spacing: 12) {
                        // Team Name
                        Text(isJuryInactive ? "NO ACTIVE JURY" : (customLabel ?? (boat?.teamName?.uppercased() ?? "UNKNOWN TEAM")))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(1)
                        
                        // Boat ID (Color Coded Background)
                        Text(isJuryInactive ? "X" : (boat?.id ?? (customLabel == "REPLAY" ? "RPLY" : "JURY")))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                (isUnassigned || isJuryInactive) 
                                ? AnyView(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing))
                                : AnyView(Color(regattaHex: boat?.color ?? (customLabel == "REPLAY" ? "#CC0000" : "#00CC00")))
                            )
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    
                    Spacer()
                    
                    // Right Position Tab: Rank
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(rankString)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.6), radius: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                    .background(isUnassigned ? Color.clear : Color.cyan.opacity(0.15))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.4)) // Liquid Glass Strip Backing
                
                // Color strip bottom anchor
                Rectangle()
                    .fill((isUnassigned || isJuryInactive) ? AnyShapeStyle(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(regattaHex: boat?.color ?? "#FFFFFF")))
                    .frame(height: 4)
            }
        }
        .clipped()
    }
}
