import SwiftUI
import AVFoundation

struct RegattaLiveVideoModule: View {
    @EnvironmentObject var raceState: RaceStateModel
    var size: CGSize
    
    // Simulating active camera streams
    @State private var activeCameras: [(String, String)] = [
        ("USA 11", "HELMET CAM"), 
        ("NZL 1", "STERN CAM"), 
        ("DRONE 1", "BIRDSEYE"), 
        ("JURY", "CHASE BOAT")
    ]
    
    private var columns: [GridItem] {
        if activeCameras.count <= 1 {
            return [GridItem(.flexible(), spacing: 16)]
        } else {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Container constraint using strictly relative vector sizing
            GeometryReader { gridGeo in
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(raceState.boats.enumerated()), id: \.element.id) { index, boat in
                        PremiumVideoCell(
                            teamName: boat.teamName?.uppercased() ?? boat.id, 
                            camType: "ONBOARD", 
                            speed: boat.speed, 
                            size: gridGeo.size, 
                            count: raceState.boats.count
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(RegattaDesign.Colors.darkNavy.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.1), radius: 20, y: 10)
    }
}

// Relative Video Container with Premium Lower Thirds
struct PremiumVideoCell: View {
    let teamName: String
    let camType: String
    let speed: Double
    let size: CGSize
    let count: Int
    
    private var cellHeight: CGFloat {
        if count <= 2 {
            return size.height // Take full height if only 1 row
        } else {
            return (size.height / 2) - 8 // Half height for 2 rows
        }
    }
    
    var body: some View {
        ZStack {
            // Black bounds (letterboxing if needed)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
            
            Image(systemName: "video.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 0.08)
                .foregroundStyle(.white.opacity(0.05))
            
            // Premium Lower Thirds
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Lower Left Title Block
                    HStack(spacing: 0) {
                        Text(teamName)
                            .font(.system(size: max(12, size.height * 0.045), weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                        
                        Text(camType)
                            .font(.system(size: max(10, size.height * 0.035), weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RegattaDesign.Colors.cyan)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                    
                    Spacer()
                    
                    // Lower Right - Glowing Speed Stat
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", speed))
                            .font(.system(size: max(18, size.height * 0.07), weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.8), radius: 5)
                        
                        Text("KTS")
                            .font(.system(size: max(10, size.height * 0.03), weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                }
                .padding(12)
            }
        }
        .frame(height: cellHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
