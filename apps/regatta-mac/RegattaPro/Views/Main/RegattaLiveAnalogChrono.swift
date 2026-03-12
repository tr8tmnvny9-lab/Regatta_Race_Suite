import SwiftUI

/// A premium 3D analog chronometer with liquid glass refraction and brushed metal aesthetics.
struct RegattaLiveAnalogChrono: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    // Derived angles for hands
    private var secondsAngle: Double {
        Double(raceState.timeRemaining).truncatingRemainder(dividingBy: 60) * 6
    }
    
    private var minutesAngle: Double {
        (Double(raceState.timeRemaining) / 60.0).truncatingRemainder(dividingBy: 60) * 6
    }
    
    var body: some View {
        ZStack {
            // 1. Outer Bezel (Brushed Gunmetal)
            Circle()
                .fill(
                    LinearGradient(gradient: Gradient(colors: [Color(white: 0.2), Color.black, Color(white: 0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 160, height: 160)
                .shadow(color: .cyan.opacity(0.2), radius: 15, x: 0, y: 5)
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
                )
            
            // 2. Inner Dial Plate (Deep Blue / Glass)
            Circle()
                .fill(
                    RadialGradient(gradient: Gradient(colors: [Color(red: 0.1, green: 0.2, blue: 0.4), Color(red: 0.02, green: 0.05, blue: 0.1)]), center: .center, startRadius: 0, endRadius: 80)
                )
                .frame(width: 144, height: 144)
            
            // 3. Tick Marks
            ForEach(0..<60) { tick in
                Rectangle()
                    .fill(tick % 5 == 0 ? Color.cyan : Color.white.opacity(0.2))
                    .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 12 : 5)
                    .offset(y: -65)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
            
            // 4. Branding / Mode Text
            VStack(spacing: 2) {
                Text("REGATTA")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
                Text("CHRONOMETER")
                    .font(.system(size: 6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.cyan.opacity(0.8))
            }
            .offset(y: -30)
            
            // 5. Digital Sub-dial (Secondary Time)
            Text(String(format: "%02d:%02d", Int(raceState.timeRemaining) / 60, Int(raceState.timeRemaining) % 60))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.4))
                .cornerRadius(4)
                .offset(y: 35)
                .shadow(color: .cyan.opacity(0.3), radius: 4)
            
            // 6. Hands
            // Minute Hand
            Capsule()
                .fill(.white)
                .frame(width: 4, height: 50)
                .offset(y: -25)
                .rotationEffect(.degrees(minutesAngle))
                .shadow(radius: 2)
            
            // Second Hand (Sweeping)
            ZStack {
                Capsule()
                    .fill(.orange)
                    .frame(width: 2, height: 65)
                    .offset(y: -25)
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
            .rotationEffect(.degrees(secondsAngle))
            .shadow(color: .orange.opacity(0.5), radius: 3)
            
            // 7. Refractive Glass Overlay
            Circle()
                .fill(
                    LinearGradient(gradient: Gradient(colors: [.white.opacity(0.2), .clear, .black.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 144, height: 144)
                .blendMode(.screen)
        }
        .frame(width: 160, height: 160)
    }
}
