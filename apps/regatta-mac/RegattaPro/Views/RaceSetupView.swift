// RaceSetupView.swift
// Post-login race selection/creation screen — Liquid Glass aesthetic.

import SwiftUI

struct RaceSetupView: View {
    @EnvironmentObject var presetManager: RacePresetManager
    @EnvironmentObject var raceState: RaceStateModel
    
    @State private var editingName: String?
    @State private var showDeleteConfirm: String? = nil
    @State private var hoverPresetId: String? = nil
    @State private var logoScale: CGFloat = 0.6
    @State private var headerOpacity: Double = 0
    
    private var allPresets: [RacePreset] {
        // Demo is always first, followed by user presets sorted by modifiedAt
        let demo = RacePresetManager.finnishSailingDemo()
        let userPresets = presetManager.presets.filter { !$0.isDemo }
        return [demo] + userPresets
    }
    
    var body: some View {
        ZStack {
            // Background
            AnimatedWaveBackground()
            
            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 16) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.6), radius: 20)
                        .scaleEffect(logoScale)
                    
                    Text("REGATTA PRO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(8)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Select or Create a Race")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                .opacity(headerOpacity)
                
                // ── Content ─────────────────────────────────────────────
                HStack(spacing: 32) {
                    // Left: Preset Cards
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(allPresets) { preset in
                                PresetCard(
                                    preset: preset,
                                    isHovered: hoverPresetId == preset.id,
                                    onSelect: { selectPreset(preset) },
                                    onDelete: preset.isDemo ? nil : { showDeleteConfirm = preset.id }
                                )
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoverPresetId = hovering ? preset.id : nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right: Quick Actions Panel
                    VStack(spacing: 20) {
                        // New Race
                        QuickActionButton(
                            title: "New Race",
                            subtitle: "Start with an empty canvas",
                            icon: "plus.circle.fill",
                            gradient: LinearGradient(
                                colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.02, green: 0.71, blue: 0.83)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            createNewRace()
                        }
                        
                        // Load Demo
                        QuickActionButton(
                            title: "Finnish Sailing Demo",
                            subtitle: "Pre-configured Helsinki WL course",
                            icon: "flag.checkered",
                            gradient: LinearGradient(
                                colors: [Color(red: 0.96, green: 0.61, blue: 0.07), Color(red: 0.86, green: 0.11, blue: 0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            selectPreset(RacePresetManager.finnishSailingDemo())
                        }
                        
                        Spacer()
                        
                        // Info Badge
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.cyan)
                                Text("RACE PRESETS")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Text("Races auto-save as you work. Course, wind, fleet, and procedures are all preserved.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .frame(width: 320)
                }
                .padding(.horizontal, 48)
                .frame(maxHeight: .infinity)
                
                Spacer(minLength: 40)
            }
        }
        .alert("Delete Race?", isPresented: .init(get: { showDeleteConfirm != nil }, set: { if !$0 { showDeleteConfirm = nil } })) {
            Button("Delete", role: .destructive) {
                if let id = showDeleteConfirm, let preset = presetManager.presets.first(where: { $0.id == id }) {
                    presetManager.delete(preset)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This race preset will be permanently deleted.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                headerOpacity = 1.0
            }
        }
    }
    
    private func selectPreset(_ preset: RacePreset) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presetManager.activate(preset, into: raceState)
        }
    }
    
    private func createNewRace() {
        let preset = presetManager.createNew()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presetManager.activate(preset, into: raceState)
        }
    }
}

// ─── Preset Card ────────────────────────────────────────────────────────────

struct PresetCard: View {
    let preset: RacePreset
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(preset.isDemo ?
                              LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: preset.isDemo ? "star.fill" : "sailboat.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(preset.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if preset.isDemo {
                            Text("DEMO")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(preset.courseSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    HStack(spacing: 12) {
                        Label("\(Int(preset.windSpeed)) kts", systemImage: "wind")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.7))
                        
                        Label("\(Int(preset.windDirection))°", systemImage: "location.north.line.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.7))
                        
                        if let teams = preset.leagueTeams, !teams.isEmpty {
                            Label("\(teams.count) teams", systemImage: "person.3")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                // Time
                VStack(alignment: .trailing, spacing: 4) {
                    if !preset.isDemo {
                        Text(preset.modifiedAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                // Delete
                if let deleteAction = onDelete {
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.6))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: isHovered ? .cyan.opacity(0.2) : .clear, radius: 15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isHovered ? Color.cyan.opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: isHovered ? 2 : 1
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// ─── Quick Action Button ────────────────────────────────────────────────────

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(gradient)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovered ? .cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: isHovered ? .cyan.opacity(0.15) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .onHover { hov in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hov }
        }
    }
}
