import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

struct TrackersAndSensorsSettingsView: View {
    @State private var qrImage: NSImage?
    @AppStorage("customRaceId") private var raceId: String = "RACE-772"
    @AppStorage("racePassword") private var racePassword: String = "secret123"
    
    // Hardcode local port used by the rust backend sidecar
    private let backendPort = 3001
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("TRACKERS & SENSORS")
                        .font(RegattaDesign.Fonts.heading)
                        .foregroundStyle(.white)
                    Text("Pair virtual or physical tracker applications.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                // Pair Card
                VStack(spacing: 24) {
                    HStack(alignment: .top, spacing: 30) {
                        // QR Code display
                        VStack(spacing: 12) {
                            if let qr = qrImage {
                                Image(nsImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 200, height: 200)
                                    .overlay(ProgressView())
                            }
                            
                            Text("SCAN TO CONNECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(RegattaDesign.Colors.cyan)
                        }
                        
                        // Connection Details
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Ensure the tracker is connected to the same local network.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                InfoRow(label: "RACE ID", value: raceId)
                                InfoRow(label: "PASSWORD", value: racePassword)
                                InfoRow(label: "ENDPOINTS", value: "\(getLocalIPAddresses().count) interfaces")
                            }
                            
                            Spacer()
                            
                            Button(action: generateRandomCredentials) {
                                Label("Regenerate Credentials", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(24)
                .glassPanel()
                
                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            if racePassword == "secret123" {
                generateRandomCredentials()
            } else {
                updateQRCode()
            }
        }
    }
    
    private func generateRandomCredentials() {
        raceId = "RACE-\(Int.random(in: 100...999))"
        let w = ["delta", "echo", "foxtrot", "golf", "hotel", "wind", "wave", "tack", "jib", "mark"]
        racePassword = "\(w.randomElement()!)-\(w.randomElement()!)-\(Int.random(in: 10...99))"
        updateQRCode()
    }
    
    private func updateQRCode() {
        let ips = getLocalIPAddresses()
        var allEndpoints = ips.map { "\"ws://\($0):\(backendPort)\"" }
        let hostName = ProcessInfo.processInfo.hostName
        allEndpoints.append("\"ws://\(hostName):\(backendPort)\"")
        
        // Convert to a JSON string array formulation
        let endpointsJson = "[\(allEndpoints.joined(separator: ", "))]"
        
        // Use a fallback in case the Mac is completely offline
        let finalUrls = endpointsJson == "[]" ? "[\"ws://127.0.0.1:\(backendPort)\"]" : endpointsJson
        
        let payload = """
        {
            "urls": \(finalUrls),
            "id": "\(raceId)",
            "pass": "\(racePassword)"
        }
        """
        
        qrImage = generateQRCode(from: payload)
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        if let data = string.data(using: .utf8) {
            filter.message = data
        }
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
            }
        }
        return nil
    }
    
    private func getLocalIPAddresses() -> [String] {
        var addresses = [String]()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            
            // Check for running IPv4 interfaces
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if let safeAddr = ptr.pointee.ifa_addr, safeAddr.pointee.sa_family == UInt8(AF_INET) {
                    let addr = safeAddr.pointee
                    if let cName = ptr.pointee.ifa_name {
                        let name = String(cString: cName)
                        // Accept any standard macOS active network interface (Wi-Fi, Ethernet, USB bridge)
                        if name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("utun") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let hw = String(cString: hostname)
                            addresses.append(hw)
                        }
                    }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}
