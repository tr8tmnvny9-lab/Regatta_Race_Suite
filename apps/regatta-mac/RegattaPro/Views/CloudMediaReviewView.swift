// CloudMediaReviewView.swift
//
// Phase 4 — AWS Cloud Media Review Portal for Race Jurors.
// Fetches archived Kinesis Video streams from Amazon S3, served
// via signed CloudFront URLs synced with the race state.json timeline.
//
// Evidence workflow:
// 1. PRO flags an incident from the race timeline
// 2. This view fetches the signed S3/CloudFront URL from the Fargate backend
// 3. AVPlayer plays back the archived video at the correct timestamp
// 4. The race state overlay shows position data synced to the video time

import SwiftUI
import AVKit
import Combine

// ─── Models ───────────────────────────────────────────────────────────────────

struct ArchivedStream: Identifiable, Codable {
    let id: String          // boat tracker ID
    let boatName: String
    let streamURL: URL      // signed CloudFront URL
    let startTimestamp: Date
    let durationSeconds: Double
    let boatNumber: String
}

struct MediaReviewRequest: Codable {
    let sessionId: String
    let incidentTimestamp: Double   // unix epoch ms
    let boatIds: [String]
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

@MainActor
final class CloudMediaReviewViewModel: ObservableObject {
    @Published var streams: [ArchivedStream] = []
    @Published var selectedStream: ArchivedStream?
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var incidentTimestamp: Date = Date()

    private let targetManager: CommandTargetManager

    init(targetManager: CommandTargetManager) {
        self.targetManager = targetManager
    }

    // ─── Fetch archived streams from backend ──────────────────────────────────

    func fetchArchivedStreams(sessionId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let baseURL = targetManager.targetURL
            var urlComponents = URLComponents(
                url: baseURL.appendingPathComponent("api/media/sessions/\(sessionId)/streams"),
                resolvingAgainstBaseURL: true
            )!
            urlComponents.queryItems = [
                URLQueryItem(name: "incident_ts", value: String(incidentTimestamp.timeIntervalSince1970 * 1000))
            ]

            var request = URLRequest(url: urlComponents.url!)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Attach JWT for IAM authorization
            if let jwt = UserDefaults.standard.string(forKey: "authJWT") {
                request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                errorMessage = "Server returned \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            streams = try decoder.decode([ArchivedStream].self, from: data)

            // Auto-select first stream
            if let first = streams.first {
                selectStream(first)
            }
        } catch {
            errorMessage = "Failed to load streams: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // ─── Select and play a stream ─────────────────────────────────────────────

    func selectStream(_ stream: ArchivedStream) {
        selectedStream = stream
        player = AVPlayer(url: stream.streamURL)
        // Seek to the incident point within the stream
        let offset = max(0, incidentTimestamp.timeIntervalSince(stream.startTimestamp) - 10)
        player?.seek(to: CMTime(seconds: offset, preferredTimescale: 600))
        player?.play()
    }
}

// ─── View ─────────────────────────────────────────────────────────────────────

struct CloudMediaReviewView: View {
    @StateObject private var vm: CloudMediaReviewViewModel
    @State private var sessionId: String = ""
    @State private var showingDatePicker = false

    init(targetManager: CommandTargetManager) {
        _vm = StateObject(wrappedValue: CloudMediaReviewViewModel(targetManager: targetManager))
    }

    var body: some View {
        HSplitView {
            // ── Left Panel: Stream List ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Label("Cloud Media Review", systemImage: "film.stack")
                        .font(.title3.bold())

                    HStack {
                        TextField("Session ID", text: $sessionId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))

                        Button {
                            Task { await vm.fetchArchivedStreams(sessionId: sessionId) }
                        } label: {
                            Image(systemName: "arrow.2.circlepath")
                        }
                        .disabled(sessionId.isEmpty || vm.isLoading)
                    }

                    // Incident timestamp picker
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        DatePicker("Incident", selection: $vm.incidentTimestamp)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        Spacer()
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.25))

                Divider()

                // Stream list
                if vm.isLoading {
                    Spacer()
                    ProgressView("Fetching archived streams…")
                    Spacer()
                } else if let err = vm.errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if vm.streams.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No archived streams.\nEnter a Session ID and fetch.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(vm.streams, selection: Binding(
                        get: { vm.selectedStream?.id },
                        set: { id in
                            if let stream = vm.streams.first(where: { $0.id == id }) {
                                vm.selectStream(stream)
                            }
                        }
                    )) { stream in
                        StreamRowView(stream: stream,
                                      isSelected: vm.selectedStream?.id == stream.id)
                            .tag(stream.id)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 240, maxWidth: 300)

            // ── Right Panel: Video Player ──────────────────────────────────────
            VStack(spacing: 0) {
                if let player = vm.player {
                    VideoPlayer(player: player)
                        .background(Color.black)

                    // Evidence overlay bar
                    if let stream = vm.selectedStream {
                        EvidenceInfoBar(stream: stream, incidentTime: vm.incidentTimestamp)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a stream from the list to begin review")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.5))
                }
            }
        }
    }
}

// ─── Subcomponents ────────────────────────────────────────────────────────────

private struct StreamRowView: View {
    let stream: ArchivedStream
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(stream.boatNumber)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stream.boatName)
                    .font(.system(size: 12, weight: .semibold))
                Text(String(format: "%.0fs archived", stream.durationSeconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "video.fill")
                .font(.caption)
                .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EvidenceInfoBar: View {
    let stream: ArchivedStream
    let incidentTime: Date

    private var offsetSeconds: Double {
        max(0, incidentTime.timeIntervalSince(stream.startTimestamp))
    }

    var body: some View {
        HStack(spacing: 16) {
            Label(stream.boatName, systemImage: "sailboat.fill")
                .font(.system(size: 11, weight: .bold))

            Divider().frame(height: 14)

            Label("Incident T+\(Int(offsetSeconds))s", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)

            Spacer()

            Label("S3 Archive", systemImage: "externaldrive.fill.badge.checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }
}
