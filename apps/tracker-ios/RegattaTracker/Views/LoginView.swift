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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
                
                VStack(spacing: 8) {
                    Text(isSignUp ? "Create Account" : "Secure Login")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("Regatta Tracker Access")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    if let error = authManager.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
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
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(16)
                        } else {
                            Text(isSignUp ? "CREATE ACCOUNT" : "AUTHENTICATE")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                    
                    Button(action: {
                        withAnimation {
                            isSignUp.toggle()
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.cyan)
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    
                    HStack {
                        VStack { Divider().background(Color.gray) }
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        VStack { Divider().background(Color.gray) }
                    }
                    .padding(.vertical, 8)
                    
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
                    .frame(height: 45)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
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
