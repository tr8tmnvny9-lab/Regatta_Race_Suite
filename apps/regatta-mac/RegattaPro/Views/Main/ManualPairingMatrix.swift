import SwiftUI

struct ManualPairingMatrix: View {
    @Binding var schedule: LeagueSchedule
    @EnvironmentObject var raceState: RaceStateModel
    
    @State private var targetFlight: Int = 0
    @State private var targetRace: Int = 0
    @State private var applyOnwards: Bool = false
    
    // We assume trackers are dynamically named or rigidly allocated 1...12
    // Let's create an array of "Trackers" based on the boat count. Tracker 1...N
    private var availableTrackers: [String] {
        (1...schedule.boatCount).map { "Tracker \($0)" }
    }
    
    var body: some View {
        GlassPanel(title: "Manual Hardware & Team Override", icon: "slider.horizontal.3") {
            if schedule.pairings.isEmpty {
                emptyView
            } else {
                VStack(spacing: 20) {
                    controlBar
                    matrixGrid
                }
            }
        }
    }
    
    private var controlBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("TARGET FLIGHT")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.secondary)
                Picker("", selection: $targetFlight) {
                    ForEach(0..<schedule.flightCount, id: \.self) { f in
                        Text("Flight \(f + 1)").tag(f)
                    }
                }
                .frame(width: 120)
            }
            
            VStack(alignment: .leading) {
                Text("TARGET RACE")
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(.secondary)
                
                // Get valid races for this flight
                let flightRaces = Array(Set(schedule.pairings.filter { $0.flightIndex == targetFlight }.map { $0.raceIndex })).sorted()
                
                Picker("", selection: $targetRace) {
                    ForEach(flightRaces, id: \.self) { r in
                        Text("Race \(r + 1)").tag(r)
                    }
                }
                .frame(width: 120)
            }
            
            Divider().frame(height: 30)
            
            Toggle(isOn: $applyOnwards) {
                VStack(alignment: .leading) {
                    Text("Apply Onwards")
                        .font(RegattaDesign.Fonts.label)
                    Text("Ripple changes to all remaining flights/races")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var matrixGrid: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .center, spacing: 2) {
                
                // Header Row
                HStack(spacing: 2) {
                    Text("TEAM")
                        .font(RegattaDesign.Fonts.label)
                        .frame(width: 180, height: 44)
                        .background(Color.black.opacity(0.3))
                    
                    Text("BOAT")
                        .font(RegattaDesign.Fonts.label)
                        .frame(width: 140, height: 44)
                        .background(Color.black.opacity(0.3))
                    
                    ForEach(availableTrackers, id: \.self) { tracker in
                        Text(tracker.uppercased())
                            .font(RegattaDesign.Fonts.label)
                            .frame(width: 80, height: 44)
                            .background(Color.black.opacity(0.3))
                    }
                }
                
                // Rows
                // Sort by Team ID to keep the logical list structurally stable when altering boats
                let currentPairings = schedule.pairingsFor(flight: targetFlight, race: targetRace).sorted(by: { ($0.teamId ?? "") < ($1.teamId ?? "") })
                
                ForEach(currentPairings, id: \.id) { pairing in
                    HStack(spacing: 2) {
                        // TEAM Label
                        let teamName = raceState.leagueTeams.first(where: { $0.id == pairing.teamId })?.name ?? "No Team Assigned"
                        Text(teamName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(width: 180, height: 44)
                            .background(Color.black.opacity(0.15))
                        
                        // BOAT Selector
                        boatSelectorCell(for: pairing)
                        
                        // TRACKER Dip Switches
                        ForEach(availableTrackers, id: \.self) { tracker in
                            trackerSwitchCell(for: pairing, trackerName: tracker)
                        }
                    }
                }
                }
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .top)
            }
        }
    }
    
    @ViewBuilder
    private func boatSelectorCell(for pairing: LeaguePairing) -> some View {
        let binding = Binding<String>(
            get: { pairing.boatId },
            set: { newBoatId in
                schedule.updateBoat(
                    flight: targetFlight,
                    race: targetRace,
                    targetPairingId: pairing.id,
                    newBoatId: newBoatId,
                    onwards: applyOnwards
                )
            }
        )
        
        let currentBoat = raceState.leagueBoats.first(where: { $0.id == binding.wrappedValue })
        let colorHex = currentBoat?.color ?? "#FFFFFF"
        let boatName = currentBoat?.name ?? "Boat \(binding.wrappedValue)"
        
        Menu {
            ForEach(raceState.leagueBoats) { boat in
                Button(boat.name) {
                    binding.wrappedValue = boat.id
                }
            }
        } label: {
            HStack {
                Text(boatName)
                    .font(RegattaDesign.Fonts.label)
                    .foregroundStyle(Color(hex: colorHex))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 12)
        .frame(width: 140, height: 44)
        .background(Color.black.opacity(0.15))
    }
    
    @ViewBuilder
    private func trackerSwitchCell(for pairing: LeaguePairing, trackerName: String) -> some View {
        let isActive = (pairing.trackerId == trackerName)
        let isDefault = (pairing.trackerId == nil && trackerName == "Tracker \(pairing.boatId)")
        let isSelected = isActive || isDefault
        
        Button {
            schedule.updateTracker(
                flight: targetFlight,
                race: targetRace,
                boatId: pairing.boatId,
                newTrackerId: trackerName,
                onwards: applyOnwards
            )
        } label: {
            ZStack {
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.black.opacity(0.15))
                    .frame(width: 80, height: 44)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No pairings generated.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
