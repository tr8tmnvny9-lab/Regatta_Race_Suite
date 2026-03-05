// LiveStreamManager.swift
//
// Phase 2 AWS Migration: Amazon Kinesis Video Streams WebRTC (KVS)
//
// The AWS KVS WebRTC SDK for iOS is distributed as a CocoaPod, not a Swift Package.
// This file defines the public interface and a ready-to-wire implementation.
// Integration steps (production):
//   1. Add `pod 'AmazonKinesisVideoStreamsWebRTC'` to `Podfile` and run `pod install`
//   2. Remove the conditional compile guards below
//   3. Uncomment the real KVS calls inside each function
//
// For now, the manager is fully functional as a stub: isStreaming publishes correctly,
// and any UI depending on LiveStreamManager will compile and work.

import Foundation
import Combine
import AVFoundation

// MARK: - Manager

class LiveStreamManager: ObservableObject {
    @Published var isStreaming = false
    @Published var connectionState: String = "idle"

    // AWS KVS channel info — set before calling connect()
    var channelARN: String = ""
    var region:     String = "eu-west-1"

    // Local media capture
    private var captureSession: AVCaptureSession?
    private var cancellables = Set<AnyCancellable>()

    init() {}

    // MARK: - Public

    /// Connects to the AWS KVS Signaling Channel and begins streaming.
    /// In production, `token` is a short-lived STS token fetched from the Rust backend.
    func connect(channelARN: String, token: String, region: String) {
        self.channelARN = channelARN
        self.region     = region

        print("📡 LiveStreamManager: connecting to KVS channel \(channelARN) [\(region)]")
        connectionState = "connecting"

        // ── Production: uncomment after CocoaPod integration ─────────────────
        // let config = KVSSignalingConfig(
        //     channelARN: channelARN,
        //     region: region,
        //     clientId: "regatta-tracker-\(UUID().uuidString)",
        //     credentialsProvider: StaticCredentialsProvider(token: token)
        // )
        // signalingClient = KVSSignalingClient(config: config)
        // signalingClient?.delegate = self
        // signalingClient?.connect()
        // ─────────────────────────────────────────────────────────────────────

        // Stub: simulate connection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connectionState = "connected (stub)"
            self?.isStreaming = true
            self?.startLocalCapture()
        }
    }

    func disconnect() {
        print("📡 LiveStreamManager: disconnecting")
        isStreaming = false
        connectionState = "idle"
        captureSession?.stopRunning()
        captureSession = nil

        // Production: signalingClient?.disconnect()
    }
    
    func setBandwidthThrottling(pauseHighRes: Bool) {
        print("📡 LiveStreamManager: setBandwidthThrottling(pauseHighRes: \(pauseHighRes))")
        // Production: Adjust KVS bitrates or pause tracks based on priority
    }

    // MARK: - Local camera capture

    private func startLocalCapture() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("⚠️ LiveStreamManager: no camera, running in audio-only mode")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}
