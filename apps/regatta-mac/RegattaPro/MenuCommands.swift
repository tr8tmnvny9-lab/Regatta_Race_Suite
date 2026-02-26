// MenuCommands.swift
// Native macOS menu commands for Regatta Pro.
//
// Adds to the standard macOS menu bar:
//   File > New Session
//   File > Export Race Log (PDF / CSV)
//   Session > Start Sequence    ⌘S
//   Session > Abandon           ⌘A
//   Session > General Recall    ⌘R
//   View > Show Log Console
//   View > Toggle Jury Mode
//   Help > About Regatta Pro

import SwiftUI

struct RegattaMenuCommands: Commands {
    var sidecar: SidecarManager
    var connection: ConnectionManager

    var body: some Commands {
        // ── File ──────────────────────────────────────────────────────────────
        CommandGroup(after: .newItem) {
            Button("New Session") {
                // TODO Phase 2: call POST /session via ConnectionManager
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        // ── Session control ───────────────────────────────────────────────────
        CommandMenu("Session") {
            Button("Start Sequence") {
                // emits start-sequence via WKWebView JS bridge
                postToFrontend("regatta:startSequence", payload: [:])
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Abandon Race") {
                postToFrontend("regatta:procedure", payload: ["action": "ABANDON"])
            }
            .keyboardShortcut("a", modifiers: .command)

            Button("General Recall") {
                postToFrontend("regatta:procedure", payload: ["action": "GENERAL_RECALL"])
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Restart Engine") {
                sidecar.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sidecar.start()
                }
            }
        }

        // ── View ──────────────────────────────────────────────────────────────
        CommandMenu("View") {
            Button("Show Log Console") {
                // TODO: open a native NSWindow with sidecar.logs
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Toggle Jury View") {
                // TODO: open a second NSWindow with JuryApp
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
        }
    }

    // ── JS Bridge helper ──────────────────────────────────────────────────────

    private func postToFrontend(_ eventName: String, payload: [String: Any]) {
        // Sends a custom event to the embedded WKWebView
        // The frontend's App.tsx listens for window.addEventListener(eventName, ...)
        let js: String
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonStr = String(data: data, encoding: .utf8) {
            js = "window.dispatchEvent(new CustomEvent('\(eventName)', { detail: \(jsonStr) }))"
        } else {
            js = "window.dispatchEvent(new CustomEvent('\(eventName)'))"
        }
        // NOTE: WKWebView reference needed here — will be injected in Phase 3.3
        // For now this is a placeholder showing the API contract.
        _ = js
    }
}
