import SwiftUI

struct BroadcastFeedSelector: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // General Views
            VStack(alignment: .leading, spacing: 8) {
                Text("GENERAL VIEWS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                
                HStack(spacing: 8) {
                    FeedDragSource(type: "map", id: "map", label: "TACTICAL MAP", icon: "map.fill")
                    FeedDragSource(type: "3dmap", id: "3dmap", label: "3D LIVE VIEW", icon: "square.3.layers.3d")
                    FeedDragSource(type: "replay", id: "replay", label: "REPLAY", icon: "arrow.counterclockwise.circle.fill")
                    FeedDragSource(type: "jury", id: "jury", label: "JURY VIEW", icon: "gavel.fill")
                }
            }
            
            Divider().background(.white.opacity(0.1))
            
            // Boat Views
            VStack(alignment: .leading, spacing: 8) {
                Text("BOAT CAMERAS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(raceState.boats) { boat in
                            FeedDragSource(
                                type: "camera", 
                                id: boat.id, 
                                label: boat.teamName?.uppercased() ?? boat.id, 
                                icon: "video.fill",
                                color: Color(regattaHex: boat.color ?? "#555555")
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct FeedDragSource: View {
    let type: String
    let id: String
    let label: String
    let icon: String
    var color: Color = .cyan
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .draggable(BroadcastDragItem(contentType: type, id: id)) {
            // Drag Preview
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.8))
                    .frame(width: 60, height: 40)
                Text(label).font(.system(size: 8)).foregroundStyle(.white)
            }
        }
    }
}
