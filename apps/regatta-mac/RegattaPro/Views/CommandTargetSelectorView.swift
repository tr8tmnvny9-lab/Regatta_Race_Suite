// CommandTargetSelectorView.swift
//
// Phase 4 — The PRO's Source of Truth toggle.
// Displays in the top toolbar of Regatta Pro, giving a clear and
// unambiguous visual indication of where commands are being sent.
// A mis-selection here would mean commanding the wrong system on the water.

import SwiftUI

struct CommandTargetSelectorView: View {
    @ObservedObject var targetManager: CommandTargetManager
    @State private var showingConfig = false

    var body: some View {
        HStack(spacing: 6) {
            // Mode indicator badge
            Image(systemName: targetManager.target.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(badgeColor)

            Text(targetManager.target.displayName.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(badgeColor)

            // Toggle button
            Menu {
                ForEach(CommandTarget.allCases, id: \.self) { target in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            targetManager.switchTarget(to: target)
                        }
                    } label: {
                        Label(target.displayName, systemImage: target.icon)
                        if targetManager.target == target {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                Button("Configure Endpoints…") {
                    showingConfig = true
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor.opacity(0.15))
        .overlay(
            Capsule().stroke(badgeColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
        .sheet(isPresented: $showingConfig) {
            CommandTargetConfigSheet(targetManager: targetManager)
        }
    }

    private var badgeColor: Color {
        switch targetManager.target {
        case .localEdge:  return .green
        case .awsCloudVM: return .blue
        }
    }
}

// ─── Configuration Sheet ─────────────────────────────────────────────────────

private struct CommandTargetConfigSheet: View {
    @ObservedObject var targetManager: CommandTargetManager
    @Environment(\.dismiss) var dismiss

    @State private var localHost = UserDefaults.standard.string(forKey: "localEdgeHost") ?? "localhost"
    @State private var awsURL = UserDefaults.standard.string(forKey: "awsCloudVMURL") ?? "https://regatta-backend.fly.dev"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Backend Endpoints")
                .font(.title2.bold())

            Divider()

            Group {
                Label("Local Edge (Nokia SNPN)", systemImage: "network")
                    .font(.headline)
                    .foregroundStyle(.green)

                HStack {
                    Text("Host:")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    TextField("e.g. 192.168.100.1", text: $localHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            Divider()

            Group {
                Label("AWS CloudVM (Fargate)", systemImage: "cloud.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                HStack {
                    Text("URL:")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    TextField("https://…", text: $awsURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    targetManager.setLocalEdgeHost(localHost)
                    targetManager.setAWSCloudVMURL(awsURL)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 300)
    }
}
