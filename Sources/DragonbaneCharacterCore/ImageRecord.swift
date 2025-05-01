import Foundation
import GRDB

/// A record for storing generated images associated with characters.
public struct ImageRecord: Codable, FetchableRecord, PersistableRecord {
    /// Auto-incremented image record ID.
    public var id: Int64?
    /// The ID of the character this image belongs to.
    public var characterId: Int64
    /// Binary data of the image (webp or original format).
    public var data: Data

    /// Create a new image record.
    public init(id: Int64? = nil, characterId: Int64, data: Data) {
        self.id = id
        self.characterId = characterId
        self.data = data
    }

    public static let databaseTableName = "image"
}

public extension ImageRecord {
    /// Fetch all images for a given character ID.
    static func fetchByCharacterId(_ characterId: Int64) throws -> [ImageRecord] {
        try DB.queue.read { db in
            try ImageRecord.fetchAll(db, sql: "SELECT * FROM image WHERE characterId = ? ORDER BY id", arguments: [characterId])
        }
    }
}