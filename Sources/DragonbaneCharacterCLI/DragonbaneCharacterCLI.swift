import DragonbaneCharacterCore
import DragonbaneCharacterPersistence
import ArgumentParser
import Foundation

struct CharacterSummary: Codable {
    let name: String
    let appearance: String
    let background: String
}

func parseSummary(from raw: String) -> CharacterSummary? {
    var s = raw
    // Drop the reasoning block if present
    if let endThink = s.range(of: "</think>") {
        s = String(s[endThink.upperBound...])
    }
    // Remove any markdown code fences
    s = s.replacingOccurrences(of: "```json", with: "")
    s = s.replacingOccurrences(of: "```", with: "")

    // Find first and last braces
    guard let first = s.firstIndex(of: "{"),
          let last = s.lastIndex(of: "}") else {
        return nil
    }
    let jsonText = String(s[first...last])
    guard let data = jsonText.data(using: .utf8) else {
        return nil
    }
    return try? JSONDecoder().decode(CharacterSummary.self, from: data)
}

final class OpenAIStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    var onToken: ((String) -> Void)?
    var onCompletion: (() -> Void)?
    private var buffer = Data()
    /// HTTP status code for the response, if known.
    private var statusCode: Int?

    /// Captures the initial HTTP response so we can surface non‑200 problems early.
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            statusCode = http.statusCode
            if http.statusCode != 200 {
                print("\n[HTTP Error] Response status code: \(http.statusCode)")
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                task: URLSessionTask,
                didCompleteWithError error: Error?) {
        if let error = error as? URLError, error.code == .cancelled {
            // Ignore cancellation errors
            return
        }
        if let error = error {
            print("\n[Error] Story generation failed: \(error.localizedDescription)")
        }
        // Surface HTTP‑level errors that did not raise a URL error.
        if let code = statusCode, code != 200 {
            print("[Error] Request finished with HTTP status \(code)")
        }
        onCompletion?()  // signal the semaphore
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // If we already know the request failed, dump the body and stop parsing for tokens.
        if let code = statusCode, code != 200 {
            if let body = String(data: data, encoding: .utf8) {
                print("\n[OpenAI Error Body] \(body)")
            }
            buffer.removeAll()
            return
        }
        buffer.append(data)
        if let text = String(data: buffer, encoding: .utf8) {
            let lines = text.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("data: ") {
                    let payload = trimmed.dropFirst("data: ".count)
                    if payload == "[DONE]" {
                        buffer.removeAll()
                        self.onCompletion?()
                        return
                    }
                    if let jsonData = payload.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let token = delta["content"] as? String {
                        onToken?(token)
                    }
                }
            }
            buffer.removeAll()
        }
    }
}

@main
struct DragonbaneCharacterCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A command-line tool for generating Dragonbane characters.",
        discussion: "In interactive mode, you can enter commands to generate characters, view help, or exit.",
        version: "1.0.0"
    )

    @Option(name: [.short, .long], help: "Server address for /v1/chat/completions calls. Can be overridden by the OPENAI_SERVER environment variable.")
    var server: String?

    @Option(name: [.short, .long], help: "API key for /v1/chat/completions calls. Can be overridden by the OPENAI_API_KEY environment variable.")
    var apiKey: String?

    @Option(name: [.short, .long], help: "Model for /v1/chat/completions calls. Can be overridden by the OPENAI_MODEL environment variable.")
    var model: String?

    /// Number of characters to generate (default 1).
    @Option(name: [.short, .long], help: "Number of characters to generate (default 1).")
    var count: Int = 1
    /// Print a random saved character from the database and exit.
    @Flag(name: [.short, .long], help: "Print a random saved character from the database and exit.")
    var random: Bool = false
    /// Print statistics about saved characters and exit.
    @Flag(name: [.long], help: "Print statistics about saved characters and exit.")
    var stats: Bool = false
    /// Print a saved character by id and exit.
    @Option(name: [.long], help: "Print the character description for the given id and exit.")
    var printId: Int?
    /// Generate an image for an existing character by id.
    @Option(name: [.long], help: "Generate an image for the existing character with the given id.")
    var imageId: Int?

/// Print database statistics to stdout.
func printStats() throws {
    let stats = try CharacterRecord.stats()
    print("Total characters: \(stats.total)")

    print("By kin:")
    for (race, count) in stats.byRace {
        print("  \(race): \(count)")
    }

    print("By profession:")
    for (profession, count) in stats.byProfession {
        print("  \(profession): \(count)")
    }
}
    mutating func run() async throws {
        // Handle --stats mode
        if stats {
            do {
                try printStats()
            } catch {
                print("[DB Error] \(error)")
                throw ExitCode.failure
            }
            return
        }
        // If random flag is set, fetch and display a random character.
        if random {
            do {
                if let rec = try CharacterRecord.fetchRandom() {
                    let character = rec.toCharacter()
                    print(character.description())
                } else {
                    print("No characters found in database.")
                }
            } catch {
                print("[DB Error] \(error)")
                throw ExitCode.failure
            }
            return
        }
        // Handle print-by-id mode
        if let id = printId {
            do {
                let record = try await DB.queue.read { db in
                    try CharacterRecord.fetchOne(db, key: Int64(id))
                }
                if let rec = record {
                    let character = rec.toCharacter()
                    print(character.description())
                } else {
                    print("No character found with id \(id)")
                }
            } catch {
                print("[DB Error] \(error)")
                throw ExitCode.failure
            }
            return
        }
        // Determine server address and API key from command line or environment.
        let serverAddress = server ?? ProcessInfo.processInfo.environment["OPENAI_SERVER"] ?? "http://192.168.86.220:1234"
        let openAIKey     = apiKey ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let openAIModel   = model ?? ProcessInfo.processInfo.environment["OPENAI_MODEL"] ?? "deepseek-r1-distill-qwen-7b"
        // Handle image generation mode
        if let id = imageId {
            do {
                try await generateAndStoreImage(characterId: Int64(id), server: serverAddress, apiKey: openAIKey)
            } catch {
                throw ExitCode.failure
            }
            return
        }

        for _ in 0..<count {
            let baseCharacter = generateCharacter()
            do {
                _ = try await generateAndStore(character: baseCharacter,
                                               server: serverAddress,
                                               apiKey: openAIKey,
                                               model: openAIModel)
            } catch {
                // `generateAndStore` prints its own error details.
                throw ExitCode.failure
            }
        }
    }

}

/// Generates name, appearance, and background via the LLM, streams the output,
/// updates and saves the character, and returns the updated instance.
func generateAndStore(character: Character,
                      server: String,
                      apiKey: String,
                      model: String) async throws -> Character {
    let originalCharacter = character

    for attempt in 1...3 {
        var currentCharacter = originalCharacter
        var rawBuffer = ""

        for await token in generateStoryStream(for: originalCharacter,
                                               server: server,
                                               apiKey: apiKey,
                                               model: model) {
            print(token, terminator: "")
            rawBuffer += token
        }

        if let summary = parseSummary(from: rawBuffer) {
            currentCharacter.setName(summary.name)
            currentCharacter.setAppearance(summary.appearance)
            currentCharacter.setBackground(summary.background)

            do {
                var rec = currentCharacter.record
                let id = try rec.save()
                print("\n[SAVED] Character stored with id #\(id)")
            } catch {
                print("\n[DB Error] \(error)")
                throw error
            }

            return currentCharacter
        } else {
            print("\n[Warning] Failed to parse character summary (attempt \(attempt) of 3)")
            if attempt == 3 {
                throw NSError(domain: "DragonbaneCharacterCLI",
                              code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to parse character summary after 3 attempts"])
            }
        }
    }
    // Should not reach here
    throw NSError(domain: "DragonbaneCharacterCLI",
                  code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Unexpected error in generateAndStore"])
}
func generateStoryStream(for character: Character, server: String, apiKey: String, model: String) -> AsyncStream<String> {
    AsyncStream { continuation in
        guard let url = URL(string: "\(server)/v1/chat/completions") else {
            continuation.finish()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let prompt = """
        I'm going to give you a details for a character in the Table Top Rollplaying game Dragonbane, and you are going to create the missing details based on this information.
        Please create a JSON object with the following keys:
        - "name": create a name for this character based off of the kin/race and background you create,
        - "appearance": create a description of this characters appearance based on the information provided,
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

        let jsonBody: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": "You are a creative fantasy story generator."],
                ["role": "user", "content": prompt]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            continuation.finish()
            return
        }

        request.httpBody = httpBody

        let delegate = OpenAIStreamDelegate()
        delegate.onToken = { token in
            continuation.yield(token)
        }
        delegate.onCompletion = {
            continuation.finish()
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        continuation.onTermination = { _ in task.cancel() }
    }
}
/// Generates an image for the given character ID, stores it in the database, and writes to disk.
func generateAndStoreImage(characterId: Int64, server: String, apiKey: String) async throws {
    // Fetch the character record
    let record = try await DB.queue.read { db in
        try CharacterRecord.fetchOne(db, key: characterId)
    }
    guard let rec = record else {
        print("[Error] No character found with id \(characterId)")
        return
    }
    let character = rec.toCharacter()

    // Build the image generation prompt
    // Use character description for prompt since properties are internal
    let prompt = """
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
    // Prepare request
    let urlString = "\(server)/v1/images/generations"
    guard let url = URL(string: urlString) else {
        print("[Error] Invalid server URL: \(urlString)")
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    if !apiKey.isEmpty {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let jsonBody: [String: Any] = [
        "model": "gpt-image-1",
        "prompt": prompt,
        "n": 1,
        "quality": "high",
        "background": "transparent",
        "output_format": "webp"
    ]
    guard let bodyData = try? JSONSerialization.data(withJSONObject: jsonBody) else {
        print("[Error] Failed to encode request body")
        return
    }
    request.httpBody = bodyData

    // Execute request (with extended timeouts for long-running image generation)
    let sessionConfig = URLSessionConfiguration.default
    // Allow up to 2 minutes for the request and resource load
    sessionConfig.timeoutIntervalForRequest = 120
    sessionConfig.timeoutIntervalForResource = 120
    let session = URLSession(configuration: sessionConfig)
    let (data, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
        print("[Error] Image generation failed with status code \(http.statusCode)")
        if let bodyString = String(data: data, encoding: .utf8) {
            print("[OpenAI Error Body] \(bodyString)")
        }
        return
    }

    // Parse response
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let dataArray = json["data"] as? [[String: Any]],
          let first = dataArray.first,
          let b64 = first["b64_json"] as? String,
          let imageData = Data(base64Encoded: b64) else {
        print("[Error] Unexpected image generation response")
        return
    }

    // Use the returned WebP image data directly
    let imageBlob = imageData
    let newImageId = try await DB.queue.write { db in
        var imgRec = ImageRecord(id: nil, characterId: characterId, data: imageBlob)
        try imgRec.insert(db)
        return imgRec.id ?? db.lastInsertedRowID
    }
    print("[SAVED IMAGE] Stored image record id #\(newImageId) for character #\(characterId)")

    // Write image file to current directory
    let currentDir = FileManager.default.currentDirectoryPath
    let fileName = "character_\(characterId)_image_\(newImageId).webp"
    let fileURL = URL(fileURLWithPath: currentDir).appendingPathComponent(fileName)
    do {
        try imageBlob.write(to: fileURL)
        print("Image written to \(fileURL.path)")
    } catch {
        print("[Warning] Failed to write image to disk: \(error)")
    }
}
