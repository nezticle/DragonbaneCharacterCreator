import XCTVapor
import DragonbaneCharacterCore
@testable import DragonbaneCharacterServer

final class CharacterAdminTests: XCTestCase {
    func testBulkGenerateCreatesRequestedCharacters() throws {
        let app = try makeTestApp()
        defer { app.shutdown() }

        let payload = CharacterController.BulkGenerateRequest(
            count: 3,
            race: .human,
            profession: nil,
            age: nil,
            name: nil,
            background: nil,
            appearance: nil,
            narrativeMode: nil,
            llmServer: nil,
            llmModel: nil,
            llmApiKey: nil
        )

        try app.test(.POST, "/api/characters/bulk-generate", beforeRequest: { req in
            try req.content.encode(payload)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let characters = try res.content.decode([CharacterResponse].self)
            XCTAssertEqual(characters.count, 3)
            XCTAssertTrue(characters.allSatisfy { $0.race == .human })
        }

        let storedCount = try CharacterModel.query(on: app.db).count().wait()
        XCTAssertEqual(storedCount, 3)
    }

    func testDeleteRemovesCharacterFromDatabase() throws {
        let app = try makeTestApp()
        defer { app.shutdown() }

        let model = CharacterModel(character: generateCompleteCharacter())
        try model.create(on: app.db).wait()
        let id = try XCTUnwrap(model.id)

        try app.test(.DELETE, "/api/characters/\(id)") { res in
            XCTAssertEqual(res.status, .noContent)
        }

        let remaining = try CharacterModel.find(id, on: app.db).wait()
        XCTAssertNil(remaining)
    }

    // MARK: - Helpers

    private func makeTestApp() throws -> Application {
        let app = Application(.testing)
        try configure(app)
        try app.autoMigrate().wait()
        return app
    }
}
