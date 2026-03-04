import SwiftUI

struct ProcedureArchitectView: View {
    @StateObject private var model = ProcedureArchitectModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var raceEngine: RaceEngineClient
    
    // Quick reference for RRS flags
    let availableFlags = ["CLASS", "P", "I", "Z", "U", "BLACK", "AP", "N", "X", "FIRST_SUB", "S", "L", "ORANGE"]
    
    var body: some View {
        ZStack {
            // Dark Dimmer Background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            HStack(spacing: 24) {
                // ─── Main Area (Left 2/3): Step Pipeline ───
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PROCEDURE ARCHITECT")
                                .font(RegattaDesign.Fonts.label)
                                .tracking(4)
                                .foregroundStyle(RegattaDesign.Colors.cyan)
                            Text("Sequence Builder")
                                .font(.title)
                                .fontWeight(.black)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                        
                        Toggle("Auto Restart (Rolling)", isOn: $model.autoRestart)
                            .toggleStyle(SwitchToggleStyle(tint: RegattaDesign.Colors.electricBlue))
                            .padding(.trailing, 10)
                        
                        Button(action: { model.addStep() }) {
                            Label("Add Step", systemImage: "plus")
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(RegattaDesign.Colors.electricBlue.opacity(0.2))
                                .foregroundStyle(RegattaDesign.Colors.electricBlue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: deployProcedure) {
                            Label("Deploy", systemImage: "paperplane.fill")
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(RegattaDesign.Gradients.primary)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Pipeline List
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        
                        if model.steps.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.inset.filled.and.person.filled")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("Pipeline Empty")
                                    .font(.headline)
                                Text("Add a step or click a Template from the vault.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            List {
                                ForEach($model.steps) { $step in
                                    ProcedureStepCard(step: $step, availableFlags: availableFlags, onDelete: {
                                        model.removeStep(id: step.id)
                                    }, onDuplicate: {
                                        model.duplicateStep(id: step.id)
                                    })
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                                .onMove { indices, newOffset in
                                    model.moveStep(from: indices, to: newOffset)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // ─── Right Sidebar (Right 1/3) ───
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                    
                    // Templates Vault
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TEMPLATES VAULT")
                            .font(RegattaDesign.Fonts.label)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        
                        ArchitectTemplateButton(title: "Standard 5-Min", icon: "timer", color: .blue) {
                            loadStandard5Min()
                        }
                        
                        ArchitectTemplateButton(title: "Short Course 3-Min", icon: "timer.square", color: .orange) {
                            loadShortCourse3Min()
                        }
                        
                        ArchitectTemplateButton(title: "League UF (Umpired)", icon: "flag.checkered", color: .green) {
                            loadLeagueUF()
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    
                    // Global Overrides & Interrupts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GLOBAL OVERRIDES & INTERRUPTS")
                            .font(RegattaDesign.Fonts.label)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        
                        ArchitectActionButton(title: "Postponement (AP)", icon: "flag.fill", color: .red) {
                            triggerOverride(action: .postponed)
                        }
                        
                        ArchitectActionButton(title: "Abandonment (N)", icon: "flag.slash.fill", color: RegattaDesign.Colors.crimson) {
                            triggerOverride(action: .abandoned)
                        }
                        
                        ArchitectActionButton(title: "General Recall", icon: "arrow.counterclockwise", color: .orange) {
                            triggerOverride(action: .generalRecall)
                        }
                        
                        ArchitectActionButton(title: "Individual Recall (X)", icon: "person.crop.circle.badge.xmark", color: RegattaDesign.Colors.cyan) {
                            triggerOverride(action: .individualRecall)
                        }
                        
                        ArchitectActionButton(title: "Shorten Course (S)", icon: "scissors", color: .blue) {
                            triggerOverride(action: .shortenCourse)
                        }
                        
                        ArchitectActionButton(title: "Change Course (C)", icon: "arrow.triangle.swap", color: .green) {
                            triggerOverride(action: .changeCourse)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    
                    // Live Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LIVE SUMMARY")
                            .font(RegattaDesign.Fonts.label)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        
                        SummaryRow(title: "Total Target Time", value: "\(model.totalDuration)s")
                        SummaryRow(title: "Manual Triggers", value: "\(model.manualStepsCount)")
                        SummaryRow(title: "Required Flags", value: "\(model.uniqueFlags)")
                        SummaryRow(title: "Steps Count", value: "\(model.steps.count)")
                        
                        if model.totalDuration > 0 {
                            Divider().background(Color.white.opacity(0.1))
                            HStack {
                                Text("EST. DURATION")
                                    .font(RegattaDesign.Fonts.label)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatTime(seconds: model.totalDuration))
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundStyle(RegattaDesign.Colors.cyan)
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    
                    Spacer()
                }
                }  // end VStack inside ScrollView
                .frame(width: 320)
                .padding(.vertical, 32)
                .padding(.trailing, 32)
            }
            .padding(.leading, 32)
        }
    }
    
    // ─── Logic ───
    private func deployProcedure() {
        print("Deploying Procedure to Race Engine (\(model.steps.count) steps, autoRestart: \(model.autoRestart))")
        raceEngine.deployProcedure(steps: model.steps, autoRestart: model.autoRestart)
        // NOTE: We do NOT dismiss here. The Architect stays open as the master configuration panel.
    }
    
    private func triggerOverride(action: RaceStatus) {
        print("Architect triggering global override: \(action.rawValue)")
        raceEngine.setRaceStatus(action)
    }
    
    private func formatTime(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // ─── Templates ───
    private func loadStandard5Min() {
        model.loadTemplate([
            ProcedureStep(label: "Idle — Ready to Start", duration: 0, flags: [], soundStart: .none, waitForUserTrigger: true, actionLabel: "SIGNAL WARNING — Begin sequence", raceStatus: .idle),
            ProcedureStep(label: "Warning Signal", duration: 60, flags: ["CLASS"], soundStart: .oneShort, raceStatus: .warning),
            ProcedureStep(label: "Preparatory Signal", duration: 180, flags: ["CLASS", "P"], soundStart: .oneShort, soundRemove: .oneLong, raceStatus: .preparatory),
            ProcedureStep(label: "One-Minute", duration: 60, flags: ["CLASS"], soundStart: .oneLong, raceStatus: .oneMinute),
            ProcedureStep(label: "Start", duration: 0, flags: [], soundStart: .oneShort, raceStatus: .racing),
            ProcedureStep(label: "Racing", duration: 0, waitForUserTrigger: true, actionLabel: "FINISH RACE — End racing", raceStatus: .racing)
        ])
    }
    
    private func loadShortCourse3Min() {
        model.loadTemplate([
            ProcedureStep(label: "Idle — Ready to Start", duration: 0, flags: [], soundStart: .none, waitForUserTrigger: true, actionLabel: "SIGNAL WARNING — Begin sequence", raceStatus: .idle),
            ProcedureStep(label: "Warning Signal", duration: 60, flags: ["CLASS"], soundStart: .oneShort, raceStatus: .warning),
            ProcedureStep(label: "Preparatory Signal", duration: 60, flags: ["CLASS", "P"], soundStart: .oneShort, soundRemove: .oneLong, raceStatus: .preparatory),
            ProcedureStep(label: "One-Minute", duration: 60, flags: ["CLASS"], soundStart: .oneLong, raceStatus: .oneMinute),
            ProcedureStep(label: "Start", duration: 0, flags: [], soundStart: .oneShort, raceStatus: .racing),
            ProcedureStep(label: "Racing", duration: 0, waitForUserTrigger: true, actionLabel: "FINISH RACE", raceStatus: .racing)
        ])
    }
    
    private func loadLeagueUF() {
        model.loadTemplate([
            ProcedureStep(label: "Pre-Start Alert", duration: 0, flags: ["ORANGE"], soundStart: .oneLong, waitForUserTrigger: true, actionLabel: "START WARNING SEQUENCE", raceStatus: .idle),
            ProcedureStep(label: "Warning Signal", duration: 60, flags: ["CLASS"], soundStart: .oneShort, raceStatus: .warning),
            ProcedureStep(label: "Preparatory Signal", duration: 180, flags: ["CLASS", "P"], soundStart: .oneShort, soundRemove: .oneLong, raceStatus: .preparatory),
            ProcedureStep(label: "One-Minute", duration: 60, flags: ["CLASS"], soundStart: .oneLong, raceStatus: .oneMinute),
            ProcedureStep(label: "Start", duration: 0, flags: [], soundStart: .oneShort, raceStatus: .racing),
            ProcedureStep(label: "Racing (Umpired)", duration: 0, waitForUserTrigger: true, actionLabel: "FINISH RACE", raceStatus: .racing)
        ])
    }
}

// ─── Subcomponents ───

struct ProcedureStepCard: View {
    @Binding var step: ProcedureStep
    let availableFlags: [String]
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed Header Row
            HStack(spacing: 16) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Step Label", text: $step.label)
                        .font(.headline)
                        .textFieldStyle(.plain)
                    
                    if !isExpanded {
                        HStack(spacing: 12) {
                            if step.waitForUserTrigger {
                                Label("Manual", systemImage: "hand.tap.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Label("\(step.duration)s", systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !step.flags.isEmpty {
                                Label("\(step.flags.count) Flags", systemImage: "flag.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if step.soundStart != .none {
                                Label(step.soundStart.displayName, systemImage: "speaker.wave.3.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isExpanded ? RegattaDesign.Colors.cyan : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            
            // Expanded Detailing
            if isExpanded {
                ExpandedStepDetails(step: $step, availableFlags: availableFlags, onDelete: onDelete, onDuplicate: onDuplicate)
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ExpandedStepDetails: View {
    @Binding var step: ProcedureStep
    let availableFlags: [String]
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider().background(Color.white.opacity(0.1))
            
            // Top Settings Row
            HStack(alignment: .top, spacing: 24) {
                // Timing & Flow
                VStack(alignment: .leading, spacing: 12) {
                    Text("TIMING & FLOW")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Manual User Trigger", isOn: $step.waitForUserTrigger)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    
                    if step.waitForUserTrigger {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Action Label")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. 'START SEQUENCE'", text: $step.actionLabel)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration (Seconds)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Amount", value: $step.duration, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Race Status Override")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Status", selection: $step.raceStatus) {
                            ForEach(RaceStatusOverride.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Audio & Hardware
                VStack(alignment: .leading, spacing: 12) {
                    Text("AUDIO & HARDWARE")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sound at Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Start Sound", selection: $step.soundStart) {
                            ForEach(SoundSignal.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sound on Remove")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Remove Sound", selection: $step.soundRemove) {
                            ForEach(SoundSignal.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    Toggle("Sync to Smart Horns/Lights", isOn: $step.hardwareSync)
                        .toggleStyle(SwitchToggleStyle(tint: RegattaDesign.Colors.cyan))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Auto VHF Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto VHF Broadcast Text (TTS)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. 'Warning signal in 1 minute'", text: $step.autoVHFText)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Flags Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("REQUIRED FLAGS")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.secondary)
                
                // Simple wrapping layout for flags
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(availableFlags, id: \.self) { flag in
                        let isSelected = step.flags.contains(flag)
                        Button(action: {
                            if isSelected {
                                step.flags.removeAll { $0 == flag }
                            } else {
                                step.flags.append(flag)
                            }
                        }) {
                            Text(flag)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(isSelected ? RegattaDesign.Colors.electricBlue : Color.white.opacity(0.1))
                                .foregroundStyle(isSelected ? .black : .white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Card Actions
            HStack {
                Spacer()
                Button(action: onDuplicate) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.black.opacity(0.2))
    }
}

struct ArchitectTemplateButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ArchitectActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
        }
    }
}

// ─── Data Models ───

struct ProcedureStep: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var label: String
    var duration: Int // in seconds
    
    var flags: [String]
    var soundStart: SoundSignal
    var soundRemove: SoundSignal
    
    var waitForUserTrigger: Bool
    var actionLabel: String
    
    var raceStatus: RaceStatusOverride
    
    var hardwareSync: Bool
    var autoVHFText: String
    
    init(id: String = UUID().uuidString, label: String, duration: Int, flags: [String] = [], soundStart: SoundSignal = .none, soundRemove: SoundSignal = .none, waitForUserTrigger: Bool = false, actionLabel: String = "", raceStatus: RaceStatusOverride = .autoDetect, hardwareSync: Bool = false, autoVHFText: String = "") {
        self.id = id
        self.label = label
        self.duration = duration
        self.flags = flags
        self.soundStart = soundStart
        self.soundRemove = soundRemove
        self.waitForUserTrigger = waitForUserTrigger
        self.actionLabel = actionLabel
        self.raceStatus = raceStatus
        self.hardwareSync = hardwareSync
        self.autoVHFText = autoVHFText
    }
}

enum SoundSignal: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case oneShort = "ONE_SHORT"
    case oneLong = "ONE_LONG"
    case twoShort = "TWO_SHORT"
    case threeShort = "THREE_SHORT"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "No Sound"
        case .oneShort: return "1 Short"
        case .oneLong: return "1 Long"
        case .twoShort: return "2 Short"
        case .threeShort: return "3 Short"
        }
    }
}

enum RaceStatusOverride: String, Codable, CaseIterable, Identifiable {
    case autoDetect = "AUTO_DETECT"
    case idle = "IDLE"
    case warning = "WARNING"
    case preparatory = "PREPARATORY"
    case oneMinute = "ONE_MINUTE"
    case racing = "RACING"
    case finished = "FINISHED"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .autoDetect: return "Auto-detect"
        case .idle: return "IDLE"
        case .warning: return "WARNING"
        case .preparatory: return "PREPARATORY"
        case .oneMinute: return "ONE_MINUTE"
        case .racing: return "RACING"
        case .finished: return "FINISHED"
        }
    }
}

@MainActor
class ProcedureArchitectModel: ObservableObject {
    private static let stepsKey = "procedureArchitect.steps"
    private static let autoRestartKey = "procedureArchitect.autoRestart"
    
    @Published var steps: [ProcedureStep] = [] {
        didSet { save() }
    }
    @Published var autoRestart: Bool = false {
        didSet { save() }
    }
    
    init() {
        load()
    }
    
    var totalDuration: Int {
        steps.reduce(0) { $0 + $1.duration }
    }
    
    var uniqueFlags: Int {
        Set(steps.flatMap { $0.flags }).count
    }
    
    var manualStepsCount: Int {
        steps.filter { $0.waitForUserTrigger }.count
    }
    
    func addStep() {
        let newStep = ProcedureStep(label: "New Step", duration: 60)
        steps.append(newStep)
    }
    
    func removeStep(id: String) {
        steps.removeAll { $0.id == id }
    }
    
    func moveStep(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }
    
    func duplicateStep(id: String) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        var copy = steps[index]
        copy.id = UUID().uuidString
        steps.insert(copy, at: index + 1)
    }
    
    func loadTemplate(_ template: [ProcedureStep]) {
        self.steps = template
    }
    
    // ─── Persistence ───
    
    func save() {
        if let data = try? JSONEncoder().encode(steps) {
            UserDefaults.standard.set(data, forKey: Self.stepsKey)
        }
        UserDefaults.standard.set(autoRestart, forKey: Self.autoRestartKey)
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.stepsKey),
           let loadedSteps = try? JSONDecoder().decode([ProcedureStep].self, from: data) {
            // Bypass didSet to prevent double-save on initial load
            _steps = Published(initialValue: loadedSteps)
        }
        _autoRestart = Published(initialValue: UserDefaults.standard.bool(forKey: Self.autoRestartKey))
    }
    
    func clearAll() {
        steps = []
        autoRestart = false
        UserDefaults.standard.removeObject(forKey: Self.stepsKey)
        UserDefaults.standard.removeObject(forKey: Self.autoRestartKey)
    }
}

