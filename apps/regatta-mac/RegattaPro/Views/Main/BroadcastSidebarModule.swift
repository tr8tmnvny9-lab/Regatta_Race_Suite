import SwiftUI

/// A reusable information module for the broadcast sidebars.
struct BroadcastSidebarModule<Content: View>: View {
    let title: String
    let icon: String?
    let content: () -> Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Module Header
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05))
            
            Divider().opacity(0.1)
            
            // Module Body
            content()
                .padding(12)
        }
        .background(.ultraThinMaterial.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

/// A specialized row for boat lists in the sidebars
struct SidebarBoatRow: View {
    let boat: LiveBoat
    let rank: Int?
    
    var body: some View {
        HStack(spacing: 12) {
            if let rank = rank {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .frame(width: 25)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(boat.teamName?.uppercased() ?? "UNKNOWN")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(boat.id)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            if let dtf = boat.dtf {
                Text("\(Int(dtf))m")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
    }
}
