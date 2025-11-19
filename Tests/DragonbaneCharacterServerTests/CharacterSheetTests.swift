import XCTVapor
import DragonbaneCharacterCore
@testable import DragonbaneCharacterServer

final class CharacterSheetTests: XCTestCase {
    func testAdoptFetchAndUpdateSheet() throws {
        let app = try makeTestApp()
        defer { app.shutdown() }

        let characterModel = CharacterModel(character: generateCompleteCharacter())
        try characterModel.create(on: app.db).wait()
        let characterID = try XCTUnwrap(characterModel.id)

        let adoptPayload = CharacterSheetController.AdoptRequest(characterID: characterID, playerName: "Tester")
        var sheetResponse: CharacterSheetResponse!
        try app.test(.POST, "/api/sheets/adopt", beforeRequest: { req in
            try req.content.encode(adoptPayload)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            sheetResponse = try res.content.decode(CharacterSheetResponse.self)
            XCTAssertEqual(sheetResponse.data.characterName, characterModel.name)
            XCTAssertEqual(sheetResponse.data.playerName, "Tester")
        }

        let sheetId = sheetResponse.sheetId
        try app.test(.GET, "/api/sheets/\(sheetId)") { res in
            XCTAssertEqual(res.status, .ok)
            let fetched = try res.content.decode(CharacterSheetResponse.self)
            XCTAssertEqual(fetched.sheetId, sheetId)
        }

        var updatedPayload = sheetResponse.data
        updatedPayload.notes = "Ready for adventure"
        if !updatedPayload.weapons.isEmpty {
            updatedPayload.weapons[0].name = "Great Sword"
            updatedPayload.weapons[0].damage = "1D10"
        }

        try app.test(.PUT, "/api/sheets/\(sheetId)", beforeRequest: { req in
            try req.content.encode(updatedPayload)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let updatedResponse = try res.content.decode(CharacterSheetResponse.self)
            XCTAssertEqual(updatedResponse.data.notes, "Ready for adventure")
            XCTAssertEqual(updatedResponse.data.weapons.first?.name, "Great Sword")
        }
    }

    // MARK: - Helpers

    private func makeTestApp() throws -> Application {
        let app = Application(.testing)
        try configure(app)
        try app.autoMigrate().wait()
        return app
    }
}
