import SwiftUI

/// Top horizontal bar wrapping global settings, master clock, and exit controls.
struct BroadcastTopBar: View {
    @EnvironmentObject var raceState: RaceStateModel
    @Binding var isPresented: Bool
    
    private var formattedTime: String {
        let t = max(0, Int(raceState.timeRemaining))
        let m = t / 60
        let s = t % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // Time since 1970 for world clock effect
    private var worldTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: EXIT (Clear access)
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 16))
                    Text("EXIT")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.red.opacity(0.15))
                .foregroundStyle(.red)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            
            Spacer()
            
            // Center: Branding & Logos
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "sailboat.fill")
                        .foregroundStyle(.cyan)
                    Text("REGATTA PRO LIVE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(2)
                }
                
                Text("VALENCIA SERIES • SPONSORED BY ROLEX / SAILGP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
            
            // Right: Studio Controls
            HStack(spacing: 12) {
                // Procedure Phase Pill
                Text(raceState.status.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.cyan.opacity(0.2))
                    .foregroundStyle(.cyan)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                
                Button(action: {}) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
