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
    var authManager: SupabaseAuthManager? // Injected from root
    
    init() {
        if let savedSession = UserDefaults.standard.string(forKey: "lastSessionId") {
            self.sessionId = savedSession
        }
    }
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.currentMode == .offline {
                        self?.currentMode = .finding
                        self?.connect()
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
            // Handle incoming events (e.g., init-state, sequence-update)
            // Parse JSON array after the "42" prefix
        }
    }
    
    deinit {
        pingTimer?.invalidate()
        monitor.cancel()
    }
}
