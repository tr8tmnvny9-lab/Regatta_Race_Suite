import SwiftUI
import UniformTypeIdentifiers

/// An interactive slot in the Center Stage grid that accepts dragged camera or map items.
struct BroadcastSlotView: View {
    let slotIndex: Int
    @EnvironmentObject var stageModel: BroadcastStageModel
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    // Smooth transition tracking
    @State private var isTargeted = false
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Drop target styling
            Rectangle()
                .fill(Color(white: 0.05).opacity(isTargeted ? 0.8 : 0.4))
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            // Content Renderer
            slotContent
            
            // Settings Trigger (for cameras)
            if case .camera(let id) = stageModel.slots[slotIndex] {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showingSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .foregroundStyle(.cyan)
                                .shadow(radius: 5)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                    Spacer()
                }
                
                if showingSettings {
                    BroadcastCameraSettings(boatId: id, isPresented: $showingSettings)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                }
            }
            
            // D&D highlight border
            if isTargeted {
                Rectangle()
                    .stroke(Color.cyan, lineWidth: 4)
            }
        }
        .clipped()
        .dropDestination(for: BroadcastDragItem.self) { items, location in
            if let item = items.first {
                stageModel.dropItem(in: slotIndex, item: item)
                return true
            }
            return false
        }
    }
    
    @ViewBuilder
    private var slotContent: some View {
        switch stageModel.slots[slotIndex] {
        case .empty:
            VStack {
                Image(systemName: "plus.dashed")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.2))
                Text("DRAG FEED HERE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 8)
            }
        case .map:
            ZStack {
                BroadcastTacticalMap()
                
                // Floating Live Map HUD
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            // Status Indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(mapInteraction.isLiveMapAutoTracking ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(mapInteraction.isLiveMapAutoTracking ? "AUTO-TRACKING" : "MANUAL")
                                    .font(.system(size: 8, weight: .black))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5))
                            .cornerRadius(6)
                            
                            // Sync Button
                            Button(action: { mapInteraction.resetLiveMapToDesigner() }) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .help("Sync View to Designer")
                            
                            // Auto-track Toggle
                            Button(action: { mapInteraction.isLiveMapAutoTracking.toggle() }) {
                                Image(systemName: mapInteraction.isLiveMapAutoTracking ? "scope" : "hand.draw.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(mapInteraction.isLiveMapAutoTracking ? .cyan : .white)
                            }
                            .buttonStyle(.plain)
                            .help(mapInteraction.isLiveMapAutoTracking ? "Stop Auto-track" : "Start Auto-track")
                        }
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(12)
                    }
                    Spacer()
                }
            }
        case .camera(let id):
            // Look up boat for data overlay
            let boat = raceState.boats.first(where: { $0.id == id })
            BroadcastVideoFeedNode(boat: boat)
        case .replay:
            BroadcastVideoFeedNode(boat: nil, customLabel: "REPLAY")
        case .jury:
            BroadcastVideoFeedNode(boat: nil, customLabel: "JURY VIEW")
        }
    }
}
