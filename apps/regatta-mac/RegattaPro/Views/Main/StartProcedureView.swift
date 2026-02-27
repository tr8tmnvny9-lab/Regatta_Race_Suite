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
    @State private var currentState: ProtocolState = .standby
    @State private var timeRemaining: TimeInterval = 0
    @State private var activeFlags: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Main Top Display
            VStack {
                Text(phaseTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(4)
                
                Text(formatTime(timeRemaining))
                    .font(.system(size: 160, weight: .bold, design: .monospaced))
                    .foregroundStyle(phaseColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                
                // Active Flags Display
                HStack(spacing: 24) {
                    if currentState != .standby {
                        FlagView(name: "Class Flag", color: .yellow)
                    }
                    if currentState == .prep || currentState == .oneMinute {
                        FlagView(name: "P Flag", color: .blue)
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
        switch currentState {
        case .standby: return "Standby"
        case .warning: return "Warning"
        case .prep: return "Preparatory"
        case .oneMinute: return "One Minute"
        case .racing: return "Racing"
        }
    }
    
    private var phaseColor: Color {
        switch currentState {
        case .standby: return .gray
        case .warning: return .primary
        case .prep: return .yellow
        case .oneMinute: return .orange
        case .racing: return .green
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
        currentState = .warning
        timeRemaining = 300
    }
    
    private func generalRecall() {
        currentState = .standby
        timeRemaining = 0
    }
    
    private func abandon() {
        currentState = .standby
        timeRemaining = 0
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
