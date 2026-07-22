import Foundation
import SwiftData

// MARK: - AppDatabase
//
// The single SwiftData stack for the whole app. Everything that persists —
// stress drops, release sessions, calm habits and the game economy — lives in
// one ModelContainer so views and the Game facade share the same mainContext.
//
// Built defensively: if the on-disk store can't be opened (a bad migration,
// a corrupt file, a read-only volume) we fall back to an in-memory container
// so the app still launches instead of crashing on a `try!`.

enum AppDatabase {
    static let container: ModelContainer = {
        let schema = Schema([
            StressDrop.self,
            ReleaseSession.self,
            Habit.self,
            GameState.self,
        ])

        // Preferred: the normal on-disk store.
        if let onDisk = try? ModelContainer(for: schema) {
            return onDisk
        }

        // Fallback: an in-memory store. Data won't survive relaunch, but the
        // app stays usable for this session rather than dying at startup.
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let inMemory = try? ModelContainer(for: schema, configurations: memoryConfig) {
            return inMemory
        }

        // Last resort: an unconfigured in-memory container. Creating an
        // in-memory store for a valid schema does not realistically fail.
        return try! ModelContainer(for: schema, configurations: memoryConfig)
    }()
}
