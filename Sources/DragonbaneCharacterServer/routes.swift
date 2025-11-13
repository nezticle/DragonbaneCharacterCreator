import Vapor

func routes(_ app: Application) throws {
    let controller = CharacterController()
    let imageController = CharacterImageController()
    let characters = app.grouped("api", "characters")

    characters.get("random", use: controller.random)
    characters.get(":characterID", use: controller.fetch)
    characters.get(use: controller.index)

    let images = characters.grouped(":characterID", "images")
    images.get(use: imageController.list)
    images.get(":imageID", use: imageController.fetchBinary)

    if let token = app.storage[AdminTokenStorageKey.self] {
        let admin = characters.grouped(AdminTokenMiddleware(token: token))
        admin.post("generate", use: controller.generate)
        admin.post("bulk-generate", use: controller.bulkGenerate)
        admin.put(":characterID", use: controller.update)
        admin.delete(":characterID", use: controller.delete)

        let protectedImages = admin.grouped(":characterID", "images")
        protectedImages.post(use: imageController.generate)
    } else {
        app.logger.warning("Admin token missing; write routes are unavailable.")
    }
}
