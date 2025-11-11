import Vapor
import Fluent
import DragonbaneCharacterCore

struct CharacterController {
    struct GenerateRequest: Content {
        let race: Race?
        let profession: Profession?
        let age: Age?
        let name: String?
        let background: String?
        let appearance: String?
    }

    func index(_ req: Request) async throws -> [CharacterResponse] {
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 200)
        var query = CharacterModel.query(on: req.db)
        let raceFilters = parseEnumQuery(req, key: "kin", type: Race.self)
        let professionFilters = parseEnumQuery(req, key: "profession", type: Profession.self)

        if !raceFilters.isEmpty {
            query = query.filter(\.$race ~~ raceFilters.map { $0.rawValue })
        }
        if !professionFilters.isEmpty {
            query = query.filter(\.$profession ~~ professionFilters.map { $0.rawValue })
        }

        let models = try await query.sort(\.$id, .descending).limit(limit).all()
        return try models.map { try $0.toResponse() }
    }

    func fetch(_ req: Request) async throws -> CharacterResponse {
        let model = try await requireModel(req)
        return try model.toResponse()
    }

    func random(_ req: Request) async throws -> CharacterResponse {
        var query = CharacterModel.query(on: req.db)
        let raceFilters = parseEnumQuery(req, key: "kin", type: Race.self)
        let professionFilters = parseEnumQuery(req, key: "profession", type: Profession.self)

        if !raceFilters.isEmpty {
            query = query.filter(\.$race ~~ raceFilters.map { $0.rawValue })
        }
        if !professionFilters.isEmpty {
            query = query.filter(\.$profession ~~ professionFilters.map { $0.rawValue })
        }

        let models = try await query.all()
        guard let random = models.randomElement() else {
            throw Abort(.notFound, reason: "No characters match the supplied filters")
        }
        return try random.toResponse()
    }

    func generate(_ req: Request) async throws -> CharacterResponse {
        let payload = try? req.content.decode(GenerateRequest.self)
        let filters = GenerationFilters(
            race: payload?.race,
            profession: payload?.profession,
            age: payload?.age
        )

        let character = try generateCharacter(matching: filters)
        let model = CharacterModel(character: character)
        if let name = payload?.name { model.name = name }
        if let background = payload?.background { model.background = background }
        if let appearance = payload?.appearance { model.appearance = appearance }

        try await model.create(on: req.db)
        return try model.toResponse()
    }

    func update(_ req: Request) async throws -> CharacterResponse {
        let updatePayload = try req.content.decode(CharacterUpdateRequest.self)
        let model = try await requireModel(req)
        model.apply(update: updatePayload)
        try await model.update(on: req.db)
        return try model.toResponse()
    }

    private func requireModel(_ req: Request) async throws -> CharacterModel {
        guard let id = req.parameters.get("characterID", as: Int.self) else {
            throw Abort(.badRequest, reason: "Missing character identifier")
        }
        guard let model = try await CharacterModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Character #\(id) was not found")
        }
        return model
    }

    private func parseEnumQuery<T: RawRepresentable>(_ req: Request, key: String, type: T.Type) -> [T] where T.RawValue == String {
        guard let value = req.query[String.self, at: key] else { return [] }
        let components = value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return components.compactMap { T(rawValue: String($0)) }
    }

    private struct GenerationFilters {
        let race: Race?
        let profession: Profession?
        let age: Age?

        func matches(_ character: Character) -> Bool {
            if let race, character.race != race { return false }
            if let profession, character.profession != profession { return false }
            if let age, character.age != age { return false }
            return true
        }
    }

    private func generateCharacter(matching filters: GenerationFilters) throws -> Character {
        let maxAttempts = 1000
        for _ in 0..<maxAttempts {
            let candidate = generateCompleteCharacter()
            if filters.matches(candidate) {
                return candidate
            }
        }
        throw Abort(.internalServerError, reason: "Unable to satisfy the requested generation filters after \(maxAttempts) attempts")
    }
}
