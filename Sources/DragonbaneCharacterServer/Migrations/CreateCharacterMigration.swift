import Fluent

struct CreateCharacterMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("characters")
            .field("id", .int, .identifier(auto: true))
            .field("name", .string, .required)
            .field("race", .string, .required)
            .field("profession", .string, .required)
            .field("age", .string, .required)
            .field("strength", .int, .required)
            .field("constitution", .int, .required)
            .field("agility", .int, .required)
            .field("intelligence", .int, .required)
            .field("willpower", .int, .required)
            .field("charisma", .int, .required)
            .field("heroic_abilities", .array(of: .string), .required)
            .field("trained_skills", .array(of: .string), .required)
            .field("magic", .array(of: .string), .required)
            .field("gear", .array(of: .string), .required)
            .field("appearance_seeds", .array(of: .string), .required)
            .field("weakness", .string, .required)
            .field("memento", .string, .required)
            .field("appearance", .string, .required)
            .field("background", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("characters").delete()
    }
}
