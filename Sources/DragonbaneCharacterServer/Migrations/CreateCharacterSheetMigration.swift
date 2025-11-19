import Fluent

struct CreateCharacterSheetMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("character_sheets")
            .id()
            .field("character_id", .int, .references("characters", "id", onDelete: .setNull, onUpdate: .cascade))
            .field("token", .string, .required)
            .unique(on: "token")
            .field("payload", .json, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("character_sheets").delete()
    }
}
