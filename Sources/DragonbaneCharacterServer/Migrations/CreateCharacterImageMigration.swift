import Fluent

struct CreateCharacterImageMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("character_images")
            .field("id", .int, .identifier(auto: true))
            .field("character_id", .int, .required, .references("characters", "id", onDelete: .cascade))
            .field("data", .data, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("character_images").delete()
    }
}
