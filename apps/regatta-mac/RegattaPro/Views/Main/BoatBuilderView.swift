import SwiftUI

struct BoatBuilderView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    
    @State private var selectedProfileId: String? = nil
    @State private var editingProfile: BoatProfile = .defaultProfile
    
    @AppStorage("showDebugMenu") private var showDebugMenu = false
    @State private var devTapCount = 0
    
    var body: some View {
        HStack(spacing: 0) {
            
            // Left Column: List of Profiles
            VStack {
                Text("FLEET PROFILES")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        devTapCount += 1
                        if devTapCount >= 7 {
                            showDebugMenu = true
                        }
                    }
                
                List(selection: $selectedProfileId) {
                    ForEach(raceState.boatProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .listStyle(.sidebar)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: createNewProfile) {
                    Label("Add Profile", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(RegattaDesign.Colors.electricBlue)
                .padding(.top, 12)
            }
            .padding(20)
            .frame(width: 250)
            .background(Color.black.opacity(0.2))
            
            Divider().opacity(0.1)
            
            // Right Column: Editor
            ZStack {
                if selectedProfileId != nil {
                    editorForm
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "sailboat.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("Select a profile to edit.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedProfileId) { id in
            if let profile = raceState.boatProfiles.first(where: { $0.id == id }) {
                editingProfile = profile
            }
        }
    }
    
    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Basics
                VStack(alignment: .leading, spacing: 12) {
                    Text("IDENTIFICATION")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(RegattaDesign.Colors.cyan)
                    
                    TextField("Profile Name", text: $editingProfile.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .onSubmit {
                            saveChanges()
                        }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Hull Dimensions
                VStack(alignment: .leading, spacing: 12) {
                    Text("HULL DIMENSIONS (METERS)")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(RegattaDesign.Colors.cyan)
                    
                    HStack(spacing: 20) {
                        numberField(title: "Length (Include Pole)", value: $editingProfile.maxLengthPole)
                        numberField(title: "Length (Hull Only)", value: $editingProfile.maxLengthHull)
                        numberField(title: "Max Deck Width", value: $editingProfile.maxWidthDeck)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Tracker Mount
                VStack(alignment: .leading, spacing: 12) {
                    Text("UWB TRACKER MOUNT METRICS")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(RegattaDesign.Colors.cyan)
                    
                    Text("Relative to Bow Tip. X=Aft, Y=Stbd, Z=Up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        numberField(title: "Offset X", value: $editingProfile.mount.offsetX)
                        numberField(title: "Offset Y", value: $editingProfile.mount.offsetY)
                        numberField(title: "Offset Z", value: $editingProfile.mount.offsetZ)
                    }
                    
                    HStack(spacing: 20) {
                        numberField(title: "Azimuth Angle", value: $editingProfile.mount.mountingAzimuth)
                        numberField(title: "Elevation Angle", value: $editingProfile.mount.mountingElevation)
                    }
                }
                
                Spacer(minLength: 40)
                
                Button(action: saveChanges) {
                    Text("Push Profile to Fleet")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(RegattaDesign.Colors.electricBlue)
            }
            .padding(32)
        }
    }
    
    private func numberField(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private func createNewProfile() {
        let newProfile = BoatProfile(
            id: UUID().uuidString,
            name: "New Profile",
            maxLengthPole: 10.0,
            maxLengthHull: 10.0,
            maxWidthDeck: 3.0,
            mount: .defaultMount
        )
        raceState.boatProfiles.append(newProfile)
        selectedProfileId = newProfile.id
        editingProfile = newProfile
    }
    
    private func saveChanges() {
        if let id = selectedProfileId, let index = raceState.boatProfiles.firstIndex(where: { $0.id == id }) {
            raceState.boatProfiles[index] = editingProfile
            sendProfileUpdate(profile: editingProfile)
        }
    }
    
    private func sendProfileUpdate(profile: BoatProfile) {
        guard let data = try? JSONEncoder().encode(profile),
              let json = try? JSONSerialization.jsonObject(with: data) else { return }
        
        raceEngine.sendEvent("set-boat-profile", data: json)
    }
}
