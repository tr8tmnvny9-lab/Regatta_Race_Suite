import SwiftUI

struct JoinView: View {
    @EnvironmentObject var connection: TrackerConnectionManager
    @Binding var showSheet: Bool
    @State private var inputId: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: "sailboat.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
                
                VStack(spacing: 8) {
                    Text("Regatta Tracker")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("Join an active race session")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 20) {
                    TextField("Session ID (e.g. 1234)", text: $inputId)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        
                    Button(action: {
                        if !inputId.isEmpty {
                            connection.joinSession(id: inputId)
                            showSheet = false
                        }
                    }) {
                        Text("JOIN SESSION")
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(16)
                    }
                    .disabled(inputId.isEmpty)
                    .opacity(inputId.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
