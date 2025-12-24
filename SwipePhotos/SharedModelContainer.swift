import Foundation
import SwiftData

// MARK: - Placeholder Photo Model for SwiftData
@Model
class PhotoModel {
    var id: UUID
    var timestamp: Date
    var caption: String

    init(id: UUID = UUID(), timestamp: Date = Date(), caption: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.caption = caption
    }
}

class SharedModelContainer {
    static let shared = SharedModelContainer()
    let container: ModelContainer

    private init() {
        let schema = Schema([PhotoModel.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.manan.OneNada.app")
        )

        do {
            container = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            // If migration fails, delete the old database and create a new one
            print("⚠️ Migration failed, recreating database: \(error)")

            // Get the store URL
            let storeURL = modelConfiguration.url

            // Delete the old store files
            let fileManager = FileManager.default
            let storePath = storeURL.path
            let shmPath = storePath + "-shm"
            let walPath = storePath + "-wal"

            try? fileManager.removeItem(atPath: storePath)
            try? fileManager.removeItem(atPath: shmPath)
            try? fileManager.removeItem(atPath: walPath)

            print("✅ Old database files deleted, creating new database...")

            // Try creating the container again
            do {
                container = try ModelContainer(for: schema, configurations: modelConfiguration)
                print("✅ New database created successfully")
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }
}
