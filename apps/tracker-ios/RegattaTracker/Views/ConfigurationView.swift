// ConfigurationView.swift
// Regatta Tracker — Manual and Automatic session joining flow.

import SwiftUI
import AVFoundation

struct ConfigurationView: View {
    @EnvironmentObject var connection: TrackerConnectionManager
    @Environment(\.dismiss) var dismiss
    
    let initialMode: WelcomeView.ConfigurationMode
    @State private var mode: ConfigurationModeState = .selection
    @State private var raceId: String = ""
    @State private var password: String = ""
    @State private var expectedScannedPassword: String?
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    enum ConfigurationModeState {
        case selection, qrScan, raceIdEntry, browse, passwordEntry, automaticLoading
    }

    var body: some View {
        ZStack {
            AnimatedWaveBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if mode != .selection && mode != .automaticLoading {
                        Button {
                            withAnimation(.spring()) { mode = .selection }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    Text(titleForCurrentMode)
                        .font(RegattaFont.heroRounded(18))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if mode != .automaticLoading {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 54)
                .padding(.bottom, 12)
                .ignoresSafeArea(edges: .top)
                
                contentForCurrentMode
            }
        }
        .onAppear {
            if initialMode == .automatic {
                mode = .automaticLoading
            }
        }
        .navigationBarHidden(true)
    }
    
    private var titleForCurrentMode: String {
        switch mode {
        case .selection: return "Manual Setup"
        case .qrScan: return "Scan QR Code"
        case .raceIdEntry: return "Enter Race ID"
        case .browse: return "Live Races"
        case .passwordEntry: return "Enter Password"
        case .automaticLoading: return "Automatic Sync"
        }
    }
    
    @ViewBuilder
    private var contentForCurrentMode: some View {
        switch mode {
        case .selection:
            VStack(spacing: 16) {
                ConfigurationTile(icon: "qrcode.viewfinder", title: "Scan QR Code", sub: "Point at the race QR") {
                    withAnimation { mode = .qrScan }
                }
                ConfigurationTile(icon: "number.square.fill", title: "Enter Race ID", sub: "Type the 6-digit code") {
                    withAnimation { mode = .raceIdEntry }
                }
                ConfigurationTile(icon: "list.bullet.rectangle.portrait.fill", title: "Browse Live Races", sub: "Find nearby events") {
                    withAnimation { mode = .browse }
                }
                Spacer()
            }
            .padding(20)
            
        case .qrScan:
            ZStack {
                QRScannerView() { code in
                    // Parse the JSON payload from RegattaPro
                    if let data = code.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let urls = json["urls"] as? [String],
                       let id = json["id"] as? String,
                       let pass = json["pass"] as? String {
                        
                        pingAndResolve(urls: urls, id: id, pass: pass)
                        // End of discovery interception
                    } else {
                        // Fallback logic if it's not JSON
                        DispatchQueue.main.async {
                            self.raceId = code
                            withAnimation { mode = .passwordEntry }
                        }
                    }
                }
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("Point camera at RegattaPro QR Code")
                        .font(RegattaFont.bodyRounded(14))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                }
                
                // Scan Frame Simulation
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cyanAccent, lineWidth: 2)
                    .frame(width: 250, height: 250)
                    .overlay {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 280, weight: .ultraLight))
                            .foregroundColor(.cyanAccent.opacity(0.5))
                    }
            }
            
        case .raceIdEntry:
            VStack(spacing: 30) {
                Spacer().frame(height: 40)
                
                TextField("000000", text: $raceId)
                    .font(RegattaFont.data(64))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .tracking(4)
                
                Button("CONTINUE") {
                    withAnimation { mode = .passwordEntry }
                }
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                .disabled(raceId.count < 4)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            
        case .browse:
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<3) { i in
                        Button {
                            withAnimation { mode = .passwordEntry }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Spring Cup 2026 - Fleet \(i+1)")
                                        .font(RegattaFont.bodyRounded(16))
                                        .foregroundColor(.white)
                                    Text("HELSINGIN PURJEHTIJAT • LIVE")
                                        .font(RegattaFont.mono(10))
                                        .foregroundColor(.cyanAccent)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding()
                            .trueLiquidGlass(cornerRadius: 16)
                        }
                    }
                }
                .padding()
            }
            
        case .passwordEntry:
            VStack(spacing: 30) {
                Spacer().frame(height: 40)
                
                VStack(spacing: 8) {
                    Text("Race Password")
                        .font(RegattaFont.heroRounded(24))
                        .foregroundColor(.white)
                    Text("Ensure this is your unique tracker key")
                        .font(RegattaFont.bodyRounded(14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                SecureField("••••••", text: $password)
                    .font(RegattaFont.data(32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .trueLiquidGlass(cornerRadius: 16)
                    .padding(.horizontal, 40)
                    .tracking(6)
                
                Button("JOIN SESSION") {
                    if let expected = expectedScannedPassword, password != expected {
                        errorMessage = "Invalid password match against QR."
                        return
                    }
                    joinSession()
                }
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.statusError)
                        .font(RegattaFont.mono(12))
                }
                
                Spacer()
            }
            
        case .automaticLoading:
            VStack(spacing: 24) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyanAccent))
                    .scaleEffect(2)
                
                Text("Connecting via your account…")
                    .font(RegattaFont.bodyRounded(16))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            .onAppear {
                if initialMode == .automatic {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        joinSession()
                    }
                }
            }
        }
    }
    
    private func joinSession() {
        isConnecting = true
        connection.joinSession(id: raceId.isEmpty ? "RACE-772" : raceId)
        dismiss()
    }
    
    private func pingAndResolve(urls: [String], id: String, pass: String) {
        // Temporarily render auto-loading layer during fast-ping discovery
        DispatchQueue.main.async {
            self.raceId = id
            self.expectedScannedPassword = pass
            withAnimation { self.mode = .automaticLoading }
        }
        
        let discoveryGroup = DispatchGroup()
        var fastestURL: String? = nil
        let lock = NSLock()
        
        for urlStr in urls {
            discoveryGroup.enter()
            let pingTarget = urlStr.replacingOccurrences(of: "ws://", with: "http://")
                                   .replacingOccurrences(of: "wss://", with: "https://") + "/health"
                                   
            guard let url = URL(string: pingTarget) else {
                discoveryGroup.leave()
                continue
            }
            
            var req = URLRequest(url: url)
            req.timeoutInterval = 1.0 // Rapid termination (USB bridge is instant if available)
            URLSession.shared.dataTask(with: req) { _, response, _ in
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    lock.lock()
                    if fastestURL == nil {
                        fastestURL = urlStr
                    }
                    lock.unlock()
                }
                discoveryGroup.leave()
            }.resume()
        }
        
        discoveryGroup.notify(queue: .main) {
            if let valid = fastestURL {
                UserDefaults.standard.set(valid, forKey: "customWebSocketURL")
                UserDefaults.standard.set(TrackerNetworkMode.customQR.rawValue, forKey: "trackerNetworkMode")
                
                withAnimation { self.mode = .passwordEntry }
            } else {
                self.errorMessage = "Tether Drop: No active network bridged to the Regatta Sidecar."
                withAnimation { self.mode = .selection }
            }
        }
    }
}

struct ConfigurationTile: View {
    let icon: String
    let title: String
    let sub: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyanAccent)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(RegattaFont.heroRounded(16))
                        .foregroundColor(.white)
                    Text(sub)
                        .font(RegattaFont.bodyRounded(12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .frame(height: 80)
            .trueLiquidGlass(cornerRadius: 16)
        }
    }
}
