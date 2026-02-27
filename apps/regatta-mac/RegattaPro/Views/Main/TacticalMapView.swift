import SwiftUI
import MapKit

struct TacticalMapView: View {
    @EnvironmentObject var connection: ConnectionManager
    // TODO: Inject RaceStateModel to pull live boats and geometry
    
    // We'll use a local position matching the typical regatta location for now
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        ZStack {
            Map(position: $position) {
                // Here we will use MapAnnotation for each boat
                // MapPolyline for ghost predictions
                // MapPolygon for the course boundary
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControlVisibility(.visible)
            
            // Floating UI Overlay
            VStack {
                HStack {
                    Spacer()
                    WindWidget()
                        .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("Overview")
    }
}

// ─── Wind Info Overlay ───────────────────────────────────────────────────────

struct WindWidget: View {
    // Dummy values until connected to RaceState
    let tws = 14.5
    let twd = 210.0
    
    var body: some View {
        VStack(spacing: 4) {
            Text("TRUE WIND")
                .font(.caption2)
                .fontWeight(.black)
                .tracking(1)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: "location.north.line.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .rotationEffect(.degrees(twd))
                    .animation(.spring(), value: twd)
                
                VStack(alignment: .leading, spacing: -2) {
                    Text(String(format: "%.1f", tws))
                        .font(.custom("Menlo", size: 24))
                        .fontWeight(.heavy)
                    Text("KTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
