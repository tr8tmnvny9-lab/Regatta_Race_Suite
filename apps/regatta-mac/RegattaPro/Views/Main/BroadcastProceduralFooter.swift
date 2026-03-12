import SwiftUI

/// A horizontal procedural timeline chart for the broadcast footer.
struct BroadcastProceduralFooter: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    // Mock stages for the timeline
    private let stages = ["PREP", "WARNING", "5:00", "4:00", "3:00", "2:00", "1:00", "START", "LEG 1", "LEG 2", "FINISH"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Header Info
            HStack {
                Text(raceState.status.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
                
                Spacer()
                
                Text("COURSE: WINDWARD-LEEWARD (2 LAPS)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            
            // Timeline Rail
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(.white.opacity(0.1))
                    .frame(height: 4)
                
                // Progress Fill
                Capsule()
                    .fill(RegattaDesign.Gradients.primary)
                    .frame(width: progressWidth, height: 4)
                    .shadow(color: .cyan.opacity(0.5), radius: 4)
                
                // Stage Markers
                HStack(spacing: 0) {
                    ForEach(stages.indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(index <= currentStageIndex ? Color.cyan : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                            
                            Text(stages[index])
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(index <= currentStageIndex ? .white : .white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var currentStageIndex: Int {
        switch raceState.status {
        case .idle: return 0
        case .warning: return 1
        case .preparatory: return 2
        case .oneMinute: return 6
        case .racing: return 8
        case .finished: return 10
        default: return 0
        }
    }
    
    private var progressWidth: CGFloat {
        // Simulating a width factor
        return 400.0 // Adjusted based on geometry if needed
    }
}
