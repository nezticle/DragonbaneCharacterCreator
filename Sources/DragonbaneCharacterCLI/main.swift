import DragonbaneCharacterCore
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
        onCompletion?()  // signal the semaphore
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
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

struct DragonbaneCharacterCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A command-line tool for generating Dragonbane characters.",
        discussion: "In interactive mode, you can enter commands to generate characters, view help, or exit.",
        version: "1.0.0"
    )

    @Flag(name: [.short, .long], help: "Run in interactive mode.")
    var interactive: Bool = false

    @Option(name: [.short, .long], help: "Server address for /v1/chat/completions calls. Can be overridden by the OPENAI_SERVER environment variable.")
    var server: String?

    @Option(name: [.short, .long], help: "API key for /v1/chat/completions calls. Can be overridden by the OPENAI_API_KEY environment variable.")
    var apiKey: String?

    @Option(name: [.short, .long], help: "Model for /v1/chat/completions calls. Can be overridden by the OPENAI_MODEL environment variable.")
    var model: String?

    mutating func run() throws {
        // Determine server address and API key from command line or environment.
        let serverAddress = server ?? ProcessInfo.processInfo.environment["OPENAI_SERVER"] ?? "http://192.168.86.220:1234"
        let openAIKey = apiKey ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let openAIModel = model ?? ProcessInfo.processInfo.environment["OPENAI_MODEL"] ?? "deepseek-r1-distill-qwen-7b"

        if interactive {
            runInteractiveMode(serverAddress: serverAddress, openAIKey: openAIKey, openAIModel: openAIModel)
        } else {
            let newCharacter = generateCharacter()
            print(newCharacter.description())
        }
    }

    // Interactive loop function
    func runInteractiveMode(serverAddress: String, openAIKey: String, openAIModel: String) {
        print("Entering interactive mode. Type 'help' for commands, and 'quit' or 'exit' to exit.")
        while true {
            print("Command:", terminator: " ")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
                continue
            }
            let lowerInput = input.lowercased()
            if lowerInput == "quit" || lowerInput == "exit" {
                print("Exiting interactive mode.")
                break
            } else if lowerInput == "help" {
                print("Available commands:")
                print("  generate  - Generate a new character")
                print("  story     - Generate story for current character")
                print("  help      - Show this help message")
                print("  quit/exit - Exit interactive mode")
            } else if lowerInput == "generate" {
                let newCharacter = generateCharacter()
                print(newCharacter.description())
            } else if lowerInput == "story" {
                print("Generating story for current character...")
                var currentCharacter = generateCharacter()
                // Block interactive prompt until story is done.
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    var rawBuffer: String = " "
                    for await token in generateStoryStream(for: currentCharacter, server: serverAddress, apiKey: openAIKey, model: openAIModel) {
                        // Print each token as it is received.
                        print(token, terminator: "")
                        rawBuffer += token
                    }

                    // if the response is valid JSON, update the character
                    if let summary = parseSummary(from: rawBuffer) {
                        // Update the character with the generated summary
                        currentCharacter.setName(String(summary.name))
                        currentCharacter.setAppearance(String(summary.appearance))
                        currentCharacter.setBackground(String(summary.background))
                        print(currentCharacter.description())
                        do {
                            var rec = currentCharacter.record
                            let id = try rec.save()
                            print("\n[SAVED] Character stored with id #\(id)")
                        } catch {
                            print("\n[DB Error] \(error)")
                        }
                    } else {
                        print("\n\nFailed to parse character summary.")
                    }

                    print("\nStory complete.")
                    semaphore.signal()
                }
                // Wait for the Task to complete before continuing interactive loop.
                // (In this simple implementation, the interactive prompt won't return until the Task finishes.)
                // You can extend this later to support cancellation.
                semaphore.wait()
            } else {
                print("Unknown command. Type 'help' to see available commands.")
            }
        }
    }
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

DragonbaneCharacterCLI.main()