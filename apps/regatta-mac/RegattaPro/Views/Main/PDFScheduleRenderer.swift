import SwiftUI
import AppKit

@MainActor
class PDFScheduleRenderer {
    static func renderAndSave(schedule: LeagueSchedule, teams: [LeagueTeam], boats: [LeagueBoat], highlightTeamId: String, fileName: String = "PairingSchedule.pdf") {
        let printView = PairingPrintLayoutView(schedule: schedule, teams: teams, boats: boats, highlightTeamId: highlightTeamId)
        
        let renderer = ImageRenderer(content: printView)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = fileName
        savePanel.prompt = "Export PDF"
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                renderer.render { size, context in
                    var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                    guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                    pdf.beginPDFPage(nil)
                    context(pdf)
                    pdf.endPDFPage()
                    pdf.closePDF()
                }
                
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// Custom View designed for white-background print compatibility
struct PairingPrintLayoutView: View {
    let schedule: LeagueSchedule
    let teams: [LeagueTeam]
    let boats: [LeagueBoat]
    let highlightTeamId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            
            // Document Header
            HStack {
                Text("RegattaPro Pairing Schedule")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                if let t = teams.first(where: { $0.id == highlightTeamId }) {
                    Text("Highlighting: \(t.name.uppercased())")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.bottom, 20)
            
            // Matrix Header
            HStack(spacing: 2) {
                Text("RACE")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .foregroundStyle(.black)
                
                ForEach(1..<(schedule.boatCount + 1), id: \.self) { bIdx in
                    let bId = "\(bIdx)"
                    let boat = boats.first(where: { $0.id == bId })
                    let name = boat?.name ?? "BOAT \(bIdx)"
                    let colorHex = boat?.color ?? "#FFFFFF"
                    let boatColor = Color(hex: colorHex)
                    
                    Text(name)
                        .font(.system(size: 12, weight: .heavy))
                        .frame(width: 140)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .foregroundStyle(boatColor)
                }
            }
            
            // Flights
            ForEach(0..<schedule.flightCount, id: \.self) { fIdx in
                Text("FLIGHT \(fIdx + 1)")
                    .font(.system(size: 14, weight: .heavy))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .padding(.top, 10)
                
                let pairings = schedule.pairings.filter { $0.flightIndex == fIdx }
                let maxRace = pairings.map { $0.raceIndex }.max() ?? 0
                
                ForEach(0..<(maxRace + 1), id: \.self) { rIdx in
                    let racePairings = pairings.filter { $0.raceIndex == rIdx }
                    
                    HStack(spacing: 2) {
                        Text("Race \(rIdx + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 80)
                            .padding(8)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .border(Color.gray.opacity(0.3), width: 1)
                        
                        ForEach(1..<(schedule.boatCount + 1), id: \.self) { bIdx in
                            let boatId = "\(bIdx)"
                            let teamId = racePairings.first(where: { $0.boatId == boatId })?.teamId
                            let teamName = teams.first(where: { $0.id == teamId })?.name ?? "-"
                            
                            let boatColorHex = boats.first(where: { $0.id == boatId })?.color ?? "#FFFFFF"
                            let baseBoatColor = Color(hex: boatColorHex)
                            let cellBg = baseBoatColor.opacity(0.15)
                            
                            let isHighlighted = (teamId == highlightTeamId && highlightTeamId != "")
                            
                            VStack(spacing: 2) {
                                Text(teamName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(teamName == "-" ? Color.gray : Color.black)
                            }
                            .frame(width: 140)
                            .padding(8)
                            .background(isHighlighted ? Color.yellow.opacity(0.6) : cellBg)
                            .border(isHighlighted ? Color.orange : Color.gray.opacity(0.3), width: isHighlighted ? 3 : 1)
                        }
                    }
                }
            }
        }
        .padding(40)
        .background(Color.white)
    }
}
