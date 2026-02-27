import Foundation
import Network
import Combine

// Hardware definition matching the embedded STM32/Rust structures
struct MeasurementPacket {
    var nodeId: UInt32
    var seqNum: UInt32
    var timestamp: UInt64
    var pdoaAzimuth: Float32
    var rangeCm: UInt16
    var signature: [UInt8] // 16 bytes auth tag
}

class UDPListener: ObservableObject {
    @Published var packetCount = 0
    @Published var lastPacketTime: Date?
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "UDPListenerQueue")
    
    // Injected to route validated packets to the backend WebSocket
    var connectionManager: ConnectionManager?
    
    func start() {
        do {
            let params = NWParameters.udp
            params.allowFastOpen = true
            
            // Port 5555 matches the Ubiquiti AP UWB multicast port
            listener = try NWListener(using: params, on: 5555)
            
            listener?.stateUpdateHandler = { state in
                print("UDP Listener state: \\(state)")
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("Started UDP Listener on port 5555.")
        } catch {
            print("Failed to start UDP listener: \\(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            if let data = content {
                self?.processPacket(data)
            }
            
            if error == nil && connection.state == .ready {
                self?.receive(on: connection)
            }
        }
    }
    
    private func processPacket(_ data: Data) {
        // Minimal length check for security (Header + body + 16 byte signature)
        guard data.count >= 24 else { return }
        
        DispatchQueue.main.async {
            self.packetCount += 1
            self.lastPacketTime = Date()
        }
        
        // TODO: Validate CRC32 and Auth Signature
        // Forward to sidecar/Cloud if valid
        // self.connectionManager?.sendUWBData(data)
    }
}
