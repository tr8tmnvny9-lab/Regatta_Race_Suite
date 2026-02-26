import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
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
                    Text("Secure Login")
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
                            await authManager.signIn(email: email, password: password)
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
                            Text("AUTHENTICATE")
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
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
