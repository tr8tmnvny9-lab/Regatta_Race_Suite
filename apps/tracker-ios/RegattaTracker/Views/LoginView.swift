import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isSignUp = false
    @State private var currentNonce: String?
    
    var body: some View {
        ZStack {
            // Sailing / Ocean Themed Background
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.0, green: 0.2, blue: 0.4), Color.cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            // Decorative elements
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: -200, y: -200)
            
            Circle()
                .fill(Color.cyan.opacity(0.2))
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
                        
                        Text(isSignUp ? "Join the Fleet" : "RegattaTracker")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        Text("Live Telemetry Link")
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
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
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
                                        print("Error generating token pieces from Apple")
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
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    // --- Cryptography Helpers ---
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
