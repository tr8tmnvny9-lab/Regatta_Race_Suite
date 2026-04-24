import SwiftUI
import MapKit

struct MapSettingsView: View {
    @EnvironmentObject var mapInteraction: MapInteractionModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    
    @State private var latString: String = ""
    @State private var lonString: String = ""
    @State private var latDeltaString: String = ""
    @State private var lonDeltaString: String = ""
    
    @State private var showingSponsorSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("MAP & NAVIGATION")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .italic()
            
            GlassPanel(title: "Home Water Configuration", icon: "house.fill") {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Specify your primary sailing location. The map will default to this area when starting a new session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LATITUDE")
                                .font(RegattaDesign.Fonts.label)
                            TextField("60.1699", text: $latString)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LONGITUDE")
                                .font(RegattaDesign.Fonts.label)
                            TextField("24.9384", text: $lonString)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LAT DELTA (ZOOM)")
                                .font(RegattaDesign.Fonts.label)
                            TextField("0.1", text: $latDeltaString)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LON DELTA (ZOOM)")
                                .font(RegattaDesign.Fonts.label)
                            TextField("0.2", text: $lonDeltaString)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack {
                        Button(action: saveHomeWater) {
                            Text("SAVE HOME WATER")
                                .font(RegattaDesign.Fonts.label)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(RegattaDesign.Gradients.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: useCurrentView) {
                            Label("USE CURRENT VIEW", systemImage: "scope")
                                .font(RegattaDesign.Fonts.label)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 600)
            
            GlassPanel(title: "Tactical Overlays", icon: "square.stack.3d.up.fill") {
                VStack(alignment: .leading, spacing: 20) {
                    // Mark Zones
                    Toggle(isOn: $mapInteraction.showMarkZones) {
                        VStack(alignment: .leading) {
                            Text("MARK ZONES")
                                .font(RegattaDesign.Fonts.label)
                            Text("Displays 2x or 3x boat length circles around all marks for RRS determination.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: mapInteraction.showMarkZones) { _ in mapInteraction.syncSettings(to: raceEngine) }
                    .toggleStyle(RegattaDesign.ToggleStyles.glass)
                    
                    if mapInteraction.showMarkZones {
                        HStack {
                            Text("ZONE MULTIPLIER")
                                .font(RegattaDesign.Fonts.label)
                            Spacer()
                            Picker("", selection: $mapInteraction.markZoneMultiplier) {
                                Text("2x").tag(2.0)
                                Text("3x").tag(3.0)
                            }
                            .onChange(of: mapInteraction.markZoneMultiplier) { _ in mapInteraction.syncSettings(to: raceEngine) }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                        .padding(.leading, 32)
                    }
                    
                    Divider().opacity(0.1)
                    
                    // Height to Mark
                    Toggle(isOn: $mapInteraction.showHeightToMark) {
                        VStack(alignment: .leading) {
                            Text("HEIGHT TO MARK")
                                .font(RegattaDesign.Fonts.label)
                            Text("Horizontal lines perpendicular to the wind to judge relative positioning.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(RegattaDesign.ToggleStyles.glass)
                }
            }
            .frame(maxWidth: 600)
            
            GlassPanel(title: "3D Visualization", icon: "square.3.layers.3d.down.right") {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle(isOn: $mapInteraction.show3DWall) {
                        VStack(alignment: .leading) {
                            Text("3D SPONSOR WALL")
                                .font(RegattaDesign.Fonts.label)
                            Text("Render a translucent curtain along the course boundary.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: mapInteraction.show3DWall) { _ in mapInteraction.syncSettings(to: raceEngine) }
                    .toggleStyle(RegattaDesign.ToggleStyles.glass)
                    
                    if mapInteraction.show3DWall {
                        Toggle(isOn: $mapInteraction.show3DLogos) {
                            Text("SHOW SPONSOR LOGOS")
                                .font(RegattaDesign.Fonts.label)
                        }
                        .onChange(of: mapInteraction.show3DLogos) { _ in mapInteraction.syncSettings(to: raceEngine) }
                        .toggleStyle(RegattaDesign.ToggleStyles.glass)
                        .padding(.leading, 32)
                        
                        Button(action: { showingSponsorSettings = true }) {
                            Label("MANAGE SPONSOR LOGOS", systemImage: "photo.on.rectangle.angled")
                                .font(RegattaDesign.Fonts.label)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 32)
                    }
                    
                    Divider().opacity(0.1)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("3D MAP SENSITIVITY")
                                .font(RegattaDesign.Fonts.label)
                            Spacer()
                            Text(String(format: "%.1fx", mapInteraction.mapSensitivity))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(RegattaDesign.Colors.electricBlue)
                        }
                        
                        Slider(value: $mapInteraction.mapSensitivity, in: 0.1...2.0, step: 0.1)
                            .accentColor(RegattaDesign.Colors.electricBlue)
                        
                        Text("Adjust mouse and trackpad panning/zoom speed for the 3D map.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 600)
            .sheet(isPresented: $showingSponsorSettings) {
                SponsorSettingsView()
                    .environmentObject(mapInteraction)
            }
            
            Spacer()
        }
        .padding(40)
        .onAppear(perform: loadCurrentSettings)
    }
    
    private func loadCurrentSettings() {
        let region = mapInteraction.homeWaterRegion
        latString = String(format: "%.6f", region.center.latitude)
        lonString = String(format: "%.6f", region.center.longitude)
        latDeltaString = String(format: "%.4f", region.span.latitudeDelta)
        lonDeltaString = String(format: "%.4f", region.span.longitudeDelta)
    }
    
    private func saveHomeWater() {
        guard let lat = Double(latString),
              let lon = Double(lonString),
              let latD = Double(latDeltaString),
              let lonD = Double(lonDeltaString) else { return }
        
        let newRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: latD, longitudeDelta: lonD)
        )
        
        mapInteraction.homeWaterRegion = newRegion
        // Also reset current view to this if it's the first time
        mapInteraction.explicitMapRegion = newRegion
    }
    
    private func useCurrentView() {
        if let current = mapInteraction.lastAppliedCourseRegion {
            mapInteraction.homeWaterRegion = current
            loadCurrentSettings()
        }
    }
}
