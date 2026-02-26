import SwiftUI

struct StartLineView: View {
    @EnvironmentObject var connection: TrackerConnectionManager
    @EnvironmentObject var bleClient: UWBNodeBLEClient
    @EnvironmentObject var race: RaceStateModel
    @EnvironmentObject var haptics: HapticManager
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            // Background red flash if OCS
            if let dtl = bleClient.dtlCm, dtl > 10.0 {
                Color.red.opacity(0.3).ignoresSafeArea()
                    .onAppear { haptics.playOCSHaptic() }
            }
            
            VStack {
                // Header Status Bar
                HStack {
                    StatusIndicator(title: "NODE", isConnected: bleClient.isConnected, color: .green)
                    Spacer()
                    StatusIndicator(title: "HUB", isConnected: connection.isConnected, color: .cyan)
                }
                .padding()
                
                Spacer()
                
                // DTL HUD (Distance To Line)
                VStack(spacing: 12) {
                    Text("DISTANCE TO LINE")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.gray)
                        .tracking(2)
                    
                    if let dtl = bleClient.dtlCm {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(dtl > 0 ? "+" : "")
                                .font(.system(size: 60, weight: .black, design: .monospaced))
                                .foregroundColor(dtl > 10 ? .red : .white)
                            Text(String(format: "%.1f", dtl))
                                .font(.system(size: 100, weight: .black, design: .monospaced))
                                .foregroundColor(dtl > 10 ? .red : .white)
                            Text("cm")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(dtl > 10 ? .red : .white)
                        }
                    } else {
                        Text("---")
                            .font(.system(size: 100, weight: .black, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Bottom Toolbar
                HStack {
                    VStack(alignment: .leading) {
                        Text("SESSION")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.gray)
                        Text(connection.sessionId ?? "None")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        connection.sessionId = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .padding()
            }
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let isConnected: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? color : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: isConnected ? color.opacity(0.8) : .red, radius: 4)
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(isConnected ? .white : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}
