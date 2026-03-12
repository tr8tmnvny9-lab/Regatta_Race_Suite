import SwiftUI
import UniformTypeIdentifiers

/// Represents the item currently populating a Broadcast grid slot
enum BroadcastSlotContent: Equatable, Codable {
    case empty
    case map
    case camera(id: String)
    case replay
    case jury
}

/// The available structural layouts for the Center Stage
enum BroadcastLayoutPreset: String, CaseIterable {
    case single = "SINGLE"
    case split = "SPLIT"
    case quad = "QUAD MATRIX"
}

/// Drag and Drop identifier
struct BroadcastDragItem: Codable, Transferable {
    let contentType: String // "map", "camera", "replay", "jury"
    let id: String // "map", boat.id, "replay", or "jury"
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

/// Central state manager for the interactive Drag & Drop Center Stage
class BroadcastStageModel: ObservableObject {
    @Published var activeLayout: BroadcastLayoutPreset = .split
    
    // We maintain a fixed 4-slot array, interpreting it differently based on the layout
    // Slot 0: Main/Top Left
    // Slot 1: Top Right (Quad) or Right Top (Split)
    // Slot 2: Bottom Left (Quad) or Empty (Split)
    // Slot 3: Bottom Right (Quad) or Right Bottom (Split)
    @Published var slots: [BroadcastSlotContent] = [.map, .camera(id: "F50-1"), .empty, .camera(id: "F50-2")]
    
    func dropItem(in slotIndex: Int, item: BroadcastDragItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch item.contentType {
            case "map":
                slots[slotIndex] = .map
            case "camera":
                slots[slotIndex] = .camera(id: item.id)
            case "replay":
                slots[slotIndex] = .replay
            case "jury":
                slots[slotIndex] = .jury
            default:
                break
            }
        }
    }
}
