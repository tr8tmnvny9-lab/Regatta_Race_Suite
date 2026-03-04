import SwiftUI
import AuthenticationServices
import CryptoKit

struct WaveShape: Shape {
    var offset: Angle
    var percent: Double
    
    var animatableData: Double {
        get { offset.degrees }
        set { offset = Angle(degrees: newValue) }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lowAmplitude: CGFloat = 20
        let waveHeight: CGFloat = lowAmplitude
        let yOffset = CGFloat(1 - percent) * (rect.height - waveHeight)
        let startAngle = offset
        let endAngle = startAngle + Angle(degrees: 360)
        
        path.move(to: CGPoint(x: 0, y: yOffset + waveHeight * CGFloat(sin(startAngle.radians))))
        
        for x in stride(from: 0, to: rect.width + 5, by: 5) {
            let relativeX = x / rect.width
            let angle = startAngle.radians + (endAngle.radians - startAngle.radians) * Double(relativeX)
            let y = yOffset + waveHeight * CGFloat(sin(angle))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct AnimatedWaveBackground: View {
    @State private var waveOffset = Angle(degrees: 0)
    @State private var waveOffset2 = Angle(degrees: 0)
    @State private var glowOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background Gradient (Deep Ocean)
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.0, green: 0.05, blue: 0.15),
                Color(red: 0.0, green: 0.15, blue: 0.35),
                Color(red: 0.1, green: 0.4, blue: 0.7)
            ]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            // Depth Glows
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: glowOffset.width - 200, y: glowOffset.height - 200)
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: -glowOffset.width + 250, y: -glowOffset.height + 150)
            
            // Distant Waves (Slow & Faint)
            WaveShape(offset: waveOffset2, percent: 0.3)
                .fill(Color.white.opacity(0.03))
                .ignoresSafeArea()
                .offset(y: 20)
            
            WaveShape(offset: waveOffset2 + Angle(degrees: 120), percent: 0.28)
                .fill(Color.cyan.opacity(0.04))
                .ignoresSafeArea()
                .offset(y: 40)
            
            // Midground Waves
            WaveShape(offset: waveOffset, percent: 0.35)
                .fill(Color.white.opacity(0.08))
                .ignoresSafeArea()
                .offset(y: 60)
            
            WaveShape(offset: waveOffset + Angle(degrees: 180), percent: 0.32)
                .fill(Color.cyan.opacity(0.12))
                .ignoresSafeArea()
                .offset(y: 80)
            
            // Foreground Waves (Faster & Prominent)
            WaveShape(offset: waveOffset * 1.5 + Angle(degrees: 90), percent: 0.4)
                .fill(Color.white.opacity(0.05))
                .ignoresSafeArea()
                .offset(y: 100)
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                waveOffset = Angle(degrees: 360)
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                waveOffset2 = Angle(degrees: 360)
            }
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                glowOffset = CGSize(width: 100, height: 100)
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isSignUp = false
    @State private var currentNonce: String?
    
    var body: some View {
        ZStack {
            AnimatedWaveBackground()
            
            // Decorative elements... (rest of the circles)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: -200, y: -200)
            
            Circle()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 200, y: 200)
            
            VStack {
                Spacer()
                
                // Liquid Glass Card
                VStack(spacing: 30) {
                    // Logo Header
                    VStack(spacing: 12) {
                        Image(systemName: "sailboat.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .foregroundColor(.white)
                            .shadow(color: .cyan.opacity(0.8), radius: 10)
                        
                        Text(isSignUp ? "Join the Fleet" : "RegattaPro")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Elite Tactical Racing")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .padding(.bottom, 10)
                    
                    VStack(spacing: 16) {
                        // Custom Styled Inputs
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.7))
                            TextField("Email", text: $email)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .cornerRadius(12)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.7))
                            SecureField("Password", text: $password)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .cornerRadius(12)
                        
                        if let error = authManager.authError {
                            Text(error)
                                .foregroundColor(error.contains("check your email") ? .green : .red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            Task {
                                isLoading = true
                                if isSignUp {
                                    let success = await authManager.signUp(email: email, password: password)
                                    if success {
                                        authManager.authError = "Account created! Please check your email to verify your account."
                                    }
                                } else {
                                    let _ = await authManager.signIn(email: email, password: password)
                                }
                                isLoading = false
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(height: 50)
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Text(isSignUp ? "SET SAIL" : "EMBARK")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                        
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isSignUp.toggle()
                            }
                        }) {
                            Text(isSignUp ? "Already a captain? Dock here" : "New to the Yacht Club? Enlist")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        VStack { Divider().background(Color.white.opacity(0.3)) }
                        Text("OR")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        VStack { Divider().background(Color.white.opacity(0.3)) }
                    }
                    .padding(.vertical, 4)
                    
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                switch authResults.credential {
                                case let appleIDCredential as ASAuthorizationAppleIDCredential:
                                    guard let nonce = currentNonce,
                                          let appleIDToken = appleIDCredential.identityToken,
                                          let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                                        print("Error generating token pieces from Apple ASAuthorization")
                                        return
                                    }
                                    Task {
                                        isLoading = true
                                        let _ = await authManager.signInWithApple(idToken: idTokenString, nonce: nonce)
                                        isLoading = false
                                    }
                                default:
                                    break
                                }
                            case .failure(let error):
                                print("Apple Sign In error: \(error.localizedDescription)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                }
                .padding(40)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .frame(maxWidth: 400)
                
                Spacer()
            }
        }
    }
    
    // --- Cryptography Helpers for Apple Sign In Nonce ---
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce") }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
