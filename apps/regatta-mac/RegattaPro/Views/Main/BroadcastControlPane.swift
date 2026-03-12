import SwiftUI

/// Right-edge pane displaying the Camera Stream Selector Tool
struct BroadcastControlPane: View {
    @EnvironmentObject var raceState: RaceStateModel
    
    private var availableCameras: [(String, String, String)] {
        raceState.boats.map { boat in
            (boat.teamName?.uppercased() ?? boat.id, "ONBOARD CAM", boat.color ?? "#FFFFFF")
        }
    }
    
    // Simulate which 4 are active
    @State private var activeCameraIndices: Set<Int> = [0, 1, 2, 3]
    @State private var autoDirectorEnabled: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Tab
            HStack {
                Text("CAMERA SELECTOR")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                Spacer()
                Toggle("", isOn: $autoDirectorEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.3))
            
            // Selector List
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Permanent Draggable Map Token
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.cyan)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TACTICAL MAP")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("RACE COURSE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.cyan.opacity(0.8))
                                .tracking(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.white.opacity(0.3))
                            .font(.system(size: 14))
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                    .draggable(BroadcastDragItem(contentType: "map", id: "map"))
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Camera Pool
                    ForEach(Array(availableCameras.enumerated()), id: \.offset) { index, cam in
                        let isActive = activeCameraIndices.contains(index)
                        
                        Button(action: {
                            toggleCam(index)
                        }) {
                            HStack(spacing: 12) {
                                // Status Indicator
                                Circle()
                                    .fill(isActive ? Color.red : Color.white.opacity(0.1))
                                    .frame(width: 8, height: 8)
                                    .shadow(color: isActive ? Color.red : .clear, radius: 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cam.0)
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(isActive ? .white : .white.opacity(0.6))
                                    Text(cam.1)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.cyan.opacity(isActive ? 1.0 : 0.4))
                                        .tracking(1)
                                }
                                
                                Spacer()
                                
                                // Drag visual cue
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .font(.system(size: 14))
                                
                                if isActive {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(isActive ? 0.08 : 0.02))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(isActive ? 0.2 : 0.0), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(autoDirectorEnabled) // Lock if auto director is making choices
                        .opacity(autoDirectorEnabled && !isActive ? 0.4 : 1.0)
                        // Enable Dragging for the Center Stage
                        .draggable(BroadcastDragItem(contentType: "camera", id: cam.0))
                    }
                }
                .padding(16)
            }
        }
        .background(.clear)
    }
    
    // Business logic to strictly enforce 4 maximum streams
    private func toggleCam(_ index: Int) {
        if activeCameraIndices.contains(index) {
            activeCameraIndices.remove(index)
        } else {
            if activeCameraIndices.count < 4 {
                activeCameraIndices.insert(index)
            } else {
                // If full, remove the oldest index? Or just ignore.
                // For this UI mockup, just ignore clicking a 5th.
            }
        }
    }
}
