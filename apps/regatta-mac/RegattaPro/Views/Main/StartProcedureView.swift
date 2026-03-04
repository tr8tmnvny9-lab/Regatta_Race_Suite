import SwiftUI
import CoreLocation
import MapKit

enum ProcedureAction: String {
    case warning = "WARNING"
    case prep = "PREP"
    case start = "START"
    case finish = "FINISH"
    case ap = "AP UP"
    case apDown = "AP DOWN"
    case recall = "GEN RECALL"
    case recallX = "X FLAG"
    case abandon = "ABANDON"
    case shorten = "SHORTEN"
    case changeCourse = "CHG COURSE"
}

struct StartProcedureView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel

    @State private var pendingAction: ProcedureAction? = nil
    @State private var cameraMode: Int = 0

    var body: some View {
        ZStack {
            // No opaque background. Let the global TacticalMapView show through.
            
            // ─── Top Center: Camera Toolbar ──────────────────────────────────
            VStack {
                StartCenterToolbarView(cameraMode: $cameraMode)
                    .padding(.top, 20)
                Spacer()
            }
            .zIndex(1)
            
            VStack(spacing: 0) {
                // ─── Side Panels (Top 80% minus bottom bar) ───────────────
                HStack(spacing: 0) {
                    // Left Column (Timeline & Clock)
                    StartLeftColumnView(
                        timeRemaining: raceState.timeRemaining,
                        status: raceState.status,
                        activeFlags: raceState.activeFlags,
                        procedureNodes: raceState.activeProcedureNodes,
                        currentNodeId: raceState.currentNodeId
                    )
                        .frame(width: 380)
                        .glassPanel()
                        .padding(.leading, 20)
                        .padding(.top, 80) // Leave room for top toolbar
                    
                    Spacer() // This exposes the map in the center
                    
                    // Right Column (Aux)
                    StartRightAuxView()
                        .frame(width: 280)
                        .glassPanel()
                        .padding(.trailing, 20)
                        .padding(.top, 80)
                }
                .allowsHitTesting(true)
                
                // Flexible spacer to push the bottom deck down but prevent overlap
                Spacer().frame(minHeight: 20)
                
                // ─── Bottom Command Deck ──────────────────────────────────────────
                StartCommandDeckView(pendingAction: $pendingAction)
                    .frame(height: 140)
                    .glassPanel()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .allowsHitTesting(true)
            }
        }
    }
}

// ─── Component: Command Deck (Liquid Glass) ──────────────────────────────────

struct StartCommandDeckView: View {
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var raceState: RaceStateModel
    @Binding var pendingAction: ProcedureAction?
    
    /// True if we are within the first 5 seconds of the start gun
    private var inRecallWindow: Bool {
        guard raceState.status == .racing,
              let t = raceState.raceStartTime else { return false }
        return Date().timeIntervalSince(t) <= 5
    }
    
    /// Pre‑race: status is IDLE, WARNING, PREP, or ONE‑MINUTE — AP is legal
    private var canAP: Bool {
        switch raceState.status {
        case .idle, .warning, .preparatory, .oneMinute: return true
        default: return false
        }
    }
    
    /// Recall (general or individual X) only legal at start moment OR within first 5s of racing
    private var canRecall: Bool {
        return inRecallWindow
    }
    
    /// Shorten / Change course — only when racing is underway (not in recall window)
    private var canAlterCourse: Bool {
        return raceState.status == .racing && !inRecallWindow
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // ─── Left Third: Procedure Sequence Buttons ─────────────────────
            HStack(spacing: 16) {
                if raceState.status == .idle || raceState.status == .warning {
                    LiquidGlassButton(title: "WARNING", subtitle: "5 MIN", color: .green, isPressed: pendingAction == .warning) {
                        pendingAction = .warning
                    }
                }
                if raceState.status == .warning {
                    LiquidGlassButton(title: "PREP", subtitle: "4 MIN", color: .yellow, isPressed: pendingAction == .prep) {
                        pendingAction = .prep
                    }
                }
                if raceState.status == .oneMinute {
                    LiquidGlassButton(title: "START", subtitle: "0 MIN", color: RegattaDesign.Colors.electricBlue, isPressed: pendingAction == .start) {
                        pendingAction = .start
                    }
                }
                // Finish button always visible when racing
                if raceState.status == .racing {
                    LiquidGlassButton(title: "FINISH", subtitle: "End Race", color: .green, isPressed: pendingAction == .finish) {
                        pendingAction = .finish
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // ─── Center: Confirmation Core ──────────────────────────────────
            VStack {
                if let action = pendingAction {
                    Text("READY TO EXECUTE: \(action.rawValue)")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.yellow)
                    
                    Button(action: {
                        execute(action)
                        pendingAction = nil
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: .orange.opacity(0.5), radius: 10)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5), lineWidth: 1))
                            
                            VStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                                    .frame(height: 20)
                                    .padding(2)
                                Spacer()
                            }
                            
                            Text("CONFIRM")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: 300, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("SELECT ACTION")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white.opacity(0.1))
                        .frame(maxWidth: 300, maxHeight: .infinity)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.05), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            
            // ─── Right Third: RRS Overrides ─────────────────────────────────
            HStack(spacing: 12) {
                // AP — legal during pre-race only
                if canAP {
                    LiquidGlassButton(title: "AP UP", subtitle: "Postpone", color: .red, isPressed: pendingAction == .ap) {
                        pendingAction = .ap
                    }
                }
                // AP DOWN — shown when race is postponed
                if raceState.status == .postponed {
                    LiquidGlassButton(title: "AP DOWN", subtitle: "Resume", color: .orange, isPressed: pendingAction == .apDown) {
                        pendingAction = .apDown
                    }
                }
                // Individual Recall X — first 5s of racing only
                if canRecall {
                    LiquidGlassButton(title: "X FLAG", subtitle: "Ind. Recall", color: RegattaDesign.Colors.cyan, isPressed: pendingAction == .recallX) {
                        pendingAction = .recallX
                    }
                    LiquidGlassButton(title: "GEN RECALL", subtitle: "1st Sub", color: .orange, isPressed: pendingAction == .recall) {
                        pendingAction = .recall
                    }
                }
                // Shorten Course / Change Course — racing only, outside recall window
                if canAlterCourse {
                    LiquidGlassButton(title: "SHORTEN", subtitle: "S Flag", color: .blue, isPressed: pendingAction == .shorten) {
                        pendingAction = .shorten
                    }
                    LiquidGlassButton(title: "CHG COURSE", subtitle: "C Flag", color: .green, isPressed: pendingAction == .changeCourse) {
                        pendingAction = .changeCourse
                    }
                }
                // Abandon — always available
                LiquidGlassButton(title: "ABANDON", subtitle: "Cancel Race", color: RegattaDesign.Colors.crimson, isPressed: pendingAction == .abandon) {
                    pendingAction = .abandon
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private func execute(_ action: ProcedureAction) {
        switch action {
        case .warning:    raceEngine.setRaceStatus(.warning)
        case .prep:       raceEngine.setRaceStatus(.preparatory)
        case .start:      raceEngine.setRaceStatus(.racing)
        case .finish:     raceEngine.setRaceStatus(.finished)
        case .ap:         raceEngine.setRaceStatus(.postponed)
        case .apDown:     raceEngine.setRaceStatus(.idle)         // AP down → IDLE, engine auto-starts 1-min warning timer via backend
        case .recall:     raceEngine.setRaceStatus(.generalRecall)
        case .recallX:    raceEngine.setRaceStatus(.individualRecall)
        case .abandon:    raceEngine.setRaceStatus(.abandoned)
        case .shorten:    raceEngine.setRaceStatus(.shortenCourse)
        case .changeCourse: raceEngine.setRaceStatus(.changeCourse)
        }
    }
}

// ─── Component: Liquid Glass Button ──────────────────────────────────────────

struct LiquidGlassButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let isPressed: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPressed ? color.opacity(0.3) : (isHovering ? color.opacity(0.15) : color.opacity(0.05)))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isPressed {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.8), lineWidth: 2)
                        .shadow(color: color.opacity(0.6), radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                }
                
                VStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(height: 15)
                        .padding(2)
                    Spacer()
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(isPressed ? .white : color)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isPressed ? .white.opacity(0.9) : color.opacity(0.7))
                }
            }
            .scaleEffect(isPressed ? 0.96 : (isHovering ? 1.02 : 1.0))
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover
        }
    }
}

// ─── Component: Left Column (Timeline & Clock) ───────────────────────────────

struct StartLeftColumnView: View {
    let timeRemaining: Double
    let status: RaceStatus
    let activeFlags: [String]
    let procedureNodes: [BackendProcedureNode]
    let currentNodeId: String?
    
    private var phaseColor: Color {
        switch status {
        case .idle: return .gray
        case .warning, .preparatory, .oneMinute: return .yellow
        case .racing: return .green
        case .finished: return .blue
        case .postponed, .abandoned: return RegattaDesign.Colors.crimson
        default: return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 30) {
                Spacer()
                
                HStack {
                    Circle()
                        .fill(phaseColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: phaseColor, radius: 4)
                    Text(status.rawValue.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(phaseColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(phaseColor.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(phaseColor.opacity(0.3), lineWidth: 1))
                
                VStack(spacing: -5) {
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 100, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    
                    Text("T-MINUS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(8)
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                VStack(spacing: 12) {
                    Text("HOISTED FLAGS")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(spacing: 20) {
                        if activeFlags.isEmpty {
                            Text("NO FLAGS")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeFlags, id: \.self) { flag in
                                FlagView(name: flag)
                            }
                        }
                    }
                    .frame(height: 60)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PROCEDURE TIMELINE")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    if !procedureNodes.isEmpty {
                        Text("\(procedureNodes.count) STEPS")
                            .font(RegattaDesign.Fonts.label)
                            .foregroundStyle(RegattaDesign.Colors.cyan.opacity(0.7))
                    }
                }
                .padding(.horizontal, 30)
                
                if procedureNodes.isEmpty {
                    MilestoneTimelineView(currentTime: timeRemaining)
                        .frame(height: 80)
                        .padding(.horizontal, 30)
                } else {
                    LiveProcedureTimelineView(
                        nodes: procedureNodes,
                        currentNodeId: currentNodeId,
                        timeRemaining: timeRemaining
                    )
                    .frame(height: 80)
                    .padding(.horizontal, 30)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(abs(seconds)))
        let m = s / 60
        let rem = s % 60
        let sign = seconds < 0 ? "+" : ""
        return String(format: "%@%d:%02d", sign, m, rem)
    }
}

// ─── Component: Horizontal Milestone Timeline ────────────────────────────────

struct MilestoneTimelineView: View {
    let currentTime: Double
    private let milestones: [(Double, String, String)] = [
        (300, "5M", "Warning"), 
        (240, "4M", "Prep"), 
        (60, "1M", "One Min"), 
        (0, "0M", "Start")
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 2)
                    .offset(y: 10)
                
                let totalTime: Double = 300
                let clampedTime = max(0, min(totalTime, currentTime))
                let progressX = geo.size.width * CGFloat(1 - (clampedTime / totalTime))
                
                Rectangle()
                    .fill(RegattaDesign.Colors.cyan)
                    .frame(width: max(0, progressX), height: 4)
                    .offset(y: 10)
                    .shadow(color: RegattaDesign.Colors.cyan.opacity(0.5), radius: 4)
                
                ForEach(milestones, id: \.0) { time, label, sub in
                    let isPassed = currentTime <= time
                    let x = geo.size.width * CGFloat(1 - (time / totalTime))
                    
                    VStack(spacing: 6) {
                        Text(sub)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isPassed ? .white : .white.opacity(0.3))
                        
                        Circle()
                            .fill(isPassed ? RegattaDesign.Colors.cyan : .white.opacity(0.2))
                            .frame(width: isPassed ? 10 : 6, height: isPassed ? 10 : 6)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        
                        Text(label)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(isPassed ? .white : .white.opacity(0.3))
                    }
                    .position(x: x, y: 12)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// ─── Component: Live Architect-Driven Procedure Timeline ──────────────────────

struct LiveProcedureTimelineView: View {
    let nodes: [BackendProcedureNode]
    let currentNodeId: String?
    let timeRemaining: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track line
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: 30)
                
                // Progress fill
                if let currentIdx = nodes.firstIndex(where: { $0.id == currentNodeId }) {
                    let totalNodes = max(1, nodes.count - 1)
                    let progress = CGFloat(currentIdx) / CGFloat(totalNodes)
                    Rectangle()
                        .fill(RegattaDesign.Colors.cyan)
                        .frame(width: geo.size.width * progress, height: 4)
                        .offset(y: 30)
                        .shadow(color: RegattaDesign.Colors.cyan.opacity(0.5), radius: 4)
                }
                
                let totalNodes = max(1, nodes.count - 1)
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let isActive = node.id == currentNodeId
                    let isPast = isNodePast(index: index)
                    let rawX = geo.size.width * CGFloat(index) / CGFloat(totalNodes)
                    let x = min(max(rawX, 10), geo.size.width - 10)
                    
                    VStack(spacing: 4) {
                        Text(node.label)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(isActive ? .white : (isPast ? RegattaDesign.Colors.cyan.opacity(0.5) : .white.opacity(0.3)))
                            .lineLimit(1)
                        
                        ZStack {
                            Circle()
                                .fill(isActive ? RegattaDesign.Colors.cyan : (isPast ? RegattaDesign.Colors.cyan.opacity(0.4) : .white.opacity(0.15)))
                                .frame(width: isActive ? 14 : 8, height: isActive ? 14 : 8)
                            if isActive {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                    .opacity(0.4)
                            }
                        }
                        
                        if node.waitForUserTrigger {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 7))
                                .foregroundStyle(isActive ? .yellow : .secondary)
                        } else if node.duration > 0 {
                            Text(formatDuration(node.duration))
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(isActive ? RegattaDesign.Colors.cyan : .secondary)
                        }
                    }
                    .position(x: x, y: 35)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    private func isNodePast(index: Int) -> Bool {
        guard let currentNodeId,
              let currentIndex = nodes.firstIndex(where: { $0.id == currentNodeId }) else {
            return false
        }
        return index < currentIndex
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s == 0 { return "AUTO" }
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m"
    }
}

// ─── Component: Center Map Toolbar ───────────────────────────────────────────

struct StartCenterToolbarView: View {
    @Binding var cameraMode: Int
    
    var body: some View {
        HStack {
            Image(systemName: "flag.checkered")
                .font(.system(size: 16))
                .foregroundStyle(RegattaDesign.Colors.cyan)
            
            Text("MISSION CONTROL")
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(RegattaDesign.Colors.cyan)
                .tracking(2)
            
            Spacer()
            
            Picker("Camera Mode", selection: $cameraMode) {
                Text("Course Locked").tag(0)
                Text("Fleet Follow").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassPanel()
        .frame(width: 600)
    }
}

// ─── Component: Right Auxiliary Panel ────────────────────────────────────────

struct StartRightAuxView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AUXILIARY")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(RegattaDesign.Colors.electricBlue)
                Spacer()
            }
            .padding(20)
            
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "book.pages")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                
                Text("Rules Book &\nDocuments")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                Button("Open Archive") {}
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.1))
                    .foregroundStyle(.white)
            }
            
            Spacer()
        }
    }
}

// ─── Support: Flag Component ─────────────────────────────────────────────────

struct FlagView: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(flagColor)
                    .frame(width: 40, height: 25)
                    .shadow(radius: 2)
                    .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 1))
                
                if name == "P" {
                    Rectangle().fill(.white).frame(width: 12, height: 8)
                } else if name == "X" {
                    Rectangle().fill(.white).frame(width: 40, height: 3)
                    Rectangle().fill(.white).frame(width: 3, height: 25)
                }
            }
            
            Text(name)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
        }
    }
    
    private var flagColor: Color {
        switch name {
        case "P", "X": return .blue
        case "L": return .yellow
        case "U": return .red
        default: return .white
        }
    }
}
