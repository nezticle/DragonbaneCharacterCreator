import Vapor
import Fluent
import Foundation
import DragonbaneCharacterCore

struct CharacterImageController {
    struct GenerateImageRequest: Content {
        let server: String?
        let apiKey: String?
        let model: String?
        let quality: String?
        let background: String?
    }

    struct ImageSummaryResponse: Content {
        let id: Int
        let characterId: Int
        let createdAt: Date?
        let downloadURL: String
    }

    func list(_ req: Request) async throws -> [ImageSummaryResponse] {
        let character = try await requireCharacter(req)
        guard let characterId = character.id else {
            throw Abort(.internalServerError, reason: "Character identifier missing.")
        }
        let images = try await CharacterImageModel.query(on: req.db)
            .filter(\.$character.$id == characterId)
            .sort(\.$id, .descending)
            .all()
        return images.compactMap { summary(for: $0, characterID: characterId, on: req) }
    }

    func generate(_ req: Request) async throws -> ImageSummaryResponse {
        let character = try await requireCharacter(req)
        guard let characterId = character.id else {
            throw Abort(.internalServerError, reason: "Character identifier missing.")
        }
        let payload = try? req.content.decode(GenerateImageRequest.self)
        let config = try ImageGenerationConfig(payload: payload)
        let characterDetails = try character.toCharacter()
        let prompt = buildPrompt(for: characterDetails)
        let imageData = try await requestImage(prompt: prompt, config: config, req: req)

        let image = CharacterImageModel(characterID: characterId, data: imageData)
        try await image.create(on: req.db)
        guard image.id != nil else {
            throw Abort(.internalServerError, reason: "Failed to persist generated image.")
        }
        guard let response = summary(for: image, characterID: characterId, on: req) else {
            throw Abort(.internalServerError, reason: "Unable to build image metadata response.")
        }
        return response
    }

    func fetchBinary(_ req: Request) async throws -> Response {
        let character = try await requireCharacter(req)
        guard let characterId = character.id else {
            throw Abort(.internalServerError, reason: "Character identifier missing.")
        }
        let image = try await requireImage(req, characterID: characterId)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "image/webp")
        return Response(status: .ok, headers: headers, body: .init(data: image.data))
    }

    // MARK: - Helpers

    private func summary(for model: CharacterImageModel, characterID: Int, on req: Request) -> ImageSummaryResponse? {
        guard let id = model.id else { return nil }
        return ImageSummaryResponse(
            id: id,
            characterId: characterID,
            createdAt: model.createdAt,
            downloadURL: "/api/characters/\(characterID)/images/\(id)"
        )
    }

    private func requireCharacter(_ req: Request) async throws -> CharacterModel {
        guard let id = req.parameters.get("characterID", as: Int.self) else {
            throw Abort(.badRequest, reason: "Missing character identifier.")
        }
        guard let model = try await CharacterModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Character #\(id) was not found.")
        }
        return model
    }

    private func requireImage(_ req: Request, characterID: Int) async throws -> CharacterImageModel {
        guard let id = req.parameters.get("imageID", as: Int.self) else {
            throw Abort(.badRequest, reason: "Missing image identifier.")
        }
        guard let image = try await CharacterImageModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Image #\(id) was not found.")
        }
        guard image.$character.id == characterID else {
            throw Abort(.notFound, reason: "Image #\(id) does not belong to character #\(characterID).")
        }
        return image
    }

    private func buildPrompt(for character: Character) -> String {
        """
        Create an image using the character details provided using the following style:

        A storybook-meets-gritty-fantasy illustration style, with strong ties to tabletop RPG character art. Blends high-detail line work with a dark medieval fairy tale aesthetic, offering both charm and menace.

        Style Features:

        1. Illustration Medium and Technique
            • Digital emulation of traditional ink and wash: Visible line art overlays a wash-style color treatment that mimics watercolor or gouache.

        2. Character Design
            • Stylized but grounded anatomy: Characters are exaggerated just enough for flair without crossing into cartoon territory. Muscles, posture, and proportions emphasize archetype (e.g., brawny barbarian, wiry rogue).
            • Expressive faces: Strong line work and brow shaping create intense or quirky facial expressions that convey personality quickly.
            • Detailed costuming: Every outfit has a layered, practical, and slightly ragged quality, common to medieval fantasy and hinting at lived-in worlds.
            • Fur, metal, and leather are common materials, often rendered with textured shading.

        3. Composition and Silhouette
            • Dynamic, readable silhouettes: Characters are posed to show role or emotion, often mid-action or ready for it.

        4. Iconography and Themes
            • Fantasy RPG tropes: Warriors, rogues, trolls, and pirates, all firmly placed in a high fantasy context.
            • Macabre whimsy

        Summary Phrase

        “Ink-washed fantasy with grim whimsy and character-rich exaggeration, drawn from the pages of a well-worn adventurer’s guide.”

        Just the character, background should be transparent.

        Here is the character sheet:
        \(character.shortDescription())
        """
    }

    private func requestImage(prompt: String, config: ImageGenerationConfig, req: Request) async throws -> Data {
        let uri = try config.imagesURI()
        let response: ClientResponse
        do {
            response = try await req.client.post(uri) { clientReq in
                clientReq.headers.contentType = .json
                if let apiKey = config.apiKey {
                    clientReq.headers.bearerAuthorization = .init(token: apiKey)
                }
                let payload = ImageGenerationPayload(
                    model: config.model,
                    prompt: prompt,
                    n: 1,
                    quality: config.quality,
                    background: config.background,
                    outputFormat: "webp"
                )
                try clientReq.content.encode(payload)
            }
        } catch {
            req.logger.error("Failed to reach image server: \(error.localizedDescription)")
            throw Abort(.badGateway, reason: "Unable to reach the image server at \(config.server)")
        }

        guard response.status == .ok else {
            let body = response.body.flatMap { String(buffer: $0) } ?? "No response body"
            req.logger.warning("Image server returned \(response.status.code): \(body)")
            throw Abort(.badGateway, reason: "Image server returned status \(response.status.code)")
        }

        let decoded = try response.content.decode(ImageGenerationAPIResponse.self)
        guard let base64 = decoded.data.first?.b64_json,
              let data = Data(base64Encoded: base64) else {
            throw Abort(.badGateway, reason: "Image server response did not include usable image data.")
        }
        return data
    }
}

// MARK: - Image generation support types

private struct ImageGenerationPayload: Content {
    let model: String
    let prompt: String
    let n: Int
    let quality: String
    let background: String
    let outputFormat: String

    enum CodingKeys: String, CodingKey {
        case model, prompt, n, quality, background
        case outputFormat = "output_format"
    }
}

private struct ImageGenerationAPIResponse: Decodable {
    struct Entry: Decodable {
        let b64_json: String
    }
    let data: [Entry]
}

private struct ImageGenerationConfig {
    let server: String
    let apiKey: String?
    let model: String
    let quality: String
    let background: String

    init(payload: CharacterImageController.GenerateImageRequest?) throws {
        let defaultServer = Environment.get("IMAGE_SERVER") ?? Environment.get("OPENAI_SERVER") ?? "https://api.openai.com"
        let defaultModel = Environment.get("IMAGE_MODEL") ?? "gpt-image-1"
        let defaultApiKey = Environment.get("IMAGE_API_KEY") ?? Environment.get("OPENAI_API_KEY")

        guard let server = payload?.server?.trimmedOrNil ?? defaultServer.trimmedOrNil else {
            throw Abort(.badRequest, reason: "Image server URL is required.")
        }
        self.server = server
        self.apiKey = payload?.apiKey?.trimmedOrNil ?? defaultApiKey?.trimmedOrNil
        self.model = payload?.model?.trimmedOrNil ?? defaultModel
        self.quality = payload?.quality?.trimmedOrNil ?? "high"
        self.background = payload?.background?.trimmedOrNil ?? "transparent"
    }

    func imagesURI() throws -> URI {
        var trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else {
            throw Abort(.badRequest, reason: "Image server URL is required.")
        }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("/v1/images/generations") {
            return URI(string: trimmed)
        }
        if lowercased.hasSuffix("/v1/images") {
            return URI(string: "\(trimmed)/generations")
        }
        if lowercased.hasSuffix("/v1") {
            return URI(string: "\(trimmed)/images/generations")
        }
        return URI(string: "\(trimmed)/v1/images/generations")
    }
}
