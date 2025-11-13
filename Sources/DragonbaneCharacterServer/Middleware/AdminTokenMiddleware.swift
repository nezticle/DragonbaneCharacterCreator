import Vapor

struct AdminTokenMiddleware: AsyncMiddleware {
    let token: String

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard
            let authorization = request.headers.bearerAuthorization,
            authorization.token == token
        else {
            throw Abort(.unauthorized, reason: "Admin token missing or invalid.")
        }
        return try await next.respond(to: request)
    }
}

enum AdminTokenStorageKey: StorageKey {
    typealias Value = String
}
