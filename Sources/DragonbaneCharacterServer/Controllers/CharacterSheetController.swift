import Vapor
import Fluent

struct CharacterSheetController {
    struct AdoptRequest: Content {
        let characterID: Int
        let playerName: String?
    }

    func adopt(_ req: Request) async throws -> CharacterSheetResponse {
        let payload = try req.content.decode(AdoptRequest.self)
        guard let model = try await CharacterModel.find(payload.characterID, on: req.db) else {
            throw Abort(.notFound, reason: "Character #\(payload.characterID) was not found")
        }

        let character = try model.toResponse()
        var sheetPayload = CharacterSheetPayload.from(character: character, playerName: payload.playerName)
        sheetPayload.normalize()
        let token = try await generateUniqueToken(on: req.db)
        let sheet = CharacterSheetModel(characterID: model.id, token: token, payload: sheetPayload)
        try await sheet.create(on: req.db)
        req.logger.info("Created character sheet \(token) for character #\(model.id ?? 0)")
        return CharacterSheetResponse(model: sheet)
    }

    func fetch(_ req: Request) async throws -> CharacterSheetResponse {
        let sheet = try await requireSheet(req)
        return CharacterSheetResponse(model: sheet)
    }

    func update(_ req: Request) async throws -> CharacterSheetResponse {
        var payload = try req.content.decode(CharacterSheetPayload.self)
        payload.normalize()
        let sheet = try await requireSheet(req)
        sheet.payload = payload
        try await sheet.update(on: req.db)
        return CharacterSheetResponse(model: sheet)
    }

    // MARK: - Helpers

    private func requireSheet(_ req: Request) async throws -> CharacterSheetModel {
        guard let token = req.parameters.get("sheetID")?.lowercased() else {
            throw Abort(.badRequest, reason: "Missing sheet identifier")
        }
        guard let sheet = try await CharacterSheetModel.query(on: req.db)
            .filter(\.$token == token)
            .first() else {
            throw Abort(.notFound, reason: "Character sheet \(token) was not found")
        }
        return sheet
    }

    private func generateUniqueToken(on db: Database) async throws -> String {
        for _ in 0..<10 {
            let token = CharacterSheetController.randomToken()
            let existing = try await CharacterSheetModel.query(on: db)
                .filter(\.$token == token)
                .first()
            if existing == nil {
                return token
            }
        }
        throw Abort(.internalServerError, reason: "Unable to allocate a unique sheet token")
    }

    private static func randomToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

struct CharacterSheetResponse: Content {
    let sheetId: String
    let characterId: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let data: CharacterSheetPayload

    init(model: CharacterSheetModel) {
        self.sheetId = model.token
        self.characterId = model.$character.id
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.data = model.payload
    }
}
