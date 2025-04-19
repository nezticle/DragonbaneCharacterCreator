import Foundation
import GRDB

// MARK: - Global DB handle
public enum DB {
    /// The single, shared SQLite connection pool.
    public static let queue: DatabaseQueue = {
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Dragonbane", isDirectory: true)
        try? FileManager.default.createDirectory(at: root,
                                                 withIntermediateDirectories: true)
        let dbPath = root.appendingPathComponent("dragonbane.sqlite").path
        print ("DB path: \(dbPath)")

        // ❷ Create queue and run migrations
        do {
            let q = try DatabaseQueue(path: dbPath)
            try migrator.migrate(q)
            return q
        } catch {
            fatalError("💥 Unable to open database: \(error)")   // fail fast
        }
    }()

    /// All schema changes live here.
    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        m.registerMigration("v1_character") { db in
            try db.create(table: "character") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("race", .text).notNull()
                t.column("profession", .text).notNull()
                t.column("age", .text).notNull()

                t.column("strength", .integer).notNull()
                t.column("constitution", .integer).notNull()
                t.column("agility", .integer).notNull()
                t.column("intelligence", .integer).notNull()
                t.column("willpower", .integer).notNull()
                t.column("charisma", .integer).notNull()

                // arrays → JSON blobs
                t.column("heroicAbilities", .text).notNull()
                t.column("trainedSkills", .text).notNull()
                t.column("magic", .text).notNull()
                t.column("gear", .text).notNull()
                t.column("appearanceSeeds", .text).notNull()

                t.column("weakness", .text).notNull()
                t.column("memento", .text).notNull()
                t.column("appearance", .text).notNull()
                t.column("background", .text).notNull()
            }
        }

        return m
    }
}

public extension CharacterRecord {
    /// Insert and return row id.
    mutating func save() throws -> Int64 {
        try DB.queue.write { db in
            // `record` must be var so GRDB can assign the auto‑id
            try insert(db)
            return id ?? db.lastInsertedRowID
        }
    }

    static func fetchAll() throws -> [CharacterRecord] {
        try DB.queue.read { db in try CharacterRecord.fetchAll(db) }
    }
}