import SwiftUI

// Temp enum until linked to Engine
enum ProtocolState {
    case standby
    case warning    // 5 minutes
    case prep       // 4 minutes
    case oneMinute  // 1 minute
    case racing     // GO
}

struct StartProcedureView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient

    var body: some View {
        VStack(spacing: 0) {
            // Main Top Display
            VStack {
                Text(phaseTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(4)
                
                Text(formatTime(raceState.timeRemaining))
                    .font(.system(size: 160, weight: .bold, design: .monospaced))
                    .foregroundStyle(phaseColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                
                // Active Flags Display
                HStack(spacing: 24) {
                    ForEach(raceState.activeFlags, id: \.self) { flag in
                        FlagView(name: flag, color: .orange)
                    }
                }
                .frame(height: 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Control Panel Bottom Strip
            HStack(spacing: 20) {
                // Sequence Initiators
                VStack(alignment: .leading) {
                    Text("STARTING SEQUENCES")
                        .font(.caption2).fontWeight(.black).foregroundStyle(.secondary)
                    HStack {
                        Button(action: startWarning) {
                            Text("5-Min Warning").fontWeight(.bold)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        
                        Button("3-Min Warning") {
                            // TODO
                        }
                        .controlSize(.large)
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
                
                // Disruptors
                VStack(alignment: .leading) {
                    Text("GLOBAL OVERRIDES")
                        .font(.caption2).fontWeight(.black).foregroundStyle(.secondary)
                    HStack {
                        Button(action: abandon) {
                            Label("Abandon (N)", systemImage: "xmark.octagon.fill")
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        
                        Button(action: generalRecall) {
                            Label("Gen Recall", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Start Procedure")
    }
    
    // --- Accessors & Logic Stub ---
    private var phaseTitle: String {
        switch raceState.currentPhase {
        case .idle: return "Standby"
        case .sequences: return "Sequences"
        case .racing: return "Racing"
        case .complete: return "Complete"
        }
    }
    
    private var phaseColor: Color {
        switch raceState.currentPhase {
        case .idle: return .gray
        case .sequences: return .yellow
        case .racing: return .green
        case .complete: return .blue
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let m = s / 60
        let rem = s % 60
        return String(format: "%d:%02d", m, rem)
    }
    
    // --- Actions ---
    private func startWarning() {
        // Send command through engine or an API client
        // raceEngine.webSocketTask?.send(String) ...
    }
    
    private func generalRecall() {
        // Send recall
    }
    
    private func abandon() {
        // Send abandon
    }
}

// Helper block for flags
struct FlagView: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack {
            Rectangle()
                .fill(color)
                .frame(width: 60, height: 40)
                .border(.primary, width: 2)
                .shadow(radius: 2)
            Text(name)
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}
