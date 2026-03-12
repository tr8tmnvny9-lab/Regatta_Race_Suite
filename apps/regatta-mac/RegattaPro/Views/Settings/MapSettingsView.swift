import SwiftUI
import MapKit

struct MapSettingsView: View {
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    @State private var latString: String = ""
    @State private var lonString: String = ""
    @State private var latDeltaString: String = ""
    @State private var lonDeltaString: String = ""
    
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
