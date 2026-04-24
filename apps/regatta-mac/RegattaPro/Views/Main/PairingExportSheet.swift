import SwiftUI

struct PairingExportSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var raceState: RaceStateModel
    
    @State private var selectedTeamId: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Export Pairing Schedule")
                .font(RegattaDesign.Fonts.heading)
                .foregroundStyle(.white)
            
            Text("Select a team to highlight their specific races in the exported PDF Document.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Picker("Highlight Team", selection: $selectedTeamId) {
                Text("None (Standard Print)").tag("")
                Divider()
                ForEach(raceState.leagueTeams) { team in
                    Text(team.name).tag(team.id)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: exportPDF) {
                    Label("Save PDF", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AnyShapeStyle(RegattaDesign.Gradients.primary))
                .cornerRadius(8)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
    
    private func exportPDF() {
        guard let schedule = raceState.leagueSchedule else { return }
        
        Task { @MainActor in
            PDFScheduleRenderer.renderAndSave(
                schedule: schedule,
                teams: raceState.leagueTeams,
                boats: raceState.leagueBoats,
                highlightTeamId: selectedTeamId,
                fileName: "Regatta Pairings.pdf"
            )
            dismiss()
        }
    }
}
