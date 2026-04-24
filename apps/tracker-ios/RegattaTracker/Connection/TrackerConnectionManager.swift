import Foundation
import Network
import UIKit
import CoreMotion
import Combine

class TrackerConnectionManager: ObservableObject {
    @Published var sessionId: String? = nil
    @Published var isConnected: Bool = false
    @Published var currentMode: ConnectionMode = .finding
    
    enum ConnectionMode { case finding, lan, cloud, offline }
    
    private var monitor = NWPathMonitor()
    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var telemetryTimer: Timer?
    private var reconnectAttempts: Int = 0
    
    
    var authManager: SupabaseAuthManager? // Injected from root
    var liveStreamManager: LiveStreamManager? // For WebRTC Control
    private var location: LocationManager?
    private var ble: UWBNodeBLEClient?
    private var motion: MotionManager?
    private var failsafe: FailsafeManager?
    var raceState: RaceStateModel? // Injected from start()
    @Published var virtualSailingModel: VirtualSailingViewModel?
    var boatId: String {
        return "virtual-boat-1"
    }
    
    private func now_ms() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    init() {
        if let savedSession = UserDefaults.standard.string(forKey: "lastSessionId") {
            self.sessionId = savedSession
        }
    }
    
    func start(location: LocationManager? = nil, ble: UWBNodeBLEClient? = nil, motion: MotionManager? = nil, failsafe: FailsafeManager? = nil, raceState: RaceStateModel? = nil) {
        self.location = location
        self.ble = ble
        self.motion = motion
        self.failsafe = failsafe
        self.raceState = raceState
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.currentMode == .offline {
                        self?.currentMode = .finding
                        self?.connect()
                        self?.flushOfflineBuffer()
                        self?.failsafe?.stopRecording()
                    }
                } else {
                    self?.currentMode = .offline
                    self?.isConnected = false
                    self?.failsafe?.startRecording()
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        connect()
        
        // Start 10Hz telemetry sampling loop in .common mode so it doesn't pause when dragging the joystick!
        DispatchQueue.main.async {
            self.telemetryTimer?.invalidate()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.sampleAndTransmitTelemetry()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.telemetryTimer = timer
        }
    }
    
    func joinSession(id: String) {
        self.sessionId = id
        UserDefaults.standard.set(id, forKey: "lastSessionId")
        connect()
    }
    
    func connect() {
        guard let _ = sessionId, currentMode != .offline else { return }
        
        // Resolve endpoint from TrackerEndpointConfig (reads Info.plist / UserDefaults / AWS default)
        // This replaces the previous hardcoded Fly.io URL.
        let resolvedURL = TrackerEndpointConfig.webSocketURL
        let resolvedMode = TrackerEndpointConfig.preferredMode
        
        self.currentMode = (resolvedMode == .awsCloud) ? .cloud : .lan
        
        print("🔌 [DEBUG] Tracker attempting connection...")
        print("   📍 URL: \(resolvedURL)")
        print("   🆔 Session: \(sessionId ?? "none")")
        print("   📡 Mode: \(currentMode)")
        
        let request = URLRequest(url: resolvedURL)
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        self.receiveMessage()
    }
    
    func forceReconnect() {
        print("🔌 [DEBUG] Forcing socket teardown and reconnect (Foregrounding)...")
        pingTimer?.invalidate()
        isConnected = false
        connect()
    }
    
    private func sampleAndTransmitTelemetry() {
        guard let sessionId = sessionId else { return }
        
        // Feed real GPS into UWB Emulator if it's active
        if let lastLocation = location?.manager.location {
            ble?.emulator.ingestRealGPS(lastLocation)
        }
        
        // Build position (Override with Virtual Simulator if active)
        var lat = location?.currentPosition?.latitude ?? 0.0
        var lon = location?.currentPosition?.longitude ?? 0.0
        var alt = location?.altitude ?? 0.0
        var course = location?.headingDegrees ?? 0.0
        var speed = location?.speedKnots ?? 0.0
        
        if let sim = virtualSailingModel, sim.isActive {
            lat = sim.latitude
            lon = sim.longitude
            course = sim.heading
            speed = sim.speedKnots
        }
        
        let isUWB = ble?.isConnected ?? false
        let dtl = ble?.dtlCm
        
        // Raw Motion
        let accel = motion?.accelerometerData
        let gyro = motion?.gyroData
        let mag = motion?.magnetometerData
        let relAlt = motion?.relativeAltitude ?? 0.0
        
        // Device Health
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel
        let thermal = ProcessInfo.processInfo.thermalState
        
        // Mock non-zero values if standing still, for Regatta visualization testing
        if lat == 0 { lat = 60.1699; lon = 24.9384 }
        
        // Virtual Sailing Override
        if let virtual = virtualSailingModel, virtual.isActive {
            lat = virtual.latitude
            lon = virtual.longitude
            course = virtual.heading
            speed = virtual.speedKnots
        }
        
        var motionDict: [String: Any] = [
            "accel": ["x": accel?.x ?? 0, "y": accel?.y ?? 0, "z": accel?.z ?? 0],
            "gyro": ["x": gyro?.x ?? 0, "y": gyro?.y ?? 0, "z": gyro?.z ?? 0],
            "mag": ["x": mag?.x ?? 0, "y": mag?.y ?? 0, "z": mag?.z ?? 0],
            "relAlt": relAlt
        ]
        
        // Add Virtual Roll (Heeling) to IMU data if active
        if let virtual = virtualSailingModel, virtual.isActive {
            motionDict["imu"] = [
                "roll": virtual.roll,
                "pitch": 0.0,
                "heading": virtual.heading
            ]
        }
        
        let deviceDict: [String: Any] = [
            "battery": battery,
            "thermal": thermal.rawValue,
            "ts": Date().timeIntervalSince1970
        ]
        
        var payloadDict: [String: Any] = [
            "boatId": "virtual-boat-1",
            "pos": [
                "lat": lat,
                "lon": lon
            ],
            "imu": [
                "heading": course,
                "roll": virtualSailingModel?.roll ?? 0.0,
                "pitch": 0.0
            ],
            "velocity": [
                "speed": speed,
                "dir": course // Simplified for mock
            ],
            "timestamp": now_ms(),
            "isSimulating": virtualSailingModel?.isActive ?? false
        ]
        
        // Safely add optional DTL to avoid silent JSONSerialization crash
        if let safeDtl = dtl {
            payloadDict["dtl"] = safeDtl
        }
        
        // Add additional debug/device data
        payloadDict["device"] = deviceDict
        payloadDict["motion_raw"] = motionDict
        
        if isConnected {
            // Live Push
            transmit(payload: payloadDict)
        } else {
            // Failsafe Logging
            failsafe?.logTelemetry(payloadDict)
            
            // Legacy Offline Buffer (for basic fallback)
            let bufferedPos = BufferedPosition(
                sessionId: sessionId,
                timestamp: Date(),
                latitude: lat,
                longitude: lon,
                course: course,
                speed: speed,
                isUWB: isUWB,
                dtlCm: dtl
            )
            OfflineBuffer.shared.bufferPosition(bufferedPos)
        }
    }
    
    private func transmit(payload: [String: Any]) {
        // Diagnostic Log D1: Generation pulse
        if let boatId = payload["boatId"] as? String, boatId == "virtual-boat-1" {
            DispatchQueue.main.async {
                self.raceState?.diagnosticHeartbeats["D1", default: 0] += 1
            }
            if let pos = payload["pos"] as? [String: Any] {
                print("📡 [D1-TRACKER-GEN] Pulse: virtual-boat-1 at lat=\(pos["lat"] ?? 0), lon=\(pos["lon"] ?? 0)")
            }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Diagnostic Log D2: Transmission pulse
            if let boatId = payload["boatId"] as? String, boatId == "virtual-boat-1" {
                print("📤 [D2-TRACKER-TX] Transmitting virtual-boat-1 telemetry: \(jsonString)")
            }

            let ioPayload = "42[\"track-update\", \(jsonString)]"
            webSocket?.send(.string(ioPayload)) { _ in }
        }
    }
    
    func transmitEvent(name: String, payload: [String: Any]) {
        guard isConnected else { return }
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let ioPayload = "42[\"\(name)\", \(jsonString)]"
            webSocket?.send(.string(ioPayload)) { _ in }
        }
    }
    
    private func flushOfflineBuffer() {
        let buffered = OfflineBuffer.shared.fetchAllBuffered()
        if buffered.isEmpty { return }
        
        print("Flushing \\(buffered.count) offline positions to backend...")
        
        let dicts = buffered.map { pos -> [String: Any] in
            return [
                "lat": pos.latitude,
                "lng": pos.longitude,
                "course": pos.course,
                "speedKnots": pos.speed,
                "timestamp": pos.timestamp.timeIntervalSince1970 * 1000,
                "isUwb": pos.isUWB,
                "dtlCm": pos.dtlCm as Any
            ]
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dicts),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            let ioPayload = "42[\"track-update-bulk\", \(jsonString)]"
            webSocket?.send(.string(ioPayload)) { _ in }
        }
        
        if let maxId = buffered.last?.id {
            OfflineBuffer.shared.clearBuffered(upTo: maxId)
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if text != "2" && text != "3" { // Skip ping/pong noise
                        print("📥 [SOCKET-IO-RX] \(text)")
                    }
                    self.handleSocketIOText(text)
                default: break
                }
                self.receiveMessage() // Continue listening
            case .failure(let error):
                print("WebSocket error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.pingTimer?.invalidate()
                }
                
                // Exponential backoff for 5G cellular reconnection
                let maxBackoff: TimeInterval = 30.0
                let backoff: TimeInterval = min(pow(2.0, Double(self.reconnectAttempts)), maxBackoff)
                self.reconnectAttempts += 1
                
                print("Initiating reconnect attempt \(self.reconnectAttempts) in \(backoff) seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + backoff) { [weak self] in
                    self?.connect()
                }
            }
        }
    }
    
    private func handleSocketIOText(_ text: String) {
        // Engine.IO Open packet
        if text.hasPrefix("0") {
            // Send Engine.IO Upgrade / Connect
            webSocket?.send(.string("40")) { _ in }
            
            // Start Engine.IO Ping (Packet type 2, send every 25 seconds)
            DispatchQueue.main.async {
                self.pingTimer?.invalidate()
                self.pingTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
                    self?.webSocket?.send(.string("2")) { _ in }
                }
            }
        }
        // Respond to Engine.IO Ping
        else if text == "2" {
            webSocket?.send(.string("3")) { _ in }
        }
        // Socket.IO Connect packet
        else if text.hasPrefix("40") {
            DispatchQueue.main.async {
                self.isConnected = true
                self.reconnectAttempts = 0 // Reset backoff on success
                
                // Emit register event with the 'tracker' role and boatId so backend routes telemetry
                let token = self.authManager?.currentJWT ?? "tracker123"
                let bid = self.boatId
                let payload = "42[\"register\", {\"role\": \"tracker\", \"boatId\": \"\(bid)\", \"type\": \"\(token)\"}]"
                self.webSocket?.send(.string(payload)) { _ in } 
                
                if self.authManager?.currentJWT != nil {
                    print("Transmitted secure AWS IAM/Cognito JWT payload to backend.")
                } else {
                    print("Transmitted fallback local tracker token.")
                }
            }
        }
        else if text.hasPrefix("42") {
            let jsonString = String(text.dropFirst(2))
            if let data = jsonString.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
               let eventName = array.first as? String {
                
                if eventName == "focus_boats_changed" {
                    if let focusData = array.last as? [String: Any],
                       let focusBoats = focusData["focus_boats"] as? [String] {
                        
                        // If this device's auth id isn't in the focus list, pause high-res
                        // We mock our identity as "boat-1" for development
                        let isFocused = focusBoats.contains("boat-1") 
                        self.liveStreamManager?.setBandwidthThrottling(pauseHighRes: !isFocused)
                    }
                } else if eventName == "state-update" || eventName == "init-state" || eventName == "course-updated" {
                    // For course-updated, the payload might just be the course object or the state payload
                    // Let's pass the payload to the race state and trigger warp logic if it contains marks
                    if let payloadDict = array.last as? [String: Any] {
                        var statePayload = payloadDict
                        if eventName == "course-updated" {
                            statePayload = ["course": payloadDict] // Wrap it for universal parsing
                            DispatchQueue.main.async {
                                self.raceState?.applyStateUpdate(statePayload)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.raceState?.applyStateUpdate(statePayload)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            // Warp logic: if we have marks, find the centroid and warp the virtual model
                            if let courseData = statePayload["course"] as? [String: Any],
                               let marks = courseData["marks"] as? [[String: Any]], !marks.isEmpty {
                                var totalLat = 0.0
                                var totalLon = 0.0
                                for m in marks {
                                    if let pos = m["pos"] as? [String: Any],
                                       let mLat = pos["lat"] as? Double,
                                       let mLon = pos["lon"] as? Double {
                                        totalLat += mLat
                                        totalLon += mLon
                                    }
                                }
                                let avgLat = totalLat / Double(marks.count)
                                let avgLon = totalLon / Double(marks.count)
                                self.virtualSailingModel?.warpToLocation(lat: avgLat, lon: avgLon)
                            }
                            
                            // Sync wind to virtual model if it exists
                            if let wind = statePayload["wind"] as? [String: Any],
                               let dir = wind["direction"] as? Double {
                                self.virtualSailingModel?.virtualWindDir = dir
                            }
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        pingTimer?.invalidate()
        monitor.cancel()
    }
}
