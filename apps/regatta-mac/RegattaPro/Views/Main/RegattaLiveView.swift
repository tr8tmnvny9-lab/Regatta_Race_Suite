import SwiftUI
import AVKit

// Temporary structural mock until LiveKit Swift SDK is injected
struct VideoStreamNode: Identifiable {
    let id = UUID()
    let boatName: String
    let isLive: Bool
    let isSpotlighted: Bool
}

struct RegattaLiveView: View {
    @State private var activeStreams: [VideoStreamNode] = [
        VideoStreamNode(boatName: "USA 11 Camera A", isLive: true, isSpotlighted: true),
        VideoStreamNode(boatName: "NZL 1 Camera B", isLive: true, isSpotlighted: true),
        VideoStreamNode(boatName: "GBR 2 Helmet Cam", isLive: true, isSpotlighted: false),
        VideoStreamNode(boatName: "FRA 28 Stern", isLive: false, isSpotlighted: false)
    ]
    
    // Auto-Director toggle
    @State private var autoDirectorEnabled = true

    // Responsive Grid Definition
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading) {
                    Text("Regatta Live Media Center")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Powered by LiveKit WebRTC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                Toggle("Auto-Director (AI Switching)", isOn: $autoDirectorEnabled)
                    .toggleStyle(.switch)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Video Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(activeStreams) { stream in
                        LiveVideoCell(stream: stream)
                    }
                }
                .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .navigationTitle("Regatta Live")
    }
}

// Helper Cell
struct LiveVideoCell: View {
    let stream: VideoStreamNode
    
    var body: some View {
        ZStack {
            // Video Placeholder (would be `VideoView` from LiveKit SDK)
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: stream.isLive ? "play.slash.fill" : "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                )
            
            // Overlays
            VStack {
                HStack {
                    if stream.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.black)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(4)
                    }
                    Spacer()
                    if stream.isSpotlighted {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .shadow(radius: 2)
                    }
                }
                Spacer()
                
                HStack {
                    Text(stream.boatName)
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(4)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
                }
            }
            .padding(12)
            .foregroundStyle(.white)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stream.isSpotlighted ? Color.yellow : Color.clear, lineWidth: 3)
        )
        .shadow(radius: 5)
    }
}
