import SwiftUI

struct IdentitySettingsView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("IDENTITY & AUTH")
                .font(RegattaDesign.Fonts.heading)
                .italic()
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(RegattaDesign.Gradients.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUser?.email ?? "Guest User")
                            .font(.title2)
                            .bold()
                        Text("Authorized via Supabase Auth")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                
                Divider().opacity(0.1)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERMISSION LEVEL")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.secondary)
                    Text("Race Director / Principal Officer")
                        .font(.headline)
                        .foregroundStyle(RegattaDesign.Colors.electricBlue)
                }
                
                Spacer(minLength: 40)
                
                Button(action: {
                    Task { await authManager.signOut() }
                }) {
                    Label("Log Out", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red.opacity(0.7))
            }
            .padding(32)
            .background(Color.white.opacity(0.05))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 600)
    }
}

struct DeveloperSettingsView: View {
    @AppStorage("uwbEmulatorEnabled") private var uwbEmulatorEnabled = false
    @AppStorage("showDebugMenu") private var showDebugMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("DEVELOPER TOOLS")
                .font(RegattaDesign.Fonts.heading)
                .italic()
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 24) {
                Toggle("Enable UWB Emulator", isOn: $uwbEmulatorEnabled)
                    .toggleStyle(.checkbox)
                    .font(.title3)
                
                Text("When enabled, the app ignores raw BLE data and instead evaluates distance-to-line by interpolating 1Hz iPhone GPS points into a 20Hz spline (Euclidean approximation).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider().opacity(0.1)
                
                Button("Hide Developer Menu") {
                    showDebugMenu = false
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 600)
    }
}
