import Foundation
import Combine
import LiveKit
import AVFoundation

class LiveStreamManager: ObservableObject {
    @Published var isStreaming = false
    @Published var currentRoom: Room?
    
    private var localVideoTrack: LocalVideoTrack?
    
    // Hardcoded for testing. Production will securely pull the signaling URL from backend
    private let serverUrl = "wss://localhost:7880"
    
    init() {}
    
    func connect(token: String) {
        Task {
            let room = Room()
            do {
                try await room.connect(serverUrl, token)
                print("LiveKit Room Connected!")
                
                DispatchQueue.main.async {
                    self.currentRoom = room
                }
                
                // Initialize default front/back camera capture
                let cameraTrack = try LocalVideoTrack.createCameraTrack()
                self.localVideoTrack = cameraTrack
                
                // Publish local video to the Room
                try await room.localParticipant.publishVideoTrack(track: cameraTrack)
                
                DispatchQueue.main.async {
                    self.isStreaming = true
                }
                
                print("Published LocalVideoTrack to SFU successfully.")
                
            } catch {
                print("Failed to connect to LiveKit SFU: \\(error)")
            }
        }
    }
    
    // Command ingested from Rust Backend (SRS Auto-Director)
    func setBandwidthThrottling(pauseHighRes: Bool) {
        Task {
            guard let participant = currentRoom?.localParticipant else { return }
            do {
                print("Backend requested camera bandwidth change: \\(pauseHighRes ? "PAUSING" : "RESUMING")")
                try await participant.setCamera(enabled: !pauseHighRes)
            } catch {
                print("Failed to throttle camera feed: \\(error)")
            }
        }
    }
    
    func disconnect() {
        Task {
            await currentRoom?.disconnect()
            DispatchQueue.main.async {
                self.isStreaming = false
                self.currentRoom = nil
                self.localVideoTrack = nil
            }
        }
    }
}
