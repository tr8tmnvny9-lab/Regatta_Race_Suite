import SwiftUI

struct ConnectivityStatusView: View {
    @EnvironmentObject var connection: ConnectionManager
    
    var body: some View {
        HStack(spacing: 12) {
            ConnectivityPill(label: "SAT", icon: "orbit", status: .healthy)
            ConnectivityPill(label: "5G", icon: "antenna.radiowaves.left.and.right", status: .healthy)
            ConnectivityPill(label: "MESH", icon: "mesh", status: .warning)
            
            Divider().frame(height: 14).opacity(0.2)
            
            Text(String(format: "%.0f ms", connection.latencyMs))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

enum LinkStatus {
    case healthy, warning, critical
}

struct ConnectivityPill: View {
    let label: String
    let icon: String
    let status: LinkStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .black))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}
