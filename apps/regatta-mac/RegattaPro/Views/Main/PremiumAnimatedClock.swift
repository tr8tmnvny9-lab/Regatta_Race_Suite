import SwiftUI

/// Premium animated clock featuring a sweeping circular dial and monospaced digital readout.
struct PremiumAnimatedClock: View {
    let mode: ClockMode
    let timeString: String
    
    // Derived from the 60fps timer in MockEngine for continuous sweep
    let seconds: Double
    
    enum ClockMode {
        case master
        case countdown
        case racing
    }
    
    var color: Color {
        switch mode {
        case .master: return .gray
        case .countdown: return .orange
        case .racing: return .cyan
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Sweeping Dial
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                
                Circle()
                    .trim(from: 0, to: CGFloat(seconds.truncatingRemainder(dividingBy: 60) / 60.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // Subtle glow
                    .shadow(color: color.opacity(0.8), radius: 4)
            }
            .frame(width: 20, height: 20)
            
            // Digital Readout
            Text(timeString)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}
