import Vapor

struct ConfigController {
    func fetch(_ req: Request) throws -> UIConfigResponse {
        let hasServer = Environment.get("LLM_SERVER")?.trimmedOrNil != nil
        let hasModel = Environment.get("LLM_MODEL")?.trimmedOrNil != nil
        return UIConfigResponse(localLLMEnabled: hasServer && hasModel)
    }
}

struct UIConfigResponse: Content {
    let localLLMEnabled: Bool
}
