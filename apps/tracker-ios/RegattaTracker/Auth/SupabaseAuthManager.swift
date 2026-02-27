import Foundation
import Supabase
import Combine

let supabaseUrl = URL(string: "https://lagsagefmaqvxoceuhrt.supabase.co")!
let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhZ3NhZ2VmbWFxdnhvY2V1aHJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjgxMDAsImV4cCI6MjA4NzcwNDEwMH0.zvYXiHlOBa0UnsDl8Y0pAYgT0NmO6intzVlQJ58VLV8"

public let supabase = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey)

@MainActor
class SupabaseAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentSession: Session?
    @Published var currentUser: User?
    @Published var authError: String? = nil
    
    // Provide an accessor for the current valid JWT to send via WebSockets
    var currentJWT: String? {
        currentSession?.accessToken
    }

    init() {
        // Start listening to auth state changes from the Supabase SDK
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                self.handleAuthStateChange(event: event, session: session)
            }
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        self.currentSession = session
        self.currentUser = session?.user
        self.isAuthenticated = (session != nil)
    }

    func signIn(email: String, password: String) async -> Bool {
        do {
            let _ = try await supabase.auth.signIn(email: email, password: password)
            self.authError = nil
            return true
        } catch {
            self.authError = "Sign In Failed: \(error.localizedDescription)"
            return false
        }
    }

    func signUp(email: String, password: String) async -> Bool {
        do {
            let _ = try await supabase.auth.signUp(email: email, password: password)
            self.authError = nil
            return true
        } catch {
            self.authError = "Sign Up Failed: \(error.localizedDescription)"
            return false
        }
    }

    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        do {
            let _ = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            self.authError = nil
            return true
        } catch {
            self.authError = "Apple Sign In Failed: \(error.localizedDescription)"
            return false
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("SignOut Error: \(error.localizedDescription)")
        }
    }
}
