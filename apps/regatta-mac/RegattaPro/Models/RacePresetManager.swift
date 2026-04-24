// RacePresetManager.swift
// Manages CRUD for race presets with auto-save and a hardcoded Finnish Sailing Demo.

import Foundation
import Combine

// ─── Data Model ─────────────────────────────────────────────────────────────

struct ProcedureStepData: Codable, Equatable {
    var label: String
    var duration: Int
    var flags: [String]
    var soundStart: String
    var soundRemove: String
    var waitForUserTrigger: Bool
    var actionLabel: String
    var raceStatus: String
}

struct RacePreset: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var course: CourseState
    var windSpeed: Double
    var windDirection: Double
    var boatProfiles: [BoatProfile]
    var procedureSteps: [ProcedureStepData]?
    var leagueTeams: [LeagueTeam]?
    var leagueBoats: [LeagueBoat]?
    var isDemo: Bool = false
    
    static func == (lhs: RacePreset, rhs: RacePreset) -> Bool {
        lhs.id == rhs.id && lhs.modifiedAt == rhs.modifiedAt
    }
    
    var courseSummary: String {
        let markCount = course.marks.count
        if markCount == 0 { return "Empty course" }
        let types = Set(course.marks.map { $0.type })
        if types.contains(.gate) { return "\(markCount) marks, Windward-Leeward" }
        return "\(markCount) marks"
    }
}

// ─── Manager ────────────────────────────────────────────────────────────────

@MainActor
final class RacePresetManager: ObservableObject {
    @Published var presets: [RacePreset] = []
    @Published var activePreset: RacePreset?
    @Published var hasSelectedRace: Bool = false
    
    private var autoSaveCancellable: AnyCancellable?
    private var autoSaveSubject = PassthroughSubject<Void, Never>()
    
    private let presetsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.regatta.pro/presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    init() {
        loadAll()
        setupAutoSave()
    }
    
    // ─── CRUD ────────────────────────────────────────────────────────────────
    
    func loadAll() {
        var loaded: [RacePreset] = []
        
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil) else {
            presets = []
            return
        }
        
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let preset = try? JSONDecoder().decode(RacePreset.self, from: data) {
                loaded.append(preset)
            }
        }
        
        presets = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    func save(_ preset: RacePreset) {
        let fileURL = presetsDirectory.appendingPathComponent("\(preset.id).json")
        if let data = try? JSONEncoder().encode(preset) {
            try? data.write(to: fileURL, options: .atomic)
        }
        
        // Update in-memory list
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.insert(preset, at: 0)
        }
    }
    
    func delete(_ preset: RacePreset) {
        let fileURL = presetsDirectory.appendingPathComponent("\(preset.id).json")
        try? FileManager.default.removeItem(at: fileURL)
        presets.removeAll { $0.id == preset.id }
    }
    
    func createNew(name: String = "New Race") -> RacePreset {
        let preset = RacePreset(
            id: UUID().uuidString,
            name: name,
            createdAt: Date(),
            modifiedAt: Date(),
            course: CourseState(),
            windSpeed: 10.0,
            windDirection: 180.0,
            boatProfiles: [.defaultProfile]
        )
        save(preset)
        return preset
    }
    
    // ─── Activate ────────────────────────────────────────────────────────────
    
    func activate(_ preset: RacePreset, into stateModel: RaceStateModel) {
        activePreset = preset
        stateModel.loadFromPreset(preset)
        hasSelectedRace = true
    }
    
    // ─── Auto-Save ───────────────────────────────────────────────────────────
    
    func triggerAutoSave() {
        autoSaveSubject.send()
    }
    
    private func setupAutoSave() {
        autoSaveCancellable = autoSaveSubject
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performAutoSave()
            }
    }
    
    private func performAutoSave() {
        guard var preset = activePreset else { return }
        preset.modifiedAt = Date()
        save(preset)
        activePreset = preset
        print("💾 [RacePresetManager] Auto-saved preset: \(preset.name)")
    }
    
    func updateActivePreset(from stateModel: RaceStateModel) {
        guard var preset = activePreset else { return }
        preset = stateModel.exportToPreset(name: preset.name, existingId: preset.id, createdAt: preset.createdAt)
        activePreset = preset
        triggerAutoSave()
    }
    
    // ─── Finnish Sailing Demo ────────────────────────────────────────────────
    
    static func finnishSailingDemo() -> RacePreset {
        // Course: Helsinki Harbour Windward-Leeward
        let marks: [Buoy] = [
            Buoy(id: "demo-start-cb", type: .start, name: "Committee Boat", pos: LatLon(lat: 60.1580, lon: 24.9350), color: "Red", design: "Spar"),
            Buoy(id: "demo-start-pin", type: .start, name: "Pin End", pos: LatLon(lat: 60.1580, lon: 24.9370), color: "Orange", design: "Cylindrical"),
            Buoy(id: "demo-ww-mark", type: .mark, name: "Windward Mark", pos: LatLon(lat: 60.1620, lon: 24.9360), color: "Yellow", design: "Spherical", showLaylines: true, laylineDirection: 0),
            Buoy(id: "demo-gate-l", type: .gate, name: "Leeward Gate L", pos: LatLon(lat: 60.1585, lon: 24.9345), color: "Yellow", design: "Cylindrical"),
            Buoy(id: "demo-gate-r", type: .gate, name: "Leeward Gate R", pos: LatLon(lat: 60.1585, lon: 24.9375), color: "Yellow", design: "Cylindrical"),
            Buoy(id: "demo-finish-cb", type: .finish, name: "Finish Boat", pos: LatLon(lat: 60.1578, lon: 24.9348), color: "Blue", design: "Spar"),
            Buoy(id: "demo-finish-pin", type: .finish, name: "Finish Pin", pos: LatLon(lat: 60.1578, lon: 24.9372), color: "Orange", design: "Cylindrical"),
        ]
        
        // Course boundary: rectangle around the racing area
        let boundary: [LatLon] = [
            LatLon(lat: 60.1570, lon: 24.9320),
            LatLon(lat: 60.1570, lon: 24.9400),
            LatLon(lat: 60.1630, lon: 24.9400),
            LatLon(lat: 60.1630, lon: 24.9320),
        ]
        
        let startLine = CourseLine(
            p1: LatLon(lat: 60.1580, lon: 24.9350),
            p2: LatLon(lat: 60.1580, lon: 24.9370)
        )
        let finishLine = CourseLine(
            p1: LatLon(lat: 60.1578, lon: 24.9348),
            p2: LatLon(lat: 60.1578, lon: 24.9372)
        )
        
        let course = CourseState(
            marks: marks,
            startLine: startLine,
            finishLine: finishLine,
            courseBoundary: boundary,
            restrictionZones: [],
            settings: CourseSettings(showMarkZones: true, markZoneMultiplier: 3.0, show3DWall: true, show3DLogos: true)
        )
        
        // J70 Boat Profile
        let j70Profile = BoatProfile(
            id: "j70-demo",
            name: "J/70",
            maxLengthPole: 10.0,
            maxLengthHull: 6.93,
            maxWidthDeck: 2.25,
            mount: TrackerMount(offsetX: 1.5, offsetY: 0, offsetZ: 0.1, mountingAzimuth: 0, mountingElevation: 0)
        )
        
        // Standard 5-Min RRS 26 Start Procedure
        let procedure: [ProcedureStepData] = [
            ProcedureStepData(label: "Idle — Ready to Start", duration: 0, flags: [], soundStart: "NONE", soundRemove: "NONE", waitForUserTrigger: true, actionLabel: "SIGNAL WARNING — Begin sequence", raceStatus: "IDLE"),
            ProcedureStepData(label: "Warning Signal", duration: 60, flags: ["CLASS"], soundStart: "ONE_SHORT", soundRemove: "NONE", waitForUserTrigger: false, actionLabel: "", raceStatus: "WARNING"),
            ProcedureStepData(label: "Preparatory Signal", duration: 180, flags: ["CLASS", "P"], soundStart: "ONE_SHORT", soundRemove: "ONE_LONG", waitForUserTrigger: false, actionLabel: "", raceStatus: "PREPARATORY"),
            ProcedureStepData(label: "One-Minute", duration: 60, flags: ["CLASS"], soundStart: "ONE_LONG", soundRemove: "NONE", waitForUserTrigger: false, actionLabel: "", raceStatus: "ONE_MINUTE"),
            ProcedureStepData(label: "Start", duration: 0, flags: [], soundStart: "ONE_SHORT", soundRemove: "NONE", waitForUserTrigger: false, actionLabel: "", raceStatus: "RACING"),
            ProcedureStepData(label: "Racing", duration: 0, flags: [], soundStart: "NONE", soundRemove: "NONE", waitForUserTrigger: true, actionLabel: "FINISH RACE — End racing", raceStatus: "RACING"),
        ]
        
        // Demo teams
        let teams: [LeagueTeam] = (1...15).map { i in
            LeagueTeam(id: "team-\(i)", name: "Team \(i)", club: "Helsinki SC", ranking: i)
        }
        
        let boats: [LeagueBoat] = [
            LeagueBoat(id: "1", name: "Boat 1", color: "#2563EB"),
            LeagueBoat(id: "2", name: "Boat 2", color: "#DC2626"),
            LeagueBoat(id: "3", name: "Boat 3", color: "#059669"),
            LeagueBoat(id: "4", name: "Boat 4", color: "#D97706"),
        ]
        
        return RacePreset(
            id: "finnish-sailing-demo",
            name: "Finnish Sailing Demo",
            createdAt: Date(timeIntervalSince1970: 1713300000),
            modifiedAt: Date(),
            course: course,
            windSpeed: 12.0,
            windDirection: 180.0,
            boatProfiles: [j70Profile],
            procedureSteps: procedure,
            leagueTeams: teams,
            leagueBoats: boats,
            isDemo: true
        )
    }
}
