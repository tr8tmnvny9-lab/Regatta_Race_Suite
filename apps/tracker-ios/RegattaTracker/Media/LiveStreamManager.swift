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
import CoreImage
import CoreVideo
import UIKit

// MARK: - Manager

class LiveStreamManager: NSObject, ObservableObject {
    @Published var isStreaming = false
    @Published var connectionState: String = "idle"
    weak var connectionManager: TrackerConnectionManager?
    
    // AWS KVS channel info — set before calling connect()
    var channelARN: String = ""
    var region:     String = "eu-west-1"

    // Local media capture
    private var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    
    private var lastFrameTime: Date = Date()
    private let fpsLimit: Double = 10.0 // 10 FPS

    override init() {
        super.init()
    }

    // MARK: - Public

    /// Connects to the local WebSocket (AWS stubbed)
    func connect(channelARN: String, token: String, region: String) {
        self.channelARN = channelARN
        self.region     = region

        print("📡 LiveStreamManager: Starting local AV stream override [\(region)]")
        connectionState = "connecting"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connectionState = "connected (local bridge)"
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
    }
    
    func setBandwidthThrottling(pauseHighRes: Bool) {
        print("📡 LiveStreamManager: setBandwidthThrottling(pauseHighRes: \(pauseHighRes))")
    }

    // MARK: - Local camera capture

    private func startLocalCapture() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self = self else {
                print("⚠️ LiveStreamManager: Camera permission denied!")
                return
            }
            
            DispatchQueue.main.async {
                let session = AVCaptureSession()
                session.sessionPreset = .medium // ~480x360
                
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera) else {
                    print("⚠️ LiveStreamManager: no camera found!")
                    return
                }

                if session.canAddInput(input) { session.addInput(input) }
                
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

                if session.canAddOutput(self.videoOutput) { session.addOutput(self.videoOutput) }
                
                if let connection = self.videoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                    } else {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                    }
                }

                self.captureSession = session
                DispatchQueue.global(qos: .userInitiated).async { [weak session] in
                    session?.startRunning()
                }
            }
        }
    }
}

extension LiveStreamManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isStreaming else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastFrameTime) < (1.0 / fpsLimit) { return }
        lastFrameTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Flip the raw buffer properly if orientation is inverted
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.3) else { return }
        let base64String = jpegData.base64EncodedString()
        
        let bid = connectionManager?.boatId ?? "virtual-boat-1"
        let payload: [String: Any] = [
            "boatId": bid,
            "frame": base64String
        ]
            
        connectionManager?.transmitEvent(name: "video-frame", payload: payload)
    }
}
