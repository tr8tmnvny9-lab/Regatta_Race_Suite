import SwiftUI

/// Wraps the primary broadcast focus area with Drag & Drop preset layouts.
struct BroadcastCenterStage: View {
    @EnvironmentObject var stageModel: BroadcastStageModel
    
    var body: some View {
        ZStack {
            // Background is liquid glass
            // Background is liquid glass
            Color.clear
            
            // Grid Layout Engine
            GeometryReader { geo in
                switch stageModel.activeLayout {
                case .single:
                    BroadcastSlotView(slotIndex: 0)
                        .frame(width: geo.size.width, height: geo.size.height)
                        
                case .quad:
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            BroadcastSlotView(slotIndex: 0)
                            BroadcastSlotView(slotIndex: 1)
                        }
                        HStack(spacing: 4) {
                            BroadcastSlotView(slotIndex: 2)
                            BroadcastSlotView(slotIndex: 3)
                        }
                    }
                    
                case .split:
                    HStack(spacing: 4) {
                        // Massive Left View (typically Map or Lead Boat)
                        BroadcastSlotView(slotIndex: 0)
                            .frame(width: geo.size.width * 0.7)
                        
                        // Stacked Right Views
                        VStack(spacing: 4) {
                            BroadcastSlotView(slotIndex: 1)
                            BroadcastSlotView(slotIndex: 3)
                        }
                    }
                }
            }
            .background(Color.white.opacity(0.02)) // Very subtle backing
            
            // Layout switcher (Bottom Center HUD style)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 20) {
                        LayoutButton(icon: "square.fill", label: "SINGLE", active: stageModel.activeLayout == .single) {
                            stageModel.activeLayout = .single
                        }
                        
                        LayoutButton(icon: "square.split.2x1.fill", label: "FOCUS", active: stageModel.activeLayout == .split) {
                            stageModel.activeLayout = .split
                        }
                        
                        LayoutButton(icon: "square.grid.2x2.fill", label: "MATRIX", active: stageModel.activeLayout == .quad) {
                            stageModel.activeLayout = .quad
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                    .padding(.bottom, 24)
                    Spacer()
                }
            }
        }
        .clipped()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stageModel.activeLayout)
    }
}

/// Premium layout selection button
struct LayoutButton: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(active ? .cyan : .white.opacity(0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? Color.cyan.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
