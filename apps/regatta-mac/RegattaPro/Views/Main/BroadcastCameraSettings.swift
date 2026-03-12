import SwiftUI

/// A glassmorphic overlay for controlling camera-specific settings (ISO, Shutter, etc.)
struct BroadcastCameraSettings: View {
    let boatId: String
    @Binding var isPresented: Bool
    
    @State private var iso: Double = 400
    @State private var shutter: Double = 120
    @State private var exposure: Double = 0.0
    @State private var zoom: Double = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CAMERA SETTINGS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)
                    Text("BOAT: \(boatId)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            // Settings Sliders
            VStack(spacing: 24) {
                settingSlider(label: "ISO", value: $iso, range: 100...3200, unit: "")
                settingSlider(label: "SHUTTER", value: $shutter, range: 30...1000, unit: "¹/s")
                settingSlider(label: "EXPOSURE", value: $exposure, range: -3...3, unit: "ev")
                settingSlider(label: "ZOOM", value: $zoom, range: 1...10, unit: "x")
            }
            
            Spacer()
            
            // Footer Action
            Button(action: { isPresented = false }) {
                Text("APPLY TO STREAM")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 300, height: 450)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.5), radius: 30)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private func settingSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            
            Slider(value: value, in: range)
                .accentColor(.cyan)
        }
    }
}
