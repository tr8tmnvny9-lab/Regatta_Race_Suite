import Foundation
import Network
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
    
    
    var authManager: SupabaseAuthManager? // Injected from root
    var liveStreamManager: LiveStreamManager? // For WebRTC Control
    private var location: LocationManager?
    private var ble: UWBNodeBLEClient?
    
    init() {
        if let savedSession = UserDefaults.standard.string(forKey: "lastSessionId") {
            self.sessionId = savedSession
        }
    }
    
    func start(location: LocationManager? = nil, ble: UWBNodeBLEClient? = nil) {
        self.location = location
        self.ble = ble
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.currentMode == .offline {
                        self?.currentMode = .finding
                        self?.connect()
                        self?.flushOfflineBuffer()
                    }
                } else {
                    self?.currentMode = .offline
                    self?.isConnected = false
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        connect()
        
        // Start 10Hz telemetry sampling loop
        DispatchQueue.main.async {
            self.telemetryTimer?.invalidate()
            self.telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.sampleAndTransmitTelemetry()
            }
        }
    }
    
    func joinSession(id: String) {
        self.sessionId = id
        UserDefaults.standard.set(id, forKey: "lastSessionId")
        connect()
    }
    
    func connect() {
        guard let _ = sessionId, currentMode != .offline else { return }
        
        self.currentMode = .cloud
        
        // Connect directly to the Socket.IO v4 endpoint on Fly.io
        let url = URL(string: "wss://regatta-backend-oscar.fly.dev/socket.io/?EIO=4&transport=websocket")!
        let request = URLRequest(url: url)
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        self.receiveMessage()
    }
    
    private func sampleAndTransmitTelemetry() {
        guard let sessionId = sessionId else { return }
        
        // Build position
        var lat = location?.currentPosition?.latitude ?? 0.0
        var lon = location?.currentPosition?.longitude ?? 0.0
        var course = location?.headingDegrees ?? 0.0
        var speed = location?.speedKnots ?? 0.0
        
        let isUWB = ble?.isConnected ?? false
        let dtl = ble?.dtlCm
        
        // Mock non-zero values if standing still, for Regatta visualization testing
        if lat == 0 { lat = 59.3293; lon = 18.0686 }
        
        let position = BufferedPosition(
            sessionId: sessionId,
            timestamp: Date(),
            latitude: lat,
            longitude: lon,
            course: course,
            speed: speed,
            isUWB: isUWB,
            dtlCm: dtl
        )
        
        if isConnected {
            // Live Push
            transmit(position: position)
        } else {
            // Offline Buffer
            OfflineBuffer.shared.bufferPosition(position)
        }
    }
    
    private func transmit(position: BufferedPosition) {
        let payloadDict: [String: Any] = [
            "lat": position.latitude,
            "lng": position.longitude,
            "course": position.course,
            "speedKnots": position.speed,
            "isUwb": position.isUWB,
            "dtlCm": position.dtlCm as Any
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            let ioPayload = "42[\"track-update\", \(jsonString)]"
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
                // Automatic reconnect with backoff could go here
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
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
        // Socket.IO Connect packet
        else if text.hasPrefix("40") {
            DispatchQueue.main.async {
                self.isConnected = true
            }
            // Emit register event with the secure JWT from the Keychain
            if let jwt = authManager?.currentJWT {
                let payload = """
                42["register", {"type": "\(jwt)"}]
                """
                webSocket?.send(.string(payload)) { _ in }
                print("Transmitted secure Supabase JWT payload to backend.")
            } else {
                print("WARNING: No JWT available for authentication.")
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
                }
            }
        }
    }
    
    deinit {
        pingTimer?.invalidate()
        monitor.cancel()
    }
}
