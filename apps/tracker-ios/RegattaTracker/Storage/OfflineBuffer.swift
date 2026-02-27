import Foundation
import GRDB
import CoreLocation

// Define the model for a tracked position epoch
struct BufferedPosition: Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: Int64?
    var sessionId: String
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var course: Double
    var speed: Double
    var isUWB: Bool
    var dtlCm: Double?
    
    // Auto-incrementing ID
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class OfflineBuffer: ObservableObject {
    static let shared = OfflineBuffer()
    private var dbQueue: DatabaseQueue?
    
    init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbURL = appSupportURL.appendingPathComponent("regatta_buffer.sqlite")
            
            dbQueue = try DatabaseQueue(path: dbURL.path)
            try migrator.migrate(dbQueue!)
        } catch {
            print("OfflineBuffer Initialization Error: \(error)")
        }
    }
    
    // Database schema
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "bufferedPosition") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sessionId", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("course", .double).notNull()
                t.column("speed", .double).notNull()
                t.column("isUWB", .boolean).notNull().defaults(to: false)
                t.column("dtlCm", .double)
            }
        }
        return migrator
    }
    
    func bufferPosition(_ position: BufferedPosition) {
        do {
            try dbQueue?.write { db in
                var pos = position
                try pos.insert(db)
            }
        } catch {
            print("Failed to buffer position: \(error)")
        }
    }
    
    func fetchAllBuffered() -> [BufferedPosition] {
        do {
            return try dbQueue?.read { db in
                try BufferedPosition.fetchAll(db)
            } ?? []
        } catch {
            print("Failed to fetch buffered positions: \(error)")
            return []
        }
    }
    
    func clearBuffered(upTo id: Int64) {
        do {
            try dbQueue?.write { db in
                _ = try BufferedPosition.filter(Column("id") <= id).deleteAll(db)
            }
        } catch {
            print("Failed to clear buffered positions: \(error)")
        }
    }
}
