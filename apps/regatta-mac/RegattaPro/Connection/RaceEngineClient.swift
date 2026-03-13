import Foundation
import OSLog
import Combine
import CoreLocation

private let log = Logger(subsystem: "com.regatta.pro", category: "RaceEngine")

final class RaceEngineClient: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    @Published var isConnected = false
    @Published var isReady = false // True after Socket.IO handshake
    private var isConnecting = false
    private var watchdogTimer: Timer?
    private var lastBackendURL: URL?
    
    private var eventQueue: [(name: String, data: Any)] = []
    // We pass the parsed data directly into the shared RaceStateModel
    var stateModel: RaceStateModel?
    
    // Connect to local sidecar Socket.IO path
    func connect(to backendURL: URL) {
        guard !isConnecting else { 
            print("⏳ Connection already in progress, skipping...")
            return 
        }
        
        // Ensure we are using 127.0.0.1 instead of localhost for IPv4 reliability
        let cleanURLString = backendURL.absoluteString.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        guard let cleanURL = URL(string: cleanURLString) else { return }
        
        isConnecting = true
        
        // Socket.IO v4 transport
        let wsString = cleanURL.absoluteString
            .replacingOccurrences(of: "http", with: "ws")
            + "/socket.io/?EIO=4&transport=websocket"
        
        guard let url = URL(string: wsString) else { 
            isConnecting = false
            return 
        }
        
        log.info("🔌 Connecting to Race Engine at \(url)")
        self.lastBackendURL = backendURL
        
        let request = URLRequest(url: url)
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        
        isReady = false
        isConnected = false
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isConnected = true
        receiveMessage()
        
        // Start self-healing watchdog
        DispatchQueue.main.async { [weak self] in
            self?.watchdogTimer?.invalidate()
            self?.watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.checkConnectionHealth()
            }
        }
        
        // Keep-alive for Socket.IO
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pingTimer?.invalidate()
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in // Faster ping (15s)
                guard let self = self, self.isConnected else { return }
                
                // Low-level WebSocket ping
                self.webSocketTask?.sendPing { error in
                    if let error = error {
                        print("❌ TCP Ping Failed: \(error.localizedDescription)")
                    }
                }
                
                // Socket.IO Level Pulse
                print("💓 Pulse: Sending Socket.IO Ping (2)")
                self.webSocketTask?.send(.string("2")) { error in
                    if let error = error {
                        print("❌ Socket.IO Ping Failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.isConnected = false
                            self.isReady = false
                        }
                    }
                }
            }
        }
        
        isConnecting = false
    }
    
    func disconnect() {
        print("🔌 Manually disconnecting from Race Engine")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        pingTimer?.invalidate()
        watchdogTimer?.invalidate()
        isConnected = false
        isReady = false
        isConnecting = false
    }
    
    private func checkConnectionHealth() {
        guard isConnected else { return }
        
        if !isReady {
            print("🚨 Watchdog: Socket is connected but not ready (handshake pending). Retrying...")
            if let url = lastBackendURL {
                isConnecting = false // Reset to allow retry
                connect(to: url)
            }
        }
    }
    
    // ─── Outbound Events ──────────────────────────────────────────────────
    
    func sendEvent(_ name: String, data: Any) {
        guard isReady else {
            print("⏳ Socket not ready, queuing event [\(name)]")
            eventQueue.append((name, data))
            return
        }
        
        // Socket.IO v4 format: 42["event-name", {data}]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [name, data]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let payload = "42\(jsonString)"
        print("📤 Sending Socket.IO event [\(name)]: \(jsonString)")
        webSocketTask?.send(.string(payload)) { [weak self] error in
            if let error = error {
                print("❌ Failed to send Socket.IO event [\(name)]: \(error)")
                DispatchQueue.main.async {
                    self?.isReady = false
                    self?.isConnected = false
                    print("⏳ Re-queuing failed event [\(name)]")
                    self?.eventQueue.append((name, data))
                }
            }
        }
    }
    
    private func flushQueue() {
        guard isReady else { return }
        let queue = eventQueue
        eventQueue.removeAll()
        
        print("🚀 Flushing \(queue.count) queued events")
        for event in queue {
            sendEvent(event.name, data: event.data)
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

    // ─── League Sailing Events ───────────────────────────────────────────
    
    func setTeams(teams: [LeagueTeam]) {
        let data = teams.map { team -> [String: Any] in
            return [
                "id": team.id,
                "name": team.name,
                "club": team.club,
                "skipper": "", // Backend expects skipper
                "status": "ACTIVE",
                "ranking": team.ranking
            ]
        }
        sendEvent("set-teams", data: data)
    }
    
    func generateFlights(flightCount: Int, boatCount: Int) {
        let data: [String: Any] = [
            "flightCount": flightCount,
            "boats": boatCount
        ]
        sendEvent("generate-flights", data: data)
    }

    
    // ─── Inbound Handling ─────────────────────────────────────────────────
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("❌ WebSocket Receive Failure: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isReady = false
                    // Trigger a re-evaluation if it's a timeout or connection loss
                    self.stateModel?.triggerConnectivityRefresh()
                }
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleSocketIOPayload(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleSocketIOPayload(text)
                    }
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
        if payload == "2" { // Server Ping
            print("💓 Received Server Ping, sending Pong")
            webSocketTask?.send(.string("3")) { _ in }
            return
        }
        
        if payload == "3" { // Server Pong (to our Ping)
            return
        }
        
        if payload.starts(with: "0") {
            log.info("Socket.IO Handshake accepted: \(payload)")
            DispatchQueue.main.async {
                self.isReady = true
                self.flushQueue()
            }
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
                            var boat = LiveBoat(
                                id: nodeId,
                                pos: LatLon(lat: lat, lon: lng),
                                speed: (dict["speedKnots"] as? Double) ?? 0,
                                heading: (dict["course"] as? Double) ?? 0
                            )
                            boat.rank = dict["rank"] as? Int
                            boat.dtf = dict["dtf_m"] as? Double
                            boat.legIndex = dict["leg_index"] as? Int
                            
                            if let tid = self.stateModel?.boatToTeamId[nodeId],
                               let tName = self.stateModel?.teamsMap[tid] {
                                boat.teamName = tName
                            }
                            newBoats.append(boat)
                        }
                    }
                    
                    // Update Zone Detection
                    self.stateModel?.updateZoneDetection(newBoats)
                    
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
