// SystemArchitectureView.swift
//
// Live animated topology view of the Regatta Suite data infrastructure.
// Renders nodes (Field, Edge, Cloud, Control layers) as styled cards on
// a dark canvas, with animated "data packet" particles flowing along the
// active connection paths in real-time.
//
// Colour scheme:
//   🟢 Green  — Local Edge path (Nokia SNPN)
//   🔵 Blue   — AWS Cloud path
//   🟠 Orange — Starlink uplink (bidirectional bridge)
//   ⚪ Grey   — Offline / inactive
//
// Architecture mapping mirrors system_integration.md mermaid diagram
// but is dynamic: active/inactive status driven by ConnectionManager.

import SwiftUI
import Combine

// MARK: - Data Model ──────────────────────────────────────────────────────────

enum NodeLayer: String {
    case field   = "Field"
    case edge    = "Edge / Private 5G"
    case cloud   = "AWS Cloud"
    case control = "Command"
    case external = "Broadcast"
}

enum NodeKind {
    case tracker, uwbNode, gnb, edge, backend, stateStore, uwbHub
    case slLink, ubiLink
    case fargate, aurora, kinesis, redis
    case proMac, juryPortal
    case broadcast
}

struct ArchNode: Identifiable {
    let id: String
    let label: String
    let sublabel: String
    let kind: NodeKind
    let layer: NodeLayer
    var position: CGPoint       // in a 1200×700 canvas coordinate space
    var isActive: Bool = true
}

struct ArchEdge: Identifiable {
    let id: String
    let from: String            // ArchNode.id
    let to: String
    let label: String
    let color: Color
    var isActive: Bool = true
    var bidirectional: Bool = true
}

// MARK: - View Model ──────────────────────────────────────────────────────────

@MainActor
final class SystemArchitectureViewModel: ObservableObject {
    @Published var nodes: [ArchNode]
    @Published var edges: [ArchEdge]
    @Published var particles: [DataParticle] = []
    @Published var activeMode: CommandTarget = .localEdge     // synced from CommandTargetManager
    @Published var hoveredNodeId: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private var particleTimer: AnyCancellable?

    init() {
        // ── Node positions designed for a 1200×700 canvas ──────────────────
        nodes = [
            // Field Layer (X=100)
            ArchNode(id: "u1",  label: "UWB Node",    sublabel: "Thunderbolt · 10 Hz",    kind: .uwbNode,    layer: .field,   position: CGPoint(x: 100, y: 150)),
            ArchNode(id: "t1",  label: "Tracker 1",   sublabel: "iOS · UWB + GNSS",       kind: .tracker,    layer: .field,   position: CGPoint(x: 100, y: 300)),
            ArchNode(id: "t2",  label: "Tracker 2",   sublabel: "iOS · Standalone",       kind: .tracker,    layer: .field,   position: CGPoint(x: 100, y: 450)),
            ArchNode(id: "t3",  label: "Tracker 3",   sublabel: "iOS · Standalone",       kind: .tracker,    layer: .field,   position: CGPoint(x: 100, y: 600)),

            // Edge Layer (X=350)
            ArchNode(id: "gnb", label: "Nokia gNB",   sublabel: "AirScale Private 5G",    kind: .gnb,        layer: .edge,    position: CGPoint(x: 350, y: 200)),
            ArchNode(id: "dac", label: "Nokia DAC",   sublabel: "MX Industrial Edge",     kind: .edge,       layer: .edge,    position: CGPoint(x: 350, y: 360)),
            ArchNode(id: "be",  label: "Backend",     sublabel: "RegattaPro · Rust",      kind: .backend,    layer: .edge,    position: CGPoint(x: 350, y: 510)),
            ArchNode(id: "uwh", label: "UWB Hub",     sublabel: "UDP 5555 · OCS Solve",   kind: .uwbHub,     layer: .edge,    position: CGPoint(x: 350, y: 630)),
            ArchNode(id: "sj",  label: "state.json",  sublabel: "Source of Truth",        kind: .stateStore, layer: .edge,    position: CGPoint(x: 500, y: 550)),

            // Uplink Bridge (X=650)
            ArchNode(id: "sl",  label: "Starlink",    sublabel: "High Orbit · Sat",       kind: .slLink,     layer: .edge,    position: CGPoint(x: 650, y: 300)),
            ArchNode(id: "ubi", label: "Ubiquiti Giga",sublabel: "60GHz PTP · Video",     kind: .ubiLink,    layer: .edge,    position: CGPoint(x: 650, y: 500)),

            // Cloud Layer (X=900)
            ArchNode(id: "fg",  label: "Fargate",     sublabel: "RegattaPro CloudVM",     kind: .fargate,    layer: .cloud,   position: CGPoint(x: 900, y: 200)),
            ArchNode(id: "au",  label: "Aurora",      sublabel: "PostgreSQL Serverless",  kind: .aurora,     layer: .cloud,   position: CGPoint(x: 900, y: 340)),
            ArchNode(id: "rd",  label: "ElastiCache", sublabel: "Redis Pub/Sub",          kind: .redis,      layer: .cloud,   position: CGPoint(x: 900, y: 470)),
            ArchNode(id: "s3",  label: "S3 / Kinesis",sublabel: "Media Ingest",           kind: .kinesis,    layer: .cloud,   position: CGPoint(x: 900, y: 600)),

            // Control Layer (X=1100)
            ArchNode(id: "mac", label: "Regatta Pro", sublabel: "macOS Command",          kind: .proMac,     layer: .control, position: CGPoint(x: 1100, y: 240)),
            ArchNode(id: "jry", label: "Juror Portal",sublabel: "S3 Evidence Review",     kind: .juryPortal, layer: .control, position: CGPoint(x: 1100, y: 400)),
            ArchNode(id: "brd", label: "Broadcast",   sublabel: "Web 4K Stream",          kind: .broadcast,  layer: .external,position: CGPoint(x: 1100, y: 560)),
        ]

        edges = [
            // Field connections
            ArchEdge(id: "u1-t1",   from: "u1",  to: "t1",  label: "Thunderbolt",    color: .mint,   isActive: true, bidirectional: false),
            ArchEdge(id: "t1-uwh",  from: "t1",  to: "uwh", label: "UDP Telemetry",  color: .green,  isActive: true),
            
            // Field → Edge (Private 5G)
            ArchEdge(id: "t1-gnb", from: "t1",  to: "gnb", label: "SNPN 5G",        color: .green,  isActive: true),
            ArchEdge(id: "t2-gnb", from: "t2",  to: "gnb", label: "SNPN 5G",        color: .green,  isActive: true),
            ArchEdge(id: "t3-gnb", from: "t3",  to: "gnb", label: "SNPN 5G",        color: .green,  isActive: true),

            // Edge internal
            ArchEdge(id: "gnb-dac", from: "gnb", to: "dac", label: "Local UPF",     color: .green,  isActive: true),
            ArchEdge(id: "dac-be",  from: "dac", to: "be",  label: "Local Bus",      color: .green,  isActive: true),
            ArchEdge(id: "be-sj",   from: "be",  to: "sj",  label: "state sync",     color: .green,  isActive: true),
            ArchEdge(id: "uwh-sj",  from: "uwh", to: "sj",  label: "OCS events",     color: .mint,   isActive: true, bidirectional: false),

            // Uplinks (Edge → Bridge → Cloud)
            ArchEdge(id: "be-sl",   from: "be",  to: "sl",  label: "Starlink",       color: .orange, isActive: true),
            ArchEdge(id: "dac-ubi", from: "dac", to: "ubi", label: "GigaBeam",       color: .cyan,   isActive: true),
            
            ArchEdge(id: "sl-fg",   from: "sl",  to: "fg",  label: "Telemetry",      color: .blue,   isActive: true),
            ArchEdge(id: "ubi-s3",  from: "ubi", to: "s3",  label: "4K Media",       color: .cyan,   isActive: true, bidirectional: false),

            // Cellular Fallback (direct to cloud)
            ArchEdge(id: "t1-fg",  from: "t1",  to: "fg",  label: "5G Fallback",    color: Color(white: 0.5), isActive: false),

            // Cloud internal
            ArchEdge(id: "fg-au",  from: "fg",  to: "au",  label: "Persistence",     color: .blue,   isActive: true),
            ArchEdge(id: "fg-rd",  from: "fg",  to: "rd",  label: "Pub/Sub",         color: .blue,   isActive: true),
            ArchEdge(id: "fg-s3",  from: "fg",  to: "s3",  label: "Video Ops",       color: .blue,   isActive: true, bidirectional: false),

            // Control
            ArchEdge(id: "mac-be", from: "mac", to: "be",  label: "LAN CMD",        color: .green,  isActive: true),
            ArchEdge(id: "mac-fg", from: "mac", to: "fg",  label: "Cloud CMD",      color: .blue,   isActive: true),
            ArchEdge(id: "jry-s3", from: "jry", to: "s3",  label: "Footage",        color: .blue,   isActive: true, bidirectional: false),
            ArchEdge(id: "fg-brd", from: "fg",  to: "brd", label: "4K Feed",         color: .purple, isActive: true, bidirectional: false),
        ]

        // Watch command target changes
        CommandTargetManager.shared.$target
            .sink { [weak self] target in
                self?.updateActiveMode(target)
            }
            .store(in: &cancellables)

        startParticleEngine()
    }

    // ── Mode switch: highlight relevant edges ─────────────────────────────────

    private func updateActiveMode(_ target: CommandTarget) {
        activeMode = target
        // In cloud mode, cellular fallback edges become active; Starlink bridge glows
        let isEdgeMode = (target == .localEdge)
        DispatchQueue.main.async {
            for i in self.edges.indices {
                switch self.edges[i].id {
                case "t1-fg", "t2-fg":
                    self.edges[i].isActive = !isEdgeMode
                case "t1-gnb", "t2-gnb", "t3-gnb", "gnb-dac", "dac-be", "be-sj":
                    self.edges[i].isActive = isEdgeMode
                default:
                    break
                }
            }
        }
    }

    // ── Particle Engine ───────────────────────────────────────────────────────

    private func startParticleEngine() {
        particleTimer = Timer.publish(every: 0.7, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.spawnParticles()
                self?.advanceParticles()
            }
    }

    private func spawnParticles() {
        // Only spawn on active edges
        let active = edges.filter { $0.isActive }
        guard !active.isEmpty else { return }

        // Spawn ~3 particles per tick on random active edges
        for _ in 0..<3 {
            if let edge = active.randomElement() {
                let from = nodes.first { $0.id == edge.from }?.position ?? .zero
                let to   = nodes.first { $0.id == edge.to   }?.position ?? .zero
                let p = DataParticle(id: UUID(), from: from, to: to,
                                     color: edge.color, progress: 0)
                particles.append(p)
            }
        }

        // Cap total
        if particles.count > 80 { particles.removeFirst(particles.count - 80) }
    }

    private func advanceParticles() {
        let speed: Double = 0.06
        particles = particles.compactMap { p in
            var updated = p
            updated.progress += speed
            return updated.progress < 1.0 ? updated : nil
        }
    }

    func nodeById(_ id: String) -> ArchNode? {
        nodes.first { $0.id == id }
    }
}

// MARK: - Particle ─────────────────────────────────────────────────────────────

struct DataParticle: Identifiable {
    let id: UUID
    let from: CGPoint
    let to: CGPoint
    let color: Color
    var progress: Double

    var currentPosition: CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }
}

// MARK: - Main View ────────────────────────────────────────────────────────────

struct SystemArchitectureView: View {
    @StateObject private var vm = SystemArchitectureViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showLegend = true
    private let canvasSize = CGSize(width: 1200, height: 700)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            LinearGradient(
                colors: [Color(white: 0.04), Color(white: 0.08), Color(white: 0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Layer divider bands
            layerBandOverlay

            // Main scrollable canvas
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    // Edges (rendered below nodes)
                    ForEach(vm.edges) { edge in
                        if let from = vm.nodeById(edge.from), let to = vm.nodeById(edge.to) {
                            ArchEdgeView(edge: edge, fromPos: from.position, toPos: to.position)
                        }
                    }

                    // Data particles
                    ForEach(vm.particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: 7, height: 7)
                            .shadow(color: particle.color, radius: 5)
                            .position(particle.currentPosition)
                            .animation(.linear(duration: 0.016), value: particle.progress)
                    }

                    // Nodes
                    ForEach(vm.nodes) { node in
                        ArchNodeView(
                            node: node,
                            isHovered: vm.hoveredNodeId == node.id
                        )
                        .position(node.position)
                        .onHover { hovering in
                            vm.hoveredNodeId = hovering ? node.id : nil
                        }
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
            .scaleEffect(scale)

            // Overlay controls
            VStack(alignment: .leading, spacing: 8) {
                // Title
                HStack(spacing: 10) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Live System Architecture")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Mode badge
                    CommandTargetSelectorView(targetManager: CommandTargetManager.shared)

                    // Zoom controls
                    HStack(spacing: 6) {
                        Button { scale = max(0.5, scale - 0.1) } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        Text(String(format: "%.0f%%", scale * 100))
                            .font(.caption.monospacedDigit())
                        Button { scale = min(2.0, scale + 0.1) } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        Button { scale = 1.0 } label: {
                            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.white.opacity(0.7))

                    // Legend toggle
                    Button {
                        withAnimation { showLegend.toggle() }
                    } label: {
                        Image(systemName: showLegend ? "sidebar.right" : "sidebar.left")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))

                Spacer()

                // Legend
                if showLegend {
                    LegendPanelView(vm: vm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("System Architecture")
    }

    // ── Layer band background stripes ─────────────────────────────────────────

    @ViewBuilder
    private var layerBandOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bands: [(String, Color, CGFloat)] = [
                ("FIELD",      .green,  0.00),
                ("EDGE POD",  .teal,   0.20),
                ("UPLINK",    .orange, 0.45),
                ("AWS CLOUD", .blue,   0.70),
                ("COMMAND",   .purple, 0.88),
            ]
            ForEach(bands, id: \.0) { name, color, xFraction in
                VStack {
                    Text(name)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(color.opacity(0.5))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 14)
                }
                .frame(maxHeight: .infinity)
                .offset(x: w * xFraction)
            }
        }
    }
}

// MARK: - Node View ────────────────────────────────────────────────────────────

struct ArchNodeView: View {
    let node: ArchNode
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 5) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(layerColor)
                .frame(width: 44, height: 44)
                .background(layerColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(layerColor.opacity(isHovered ? 0.9 : 0.35), lineWidth: 1.5)
                )
                .shadow(color: layerColor.opacity(isHovered ? 0.6 : 0.2), radius: isHovered ? 12 : 5)

            // Label
            VStack(spacing: 1) {
                Text(node.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(node.sublabel)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .multilineTextAlignment(.center)
            .frame(width: 90)
        }
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
    }

    private var layerColor: Color {
        switch node.layer {
        case .field:    return .green
        case .edge:     return .teal
        case .cloud:    return .blue
        case .control:  return .purple
        case .external: return .pink
        }
    }

    private var iconName: String {
        switch node.kind {
        case .tracker:    return "iphone"
        case .uwbNode:    return "dot.radiowaves.right"
        case .gnb:        return "antenna.radiowaves.left.and.right"
        case .edge:       return "server.rack"
        case .backend:    return "cpu"
        case .stateStore: return "doc.text.fill"
        case .uwbHub:     return "scope"
        case .slLink:     return "antenna.radiowaves.left.and.right"
        case .ubiLink:    return "beam.tower.fill"
        case .fargate:    return "cloud.fill"
        case .aurora:     return "cylinder.split.1x2.fill"
        case .redis:      return "bolt.horizontal.fill"
        case .kinesis:    return "film.stack.fill"
        case .proMac:     return "desktopcomputer"
        case .juryPortal: return "theatermasks.fill"
        case .broadcast:  return "antenna.radiowaves.left.and.right.slash"
        }
    }
}

// MARK: - Edge View ────────────────────────────────────────────────────────────

struct ArchEdgeView: View {
    let edge: ArchEdge
    let fromPos: CGPoint
    let toPos: CGPoint

    var body: some View {
        let path = edgePath
        ZStack {
            // Glow
            path
                .stroke(edge.color.opacity(edge.isActive ? 0.25 : 0.06),
                        style: StrokeStyle(lineWidth: edge.isActive ? 4 : 2,
                                           dash: edge.bidirectional ? [] : [6, 4]))
                .blur(radius: edge.isActive ? 3 : 0)

            // Core line
            path
                .stroke(edge.color.opacity(edge.isActive ? 0.65 : 0.18),
                        style: StrokeStyle(lineWidth: 1.5,
                                           lineCap: .round,
                                           dash: edge.bidirectional ? [] : [6, 4]))

            // Edge label (centered)
            if edge.isActive {
                Text(edge.label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(edge.color.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .position(midPoint)
                    .offset(y: -10)
            }
        }
    }

    private var edgePath: Path {
        Path { p in
            // Calculate insets to terminate at node edges (node icon is ~44px wide)
            let inset: CGFloat = 32
            let dx = toPos.x - fromPos.x
            let dy = toPos.y - fromPos.y
            let len = sqrt(dx*dx + dy*dy)
            
            guard len > inset * 2 else {
                p.move(to: fromPos)
                p.addLine(to: toPos)
                return
            }
            
            let start = CGPoint(x: fromPos.x + (dx/len) * inset, y: fromPos.y + (dy/len) * inset)
            let end = CGPoint(x: toPos.x - (dx/len) * inset, y: toPos.y - (dy/len) * inset)
            
            p.move(to: start)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 15)
            p.addQuadCurve(to: end, control: mid)
        }
    }

    private var midPoint: CGPoint {
        let dx = toPos.x - fromPos.x
        let dy = toPos.y - fromPos.y
        return CGPoint(x: fromPos.x + dx/2, y: fromPos.y + dy/2 - 15)
    }
}

// MARK: - Legend ───────────────────────────────────────────────────────────────

struct LegendPanelView: View {
    @ObservedObject var vm: SystemArchitectureViewModel

    private let layers: [(String, Color)] = [
        ("Field Layer",         .green),
        ("Nokia Edge / SNPN",   .teal),
        ("AWS Cloud",           .blue),
        ("Command & Control",   .purple),
    ]

    private let linkTypes: [(String, Color, Bool)] = [
        ("Private 5G (SNPN)",   .green,  true),
        ("Starlink Bridge",     .orange, true),
        ("Ubiquiti GigaBeam",   .cyan,   true),
        ("AWS Cloud Path",      .blue,   true),
        ("Cellular Fallback",   Color(white: 0.5), false),
        ("UWB Thunderbolt",     .mint,   false),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // Node layers
            VStack(alignment: .leading, spacing: 6) {
                Text("LAYERS").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.4))
                ForEach(layers, id: \.0) { name, color in
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Divider().frame(height: 80).opacity(0.2)

            // Link types
            VStack(alignment: .leading, spacing: 6) {
                Text("CONNECTIONS").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.4))
                ForEach(linkTypes, id: \.0) { name, color, biDir in
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(color)
                            .frame(width: 20, height: 2)
                        if !biDir {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7))
                                .foregroundStyle(color)
                        }
                        Text(name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Divider().frame(height: 80).opacity(0.2)

            // Live stats
            VStack(alignment: .leading, spacing: 6) {
                Text("LIVE").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.4))
                LiveStatRow(label: "Active Edges", value: "\(vm.edges.filter { $0.isActive }.count) / \(vm.edges.count)")
                LiveStatRow(label: "Data Packets",  value: "\(vm.particles.count)")
                LiveStatRow(label: "Command Target", value: vm.activeMode.displayName)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding([.horizontal, .bottom], 16)
    }
}

struct LiveStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
