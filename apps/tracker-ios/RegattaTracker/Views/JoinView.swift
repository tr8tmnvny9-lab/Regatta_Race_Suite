import SwiftUI

struct JoinView: View {
    @EnvironmentObject var connection: TrackerConnectionManager
    @Binding var showSheet: Bool
    @State private var inputId: String = ""
    
    var body: some View {
        ZStack {
            AnimatedWaveBackground()
            
            VStack(spacing: 40) {
                Image(systemName: "sailboat.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .foregroundColor(.white)
                    .shadow(color: .cyanAccent.opacity(0.8), radius: 10)
                
                VStack(spacing: 8) {
                    Text("Regatta Tracker")
                        .font(RegattaFont.heroRounded(32))
                        .foregroundColor(.white)
                    Text("Join an active race session")
                        .font(RegattaFont.bodyRounded(16))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                VStack(spacing: 24) {
                    TextField("Session ID", text: $inputId)
                        .font(RegattaFont.data(32))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .tracking(4)
                        .trueLiquidGlass(cornerRadius: 16)
                        
                    Button(action: {
                        if !inputId.isEmpty {
                            connection.joinSession(id: inputId)
                            showSheet = false
                        }
                    }) {
                        Text("JOIN SESSION")
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                    .disabled(inputId.isEmpty)
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
    }
}
