// ContentView.swift
// WKWebView wrapper for the React frontend.
//
// In development: loads http://localhost:3000 (Vite dev server)
// In production app bundle: loads the built frontend from localhost:3001/app
//
// Features:
// - Native macOS toolbar showing connection mode (LAN/Cloud/Offline)
// - Retry button if the page fails to load (sidecar startup race condition)
// - JavaScript bridge for native features (notifications, haptics, menus)

import SwiftUI
import WebKit
import Combine

struct ContentView: View {
    let url: URL
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var sidecar: SidecarManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var loadError: String?

    var body: some View {
        ZStack {
            WebView(url: url, authManager: authManager, onError: { error in
                loadError = error
            })
            .ignoresSafeArea()

            // Connection status bar (overlaid at top)
            VStack {
                ConnectionStatusBar()
                Spacer()
            }

            // Error overlay with retry
            if let error = loadError {
                LoadErrorOverlay(error: error) {
                    loadError = nil
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Label("Regatta Pro", systemImage: "sailboat.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            ToolbarItem(placement: .status) {
                Text(connection.modeLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            ToolbarItem(placement: .status) {
                if connection.latencyMs > 0 {
                    Text(String(format: "%.0f ms", connection.latencyMs))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// ─── WKWebView representable ──────────────────────────────────────────────────

struct WebView: NSViewRepresentable {
    let url: URL
    let authManager: SupabaseAuthManager
    var onError: ((String) -> Void)?

    private var urlWithJWT: URL {
        var finalURL = url
        if let jwt = authManager.currentJWT {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "jwt", value: jwt))
            components.queryItems = queryItems
            finalURL = components.url ?? url
        }
        return finalURL
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Allow WebSocket connections to localhost (needed for Socket.IO)
        config.limitsNavigationsToAppBoundDomains = false

        // Allow local network access for LAN backend
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Keep web view alive in background (important during race)
        webView.configuration.websiteDataStore = .nonPersistent()

        // Load initial page
        webView.load(URLRequest(url: urlWithJWT))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // URL changes only happen when sidecar restarts — reload
        if nsView.url?.absoluteString.starts(with: url.absoluteString) == false {
            nsView.load(URLRequest(url: urlWithJWT))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onError: ((String) -> Void)?
        init(onError: ((String) -> Void)?) { self.onError = onError }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onError?("Could not load interface: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError?("Interface error: \(error.localizedDescription)")
        }
    }
}

// ─── Connection status bar ────────────────────────────────────────────────────

struct ConnectionStatusBar: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var visible = true

    var body: some View {
        if connection.mode == .offline {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("No connection — data may be stale")
                Spacer()
                Button("Retry") { Task { await connection.evaluateConnectionModePublic() } }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.85))
            .foregroundStyle(.white)
            .font(.system(size: 12, weight: .medium))
        }
    }
}

// ─── Load error overlay ───────────────────────────────────────────────────────

struct LoadErrorOverlay: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.95)
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Interface unavailable")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry") { onRetry() }
                    .controlSize(.large)
            }
        }
    }
}
