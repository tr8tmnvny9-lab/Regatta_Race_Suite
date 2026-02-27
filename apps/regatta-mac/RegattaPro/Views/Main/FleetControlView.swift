import SwiftUI
import UniformTypeIdentifiers

// Temporary Model definition until we link to the Rust Native Core Data Model
struct TeamNode: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var club: String
}

struct PairingRow: Identifiable {
    let id = UUID()
    let boatId: String // e.g., "USA 1"
    var teamA: TeamNode?
    var teamB: TeamNode?
}

struct FleetControlView: View {
    @State private var unassignedTeams: [TeamNode] = [
        TeamNode(name: "NYYC American Magic", club: "NYYC"),
        TeamNode(name: "Emirates Team NZ", club: "RNZYS"),
        TeamNode(name: "INEOS Britannia", club: "RYS"),
        TeamNode(name: "Luna Rossa", club: "CVS")
    ]
    
    // Flight 1 Example
    @State private var flightPairs: [PairingRow] = [
        PairingRow(boatId: "FRA 28"),
        PairingRow(boatId: "SWE 11"),
        PairingRow(boatId: "AUS 99")
    ]
    
    @State private var sortOrder = [KeyPathComparator(\TeamNode.name)]

    var body: some View {
        VSplitView {
            // TOP HALF: Team Roster
            VStack(alignment: .leading) {
                HStack {
                    Text("Team Roster")
                        .font(.headline)
                    Spacer()
                    Button(action: addTeam) {
                        Label("Add Team", systemImage: "plus")
                    }
                }
                .padding()
                
                Table(unassignedTeams, sortOrder: $sortOrder) {
                    TableColumn("Team Name", value: \.name) { team in
                        Text(team.name)
                            .onDrag {
                                // Provide JSON representation for drag
                                let provider = NSItemProvider(object: team.id.uuidString as NSString)
                                return provider
                            }
                    }
                    TableColumn("Club", value: \.club)
                }
                .onChange(of: sortOrder) { newOrder in
                    unassignedTeams.sort(using: newOrder)
                }
            }
            .frame(minHeight: 200)
            
            // BOTTOM HALF: Flight Pairings Matrix
            VStack(alignment: .leading) {
                HStack {
                    Text("Flight Schedule")
                        .font(.headline)
                    Spacer()
                    Button(action: autoGenerate) {
                        Label("Generate Pairings", systemImage: "wand.and.stars")
                    }
                }
                .padding()
                
                Table(flightPairs) {
                    TableColumn("Boat", value: \.boatId)
                        .width(max: 80)
                    
                    TableColumn("Assigned Team") { row in
                        DropZoneCell(team: row.teamA, onDrop: { teamId in
                            assignTeam(teamId: teamId, to: row.id)
                        })
                    }
                }
            }
            .frame(minHeight: 200)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .navigationTitle("Fleet Management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Format", selection: .constant("League")) {
                    Text("League Round-Robin").tag("League")
                    Text("Owner Driver").tag("Owner")
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // --- Actions ---
    private func addTeam() {
        // TODO: Show Add Team Sheet
        unassignedTeams.append(TeamNode(name: "Alinghi", club: "SNG"))
    }
    
    private func autoGenerate() {
        // TODO: Hook into Rust matrix algorithms
        print("Auto-generating schedule")
    }
    
    private func assignTeam(teamId: String, to pairingId: UUID) {
        // Find team
        guard let teamIndex = unassignedTeams.firstIndex(where: { $0.id.uuidString == teamId }) else { return }
        let team = unassignedTeams[teamIndex]
        
        // Find row
        guard let rowIndex = flightPairs.firstIndex(where: { $0.id == pairingId }) else { return }
        
        // Move
        unassignedTeams.remove(at: teamIndex)
        // If there was an old team, push it back
        if let oldTeam = flightPairs[rowIndex].teamA {
            unassignedTeams.append(oldTeam)
        }
        
        flightPairs[rowIndex].teamA = team
    }
}

// Custom Drop Zone Cell
struct DropZoneCell: View {
    let team: TeamNode?
    let onDrop: (String) -> Void
    @State private var isTargeted = false
    
    var body: some View {
        ZStack {
            if let team = team {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.blue)
                    Text(team.name)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Drag Team Here")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isTargeted ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
            if let first = providers.first {
                first.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, error) in
                    if let stringData = data as? Data, let idString = String(data: stringData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            onDrop(idString)
                        }
                    }
                }
                return true
            }
            return false
        }
    }
}
