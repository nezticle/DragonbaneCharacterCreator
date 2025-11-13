import Vapor
import Fluent
import DragonbaneCharacterCore
import Foundation

struct CharacterController {
    struct GenerateRequest: Content {
        let race: Race?
        let profession: Profession?
        let age: Age?
        let name: String?
        let background: String?
        let appearance: String?
        let narrativeMode: NarrativeMode?
        let llmServer: String?
        let llmModel: String?
        let llmApiKey: String?

        enum NarrativeMode: String, Content {
            case offline
            case llm
        }
    }

    struct BulkGenerateRequest: Content {
        let count: Int
        let race: Race?
        let profession: Profession?
        let age: Age?
        let name: String?
        let background: String?
        let appearance: String?
        let narrativeMode: GenerateRequest.NarrativeMode?
        let llmServer: String?
        let llmModel: String?
        let llmApiKey: String?

        func asGenerateRequest() -> GenerateRequest {
            GenerateRequest(
                race: race,
                profession: profession,
                age: age,
                name: name,
                background: background,
                appearance: appearance,
                narrativeMode: narrativeMode,
                llmServer: llmServer,
                llmModel: llmModel,
                llmApiKey: llmApiKey
            )
        }
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
        let model = try await createCharacter(from: payload, on: req)
        return try model.toResponse()
    }

    func bulkGenerate(_ req: Request) async throws -> [CharacterResponse] {
        let payload = try req.content.decode(BulkGenerateRequest.self)
        let count = min(max(payload.count, 1), 20)
        var responses: [CharacterResponse] = []
        for _ in 0..<count {
            let model = try await createCharacter(from: payload.asGenerateRequest(), on: req)
            responses.append(try model.toResponse())
        }
        return responses
    }

    func delete(_ req: Request) async throws -> HTTPStatus {
        let model = try await requireModel(req)
        try await model.delete(on: req.db)
        return .noContent
    }

    private func createCharacter(from payload: GenerateRequest?, on req: Request) async throws -> CharacterModel {
        let filters = GenerationFilters(
            race: payload?.race,
            profession: payload?.profession,
            age: payload?.age
        )

        var character = try generateCharacter(matching: filters)
        if (payload?.narrativeMode ?? .offline) == .llm {
            let config = llmConfig(from: payload)
            if let summary = try await enrichNarrative(for: character, config: config, on: req) {
                if payload?.name == nil { character.setName(summary.name) }
                if payload?.appearance == nil { character.setAppearance(summary.appearance) }
                if payload?.background == nil { character.setBackground(summary.background) }
            }
        }

        let model = CharacterModel(character: character)
        if let name = payload?.name { model.name = name }
        if let background = payload?.background { model.background = background }
        if let appearance = payload?.appearance { model.appearance = appearance }

        try await model.create(on: req.db)
        return model
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

    private func enrichNarrative(for character: Character, config: LLMGenerationConfig, on req: Request) async throws -> CharacterSummary? {
        let prompt = """
        I'm going to give you details for a character in the Table Top Roleplaying game Dragonbane, and you are going to create the missing details based on this information.
        Please create a JSON object with the following keys:
        - "name": create a name for this character based off of the kin/race and background you create,
        - "appearance": create a description of this character's appearance based on the information provided,
        - "background": create a plausible background for this character based on the information provided

        Your output must be valid JSON in the following format:

        {
            "name": "Firstname Lastname",
            "appearance": "A one-paragraph description of the character's appearance.",
            "background": "A one-paragraph description of the character's background."
        }

        Only respond with this JSON.

        --

        Here is the character:
        \(character.description())
        """

        let uri = try config.completionsURI()
        let response: ClientResponse
        do {
            response = try await req.client.post(uri) { clientReq in
                clientReq.headers.contentType = .json
                if let key = config.apiKey {
                    clientReq.headers.bearerAuthorization = .init(token: key)
                }
                let payload = ChatCompletionRequest(
                    model: config.model,
                    messages: [
                        .init(role: "system", content: "You are a creative fantasy story generator."),
                        .init(role: "user", content: prompt)
                    ],
                    stream: false
                )
                try clientReq.content.encode(payload)
            }
        } catch {
            req.logger.error("Failed to reach LLM server: \(error.localizedDescription)")
            throw Abort(.badGateway, reason: "Unable to reach the LLM server at \(config.server)")
        }

        guard response.status == .ok else {
            let body = response.body.flatMap { String(buffer: $0) } ?? "No response body"
            req.logger.warning("LLM server returned \(response.status.code): \(body)")
            throw Abort(.badGateway, reason: "LLM server returned status \(response.status.code)")
        }

        let completion = try response.content.decode(ChatCompletionResponse.self)
        guard let content = completion.choices.first?.message.content,
              let summary = parseSummary(from: content) else {
            req.logger.warning("LLM response missing usable content")
            throw Abort(.badGateway, reason: "LLM response did not contain usable narrative content")
        }
        return summary
    }

    private func parseSummary(from raw: String) -> CharacterSummary? {
        var text = raw
        if let endThink = text.range(of: "</think>") {
            text = String(text[endThink.upperBound...])
        }
        text = text.replacingOccurrences(of: "```json", with: "")
        text = text.replacingOccurrences(of: "```", with: "")
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        let jsonSlice = text[firstBrace...lastBrace]
        guard let data = String(jsonSlice).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CharacterSummary.self, from: data)
    }

    private func llmConfig(from payload: GenerateRequest?) -> LLMGenerationConfig {
        let defaultServer = Environment.get("LLM_SERVER") ?? "http://flyndre.local:1234"
        let defaultModel = Environment.get("LLM_MODEL") ?? "deepseek-r1-distill-qwen-7b"
        return LLMGenerationConfig(
            server: payload?.llmServer?.trimmedOrNil ?? defaultServer,
            model: payload?.llmModel?.trimmedOrNil ?? defaultModel,
            apiKey: payload?.llmApiKey?.trimmedOrNil
        )
    }
}

private struct CharacterSummary: Decodable {
    let name: String
    let appearance: String
    let background: String
}

private struct ChatCompletionRequest: Content {
    struct Message: Content {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct LLMGenerationConfig {
    let server: String
    let model: String
    let apiKey: String?

    func completionsURI() throws -> URI {
        guard !server.isEmpty else {
            throw Abort(.badRequest, reason: "LLM server URL is missing.")
        }
        var trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        let lowercased = trimmed.lowercased()
        if lowercased.contains("/v1/chat/completions") {
            return URI(string: trimmed)
        }
        if lowercased.hasSuffix("/v1") {
            return URI(string: "\(trimmed)/chat/completions")
        }
        return URI(string: "\(trimmed)/v1/chat/completions")
    }
}
