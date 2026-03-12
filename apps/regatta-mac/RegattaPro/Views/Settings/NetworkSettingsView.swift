import SwiftUI

struct NetworkSettingsView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var sidecar: SidecarManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("NETWORK & CLOUD")
                    .font(RegattaDesign.Fonts.heading)
                    .italic()
                
                // Connection Status Panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("BACKEND BRIDGE")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(RegattaDesign.Colors.electricBlue)
                    
                    HStack(spacing: 20) {
                        StatusCard(
                            title: "Sidecar",
                            value: sidecarStatusText,
                            color: sidecarColor,
                            icon: "cpu"
                        )
                        
                        StatusCard(
                            title: "Socket.IO",
                            value: raceEngine.isConnected ? "CONNECTED" : "DISCONNECTED",
                            color: raceEngine.isConnected ? .green : .red,
                            icon: "bolt.fill"
                        )
                        
                        StatusCard(
                            title: "Latency",
                            value: "\(Int(connection.latencyMs))ms",
                            color: latencyColor,
                            icon: "waveform.path.ecg"
                        )
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                
                // Mode Selector
                VStack(alignment: .leading, spacing: 16) {
                    Text("COMMAND TARGET")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(RegattaDesign.Colors.cyan)
                    
                    Text("Current Mode: \(connection.modeLabel)")
                        .font(.title3)
                        .bold()
                    
                    Text("Regatta Pro automatically fails over to AWS Cloud if the local Nokia SNPN edge compute is unavailable (Invariant #3).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("LOCAL ENDPOINT")
                                .font(.caption2).bold()
                            Text("http://localhost:3001")
                                .font(RegattaDesign.Fonts.mono)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("CLOUD ENDPOINT")
                                .font(.caption2).bold()
                            Text("regatta-backend.fly.dev")
                                .font(RegattaDesign.Fonts.mono)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }
            .padding(32)
        }
    }
    
    private var sidecarStatusText: String {
        switch sidecar.status {
        case .idle: return "IDLE"
        case .starting: return "STARTING"
        case .ready: return "READY"
        case .failed(let error): return "FAILED: \(error)"
        }
    }
    
    private var sidecarColor: Color {
        switch sidecar.status {
        case .ready: return .green
        case .failed: return .red
        default: return .orange
        }
    }
    
    private var latencyColor: Color {
        if connection.latencyMs < 50 { return .green }
        if connection.latencyMs < 150 { return .yellow }
        return .red
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(RegattaDesign.Fonts.telemetry)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}
