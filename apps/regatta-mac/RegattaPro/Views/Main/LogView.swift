import SwiftUI

struct LogView: View {
    @EnvironmentObject var raceState: RaceStateModel
    @State private var selectedCategory: LogCategory? = nil
    @State private var searchSource: String = ""
    @State private var sortOrder = [KeyPathComparator(\LogEntry.timestamp, order: .reverse)]
    
    var filteredLogs: [LogEntry] {
        raceState.logs.filter { entry in
            let catMatch = selectedCategory == nil || entry.category == selectedCategory
            let sourceMatch = searchSource.isEmpty || entry.source.lowercased().contains(searchSource.lowercased())
            return catMatch && sourceMatch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // High-Velocity Toolbar
            HStack(spacing: 20) {
                // Category Filter
                HStack(spacing: 8) {
                    FilterChip(label: "ALL", isActive: selectedCategory == nil) { selectedCategory = nil }
                    ForEach([LogCategory.jury, .boat, .procedure, .system], id: \.self) { cat in
                        FilterChip(label: cat.rawValue, isActive: selectedCategory == cat, color: categoryColor(cat)) {
                            selectedCategory = (selectedCategory == cat ? nil : cat)
                        }
                    }
                }
                
                Divider().frame(height: 24)
                
                // Search / Boat ID Filter
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter by Boat ID / Source", text: $searchSource)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    ActionButton(icon: "arrow.down.doc", label: "CSV") { /* Export */ }
                    ActionButton(icon: "doc.richtext", label: "PDF") { /* Export */ }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            
            // The Log Table
            Table(filteredLogs, sortOrder: $sortOrder) {
                TableColumn("TIME", value: \.timestamp) { entry in
                    Text(entry.date, style: .time)
                        .font(RegattaDesign.Fonts.mono)
                        .foregroundStyle(.secondary)
                }
                .width(80)
                
                TableColumn("CATEGORY", value: \.category.rawValue) { entry in
                    categoryBadge(for: entry.category)
                }
                .width(100)
                
                TableColumn("SOURCE", value: \.source) { entry in
                    Text(entry.source)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.category == .boat ? RegattaDesign.Colors.cyan : .white)
                }
                .width(100)
                
                TableColumn("MESSAGE", value: \.message) { entry in
                    HStack {
                        if entry.isFlagged {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(RegattaDesign.Colors.crimson)
                        }
                        Text(entry.message)
                            .foregroundStyle(entry.isFlagged ? RegattaDesign.Colors.crimson : .primary)
                    }
                }
            }
            .tableStyle(.inset)
        }
        .background(Color.black.opacity(0.2))
    }
    
    @ViewBuilder
    private func categoryBadge(for category: LogCategory) -> some View {
        Text(category.rawValue)
            .font(.system(size: 9, weight: .black))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor(category).opacity(0.15))
            .foregroundStyle(categoryColor(category))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(categoryColor(category).opacity(0.3), lineWidth: 1))
    }
    
    private func categoryColor(_ category: LogCategory) -> Color {
        switch category {
        case .system: return .gray
        case .procedure: return .blue
        case .boat: return RegattaDesign.Colors.cyan
        case .jury: return RegattaDesign.Colors.crimson
        default: return .white
        }
    }
}

// ─── Sub-Components ──────────────────────────────────────────────────────────

struct FilterChip: View {
    let label: String
    let isActive: Bool
    var color: Color = RegattaDesign.Colors.electricBlue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? color.opacity(0.2) : Color.white.opacity(0.05))
                .foregroundStyle(isActive ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

