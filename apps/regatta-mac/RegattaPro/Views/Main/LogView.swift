import SwiftUI

// Temporary Model definition until we link to the Rust Native Core Data Model
struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let source: String
    let message: String
    let isFlagged: Bool
}

struct LogView: View {
    // Dummy Data to establish UI
    @State private var logs: [LogEntry] = [
        LogEntry(timestamp: Date().addingTimeInterval(-3600), category: "SYSTEM", source: "Sidecar", message: "Regatta Engine Started", isFlagged: false),
        LogEntry(timestamp: Date().addingTimeInterval(-1800), category: "PROCEDURE", source: "Director", message: "Sequence 1 (Warning) Initiated", isFlagged: false),
        LogEntry(timestamp: Date().addingTimeInterval(-1740), category: "PROCEDURE", source: "Director", message: "Class Flag Hoisted", isFlagged: false),
        LogEntry(timestamp: Date().addingTimeInterval(-120), category: "BOAT", source: "FRA 28", message: "Ping timeout, switching to offline buffer", isFlagged: true),
        LogEntry(timestamp: Date(), category: "JURY", source: "Automated", message: "USA 11 On Course Side (OCS)", isFlagged: true)
    ]
    
    @State private var sortOrder = [KeyPathComparator(\LogEntry.timestamp, order: .reverse)]
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar Area
            HStack {
                Text("Race Audit Log")
                    .font(.headline)
                Spacer()
                Button(action: exportCSV) {
                    Label("Export CSV", systemImage: "arrow.down.doc")
                }
                Button(action: exportPDF) {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Core Table
            Table(logs, sortOrder: $sortOrder) {
                TableColumn("Time", value: \.timestamp) { entry in
                    Text(entry.timestamp, style: .time)
                        .font(.system(.body, design: .monospaced))
                }
                .width(min: 80, ideal: 100, max: 120)
                
                TableColumn("Category", value: \.category) { entry in
                    Text(entry.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor(entry.category).opacity(0.2))
                        .foregroundStyle(categoryColor(entry.category))
                        .cornerRadius(4)
                }
                .width(80)
                
                TableColumn("Source", value: \.source) { entry in
                    Text(entry.source)
                        .foregroundStyle(.secondary)
                }
                .width(100)
                
                TableColumn("Message", value: \.message) { entry in
                    HStack {
                        if entry.isFlagged {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.red)
                        }
                        Text(entry.message)
                            .fontWeight(entry.isFlagged ? .semibold : .regular)
                    }
                }
            }
            .onChange(of: sortOrder) { newOrder in
                logs.sort(using: newOrder)
            }
            .contextMenu(forSelectionType: LogEntry.ID.self) { items in
                Button("Flag for Jury") {
                    // TODO: Trigger Jury Modal
                }
                Button("Copy Message") {
                    // TODO: Copy to clipboard
                }
            }
        }
        .navigationTitle("Race Log")
    }
    
    // Helper to color code chips
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "SYSTEM": return .gray
        case "PROCEDURE": return .blue
        case "BOAT": return .cyan
        case "JURY": return .red
        default: return .primary
        }
    }
    
    // Export Handlers
    private func exportCSV() {
        print("Exporting CSV...")
    }
    
    private func exportPDF() {
        print("Exporting PDF...")
    }
}
