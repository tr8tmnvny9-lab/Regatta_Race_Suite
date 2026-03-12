import SwiftUI
import UniformTypeIdentifiers

struct FleetControlView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    
    @State private var boatCount: Int = 6
    @State private var flightCount: Int = 15
    @State private var newTeamName: String = ""
    @State private var newTeamClub: String = ""
    @State private var teamToDelete: LeagueTeam?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 20) {
            // LEFT COLUMN: Team Roster & Diagnostics
            VStack(spacing: 20) {
                teamRosterSection
                
                GlassPanel(title: "Fleet Health", icon: "waveform.path.ecg") {
                    FleetHealthDashboard()
                }
                .frame(height: 300)
            }
            .frame(width: 320)
            
            // RIGHT COLUMN: Scheduling Matrix
            VStack(spacing: 20) {
                generatorControlsSection
                scheduleMatrixSection
            }
        }
        .padding(20)
    }
}

// MARK: - Sections

extension FleetControlView {
    
    private var teamRosterSection: some View {
        GlassPanel(title: "Team Roster (\(raceState.leagueTeams.count))", icon: "person.3.fill") {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button("Clear All", role: .destructive) {
                        raceState.clearAllTeams()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                }
                
                HStack {
                    TextField("Team Name", text: $newTeamName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    
                    TextField("Club", text: $newTeamClub)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    
                    Button(action: addTeam) {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RegattaDesign.Colors.electricBlue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newTeamName.isEmpty)
                }
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(raceState.leagueTeams) { team in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(team.name)
                                        .fontWeight(.bold)
                                    Text(team.club)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(action: { 
                                    teamToDelete = team
                                    showingDeleteConfirmation = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete \(teamToDelete?.name ?? "this team")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Team", role: .destructive) {
                if let team = teamToDelete {
                    deleteTeam(team)
                }
            }
            Button("Cancel", role: .cancel) {
                teamToDelete = nil
            }
        } message: {
            Text("This action cannot be undone and will remove the team from all races.")
        }
    }
    
    private var generatorControlsSection: some View {
        GlassPanel(title: "Pairing Generator", icon: "wand.and.stars") {
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("FLIGHTS")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.secondary)
                    Stepper("\(flightCount)", value: $flightCount, in: 1...50)
                }
                
                VStack(alignment: .leading) {
                    Text("BOATS")
                        .font(RegattaDesign.Fonts.label)
                        .foregroundStyle(.secondary)
                    Stepper("\(boatCount)", value: $boatCount, in: 2...12)
                }
                
                Spacer()
                
                Button(action: generateSchedule) {
                    HStack {
                        if !raceEngine.isReady {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Label(raceEngine.isReady ? "GENERATE SCHEDULE" : "QUEUE GENERATION", systemImage: "play.fill")
                            .font(RegattaDesign.Fonts.label)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(raceEngine.isReady ? AnyShapeStyle(RegattaDesign.Gradients.primary) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 100)
    }
    
    private var scheduleMatrixSection: some View {
        GlassPanel(title: "Flight Schedule Matrix", icon: "calendar") {
            if let schedule = raceState.leagueSchedule {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 2) {
                        // Header
                        HStack(spacing: 2) {
                            Text("RACE")
                                .font(RegattaDesign.Fonts.label)
                                .frame(width: 80)
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                            
                            ForEach(1..<(schedule.boatCount + 1), id: \.self) { bIdx in
                                BoatHeaderView(boatId: "\(bIdx)")
                            }
                        }
                        
                        // Flights
                        ForEach(0..<schedule.flightCount, id: \.self) { fIdx in
                            flightHeader(index: fIdx)
                            
                            let pairings = schedule.pairings.filter { $0.flightIndex == fIdx }
                            let maxRace = pairings.map { $0.raceIndex }.max() ?? 0
                            
                            ForEach(0..<(maxRace + 1), id: \.self) { rIdx in
                                let racePairings = pairings.filter { $0.raceIndex == rIdx }
                                raceRow(flightIdx: fIdx, raceIdx: rIdx, boatCount: schedule.boatCount, pairings: racePairings)
                            }
                        }
                    }
                }
            } else {
                emptyScheduleView
            }
        }
    }
    
    private func flightHeader(index: Int) -> some View {
        Text("FLIGHT \(index + 1)")
            .font(RegattaDesign.Fonts.label)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RegattaDesign.Colors.cyan.opacity(0.1))
            .foregroundStyle(RegattaDesign.Colors.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.top, 10)
    }
    
    private func raceRow(flightIdx: Int, raceIdx: Int, boatCount: Int, pairings: [LeaguePairing]) -> some View {
        HStack(spacing: 2) {
            Text("Race \(raceIdx + 1)")
                .font(RegattaDesign.Fonts.mono)
                .frame(width: 80)
                .padding(8)
                .background(Color.white.opacity(0.05))
            
            ForEach(1..<(boatCount + 1), id: \.self) { bIdx in
                PairingCell(boatId: "\(bIdx)", pairings: pairings)
            }
        }
    }
    
    private var emptyScheduleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No schedule generated yet.\nAdd teams and configure your flight plan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Components

struct BoatHeaderView: View {
    @EnvironmentObject var raceState: RaceStateModel
    let boatId: String
    
    var body: some View {
        let boat = raceState.leagueBoats.first(where: { $0.id == boatId })
        let name = boat?.name ?? "BOAT \(boatId)"
        let colorHex = boat?.color ?? "#FFFFFF"
        
        let colorBinding = Binding<Color>(
            get: { Color(hex: colorHex) },
            set: { newColor in
                if let hexString = newColor.toHex() {
                    raceState.updateBoatColor(id: boatId, colorHex: hexString)
                }
            }
        )
        
        HStack {
            Text(name)
                .font(RegattaDesign.Fonts.label)
                .foregroundStyle(Color(hex: colorHex))
            Spacer()
            ColorPicker("", selection: colorBinding)
                .labelsHidden()
        }
        .frame(width: 140)
        .padding(8)
        .background(Color.black.opacity(0.2))
    }
}

struct PairingCell: View {
    @EnvironmentObject var raceState: RaceStateModel
    let boatId: String
    let pairings: [LeaguePairing]
    
    var body: some View {
        let teamId = pairings.first(where: { $0.boatId == boatId })?.teamId
        let team = raceState.leagueTeams.first(where: { $0.id == teamId })
        let teamName = team?.name ?? "-"
        let boatColorHex = raceState.leagueBoats.first(where: { $0.id == boatId })?.color ?? "#FFFFFF"
        let boatColor = Color(hex: boatColorHex)
        
        VStack(spacing: 2) {
            Text(teamName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(teamName == "-" ? Color.secondary : Color.white)
            
            if let club = team?.club, !club.isEmpty {
                Text(club)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .frame(width: 140)
        .padding(8)
        .background(teamName == "-" ? Color.clear : boatColor.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(teamName == "-" ? Color.clear : boatColor)
                .frame(width: 4),
            alignment: .leading
        )
    }
}

// MARK: - Actions

extension FleetControlView {
    
    private func addTeam() {
        guard !newTeamName.isEmpty else { return }
        raceState.addLeagueTeam(name: newTeamName, club: newTeamClub)
        newTeamName = ""
        newTeamClub = ""
    }
    
    private func deleteTeam(_ team: LeagueTeam) {
        raceState.removeLeagueTeam(id: team.id)
    }
    
    private func generateSchedule() {
        raceState.generateLeagueSchedule(boatCount: boatCount, flightCount: flightCount)
    }
}

