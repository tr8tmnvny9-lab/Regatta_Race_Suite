import SwiftUI

struct SponsorSettingsView: View {
    @EnvironmentObject var mapInteraction: MapInteractionModel
    @Environment(\.dismiss) var dismiss
    
    // Mock list of uploaded logos
    @State private var logos: [SponsorLogo] = [
        SponsorLogo(id: "L1", name: "Main Sponsor", image: "star.fill", color: .yellow),
        SponsorLogo(id: "L2", name: "Technical Partner", image: "cpu", color: .cyan),
        SponsorLogo(id: "L3", name: "Official Supplier", image: "shippingbox.fill", color: .orange)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack {
                Text("SPONSOR LOGO MANAGEMENT")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Spacer()
                Button("DONE") { dismiss() }
                    .buttonStyle(.plain)
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.cyan)
            }
            
            Text("These logos will be displayed as a repeating pattern on the 3D Course Border wall.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(logos) { sponsor in
                        HStack {
                            Image(systemName: sponsor.image)
                                .font(.title)
                                .foregroundStyle(sponsor.color)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text(sponsor.name.uppercased())
                                    .font(RegattaDesign.Fonts.label)
                                Text("Uploaded: 2026-03-13")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { /* Delete */ }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // Add Button
                    Button(action: { /* Add */ }) {
                        Label("UPLOAD NEW LOGO", systemImage: "plus.circle.fill")
                            .font(RegattaDesign.Fonts.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5])))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding(40)
        .frame(width: 600, height: 800)
        .background(.ultraThinMaterial)
    }
}

struct SponsorLogo: Identifiable {
    let id: String
    let name: String
    let image: String
    let color: Color
}
