import Foundation
import OSLog
import Combine
import CoreLocation

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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
    
    // ─── Outbound Events ──────────────────────────────────────────────────
    
    func sendEvent(_ name: String, data: Any) {
        // Socket.IO v4 format: 42["event-name", {data}]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [name, data]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let payload = "42\(jsonString)"
        webSocketTask?.send(.string(payload)) { error in
            if let error = error {
                log.error("Failed to send Socket.IO event [\(name)]: \(error)")
            }
        }
    }
    
    func moveBuoy(id: String, coordinate: CLLocationCoordinate2D) {
        let data: [String: Any] = [
            "id": id,
            "lat": coordinate.latitude,
            "lon": coordinate.longitude
        ]
        sendEvent("move-buoy", data: data)
    }
    
    func updateBuoyConfig(buoy: Buoy) {
        let data: [String: Any] = [
            "id": buoy.id,
            "name": buoy.name,
            "color": buoy.color ?? "Yellow",
            "rounding": buoy.rounding ?? "Port",
            "design": buoy.design ?? "Cylindrical",
            "showLaylines": buoy.showLaylines
        ]
        sendEvent("update-buoy-config", data: data)
    }
    
    func setBoundary(points: [CLLocationCoordinate2D]) {
        let data = points.map { ["lat": $0.latitude, "lon": $0.longitude] }
        sendEvent("set-boundary", data: data)
    }
    
    func setRaceStatus(_ status: RaceStatus) {
        sendEvent("set-race-status", data: ["status": status.rawValue])
    }
    
    func setWind(speed: Double, direction: Double) {
        sendEvent("set-wind", data: ["speed": speed, "direction": direction])
    }
    
    func overrideMarks(marks: [Buoy]) {
        let serializedMarks = marks.map { buoy -> [String: Any] in
            return [
                "id": buoy.id,
                "type": buoy.type.rawValue,
                "name": buoy.name,
                "lat": buoy.pos.lat,
                "lon": buoy.pos.lon,
                "color": buoy.color ?? "Yellow",
                "rounding": buoy.rounding ?? "Port",
                "design": buoy.design ?? "Cylindrical",
                "showLaylines": buoy.showLaylines
            ]
        }
        sendEvent("override-marks", data: serializedMarks)
    }
    
    func deployProcedure(steps: [ProcedureStep], autoRestart: Bool) {
        // Build a safe, fully-typed payload matching the backend ProcedureGraph schema
        struct NodeData: Encodable {
            let label: String
            let flags: [String]
            let duration: Int
            let sound: String
            let soundOnRemove: String
            let waitForUserTrigger: Bool
            let actionLabel: String?
            let raceStatus: String?
            let postTriggerDuration: Int
            let postTriggerFlags: [String]
        }
        struct Node: Encodable {
            let id: String
            let type: String
            let data: NodeData
        }
        struct Edge: Encodable {
            let id: String
            let source: String
            let target: String
            let animated: Bool
        }
        struct Graph: Encodable {
            let id: String
            let nodes: [Node]
            let edges: [Edge]
            let autoRestart: Bool
        }
        
        let nodes = steps.map { step in
            Node(
                id: step.id,
                type: "state",
                data: NodeData(
                    label: step.label,
                    flags: step.flags,
                    duration: step.duration,
                    sound: step.soundStart.rawValue,
                    soundOnRemove: step.soundRemove.rawValue,
                    waitForUserTrigger: step.waitForUserTrigger,
                    actionLabel: step.actionLabel.isEmpty ? nil : step.actionLabel,
                    raceStatus: step.raceStatus == .autoDetect ? nil : step.raceStatus.rawValue,
                    postTriggerDuration: 0,
                    postTriggerFlags: []
                )
            )
        }
        
        let edges: [Edge] = zip(steps.dropLast(), steps.dropFirst()).map { a, b in
            Edge(id: "e_\(a.id)_\(b.id)", source: a.id, target: b.id, animated: true)
        }
        
        let graph = Graph(id: UUID().uuidString, nodes: nodes, edges: edges, autoRestart: autoRestart)
        
        guard let data = try? JSONEncoder().encode(graph),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            log.error("deployProcedure: Encoding failed — nothing sent")
            return
        }
        
        sendEvent("save-procedure", data: jsonObject)
    }

    
    // ─── Inbound Handling ─────────────────────────────────────────────────
    
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
            // Register as director to receive state and have write permissions
            sendEvent("register", data: ["type": "director"])
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
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if eventName == "state-update", let stateData = jsonArray[1] as? [String: Any] {
                    self.stateModel?.applyStateUpdate(stateData)
                } else if eventName == "telemetry-update", let telemetryNodes = jsonArray[1] as? [String: Any] {
                    var newBoats: [LiveBoat] = []
                    for (nodeId, nodeData) in telemetryNodes {
                        if let dict = nodeData as? [String: Any],
                           let lat = dict["lat"] as? Double,
                           let lng = dict["lng"] as? Double {
                            newBoats.append(LiveBoat(
                                id: nodeId,
                                pos: LatLon(lat: lat, lon: lng),
                                speed: (dict["speedKnots"] as? Double) ?? 0,
                                heading: (dict["course"] as? Double) ?? 0
                            ))
                        }
                    }
                    
                    // Throttled update to avoid bridge/render congestion
                    self.updateBoatsThrottled(newBoats)
                }
            }
        }
    }

    private var lastBoatUpdate = Date.distantPast
    private let updateInterval: TimeInterval = 0.05 // Cap at 20fps for performance

    private func updateBoatsThrottled(_ newBoats: [LiveBoat]) {
        let now = Date()
        if now.timeIntervalSince(lastBoatUpdate) >= updateInterval {
            self.stateModel?.boats = newBoats
            lastBoatUpdate = now
        }
    }
}
