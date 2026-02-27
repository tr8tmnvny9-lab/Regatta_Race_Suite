import Foundation
import OSLog
import Combine

private let log = Logger(subsystem: "com.regatta.pro", category: "RaceEngine")

final class RaceEngineClient: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    @Published var isConnected = false
    
    // We pass the parsed data directly into the shared RaceStateModel
    var stateModel: RaceStateModel?
    
    // Connect to local sidecar Socket.IO path
    func connect(to backendURL: URL) {
        // Socket.IO v4 transport
        let wsString = backendURL.absoluteString
            .replacingOccurrences(of: "http", with: "ws")
            + "/socket.io/?EIO=4&transport=websocket"
        
        guard let url = URL(string: wsString) else { return }
        log.info("Connecting to Race Engine at \(url)")
        
        let request = URLRequest(url: url)
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isConnected = true
        receiveMessage()
        
        // Keep-alive for Socket.IO
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
                self?.webSocketTask?.send(.string("2")) { _ in } // Socket.IO Ping
            }
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        pingTimer?.invalidate()
        isConnected = false
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                log.error("WebSocket Error: \(error)")
                DispatchQueue.main.async { self.isConnected = false }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleSocketIOPayload(text)
                case .data(let data):
                    log.debug("Received binary data of \(data.count) bytes")
                @unknown default:
                    break
                }
                
                // Keep listening
                if self.isConnected {
                    self.receiveMessage()
                }
            }
        }
    }
    
    private func handleSocketIOPayload(_ payload: String) {
        if payload == "3" { // Socket.IO Pong
            return
        }
        
        if payload.starts(with: "0") {
            log.info("Socket.IO Handshake accepted")
            return
        }
        
        if payload.starts(with: "42") { // Socket.IO Event
            let jsonString = String(payload.dropFirst(2))
            guard let data = jsonString.data(using: .utf8),
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  jsonArray.count >= 2,
                  let eventName = jsonArray[0] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                if eventName == "state-update", let stateData = jsonArray[1] as? [String: Any] {
                    self.stateModel?.applyStateUpdate(stateData)
                } else if eventName == "telemetry-update", let telemetryNodes = jsonArray[1] as? [String: Any] {
                    // Quick mock mapping for TacticalMapView
                    var activeBoats: [LiveBoat] = []
                    for (nodeId, nodeData) in telemetryNodes {
                        if let dict = nodeData as? [String: Any],
                           let lat = dict["lat"] as? Double,
                           let lng = dict["lng"] as? Double {
                            activeBoats.append(LiveBoat(
                                id: nodeId,
                                position: CGPoint(x: lat, y: lng), // In reality, map converting
                                speed: (dict["speedKnots"] as? Double) ?? 0,
                                heading: (dict["course"] as? Double) ?? 0
                            ))
                        }
                    }
                    self.stateModel?.boats = activeBoats
                }
            }
        }
    }
}
