import Vapor

func routes(_ app: Application) throws {
    let controller = CharacterController()
    let imageController = CharacterImageController()
    let characters = app.grouped("api", "characters")

    characters.get("random", use: controller.random)
    characters.post("generate", use: controller.generate)
    characters.get(":characterID", use: controller.fetch)
    characters.put(":characterID", use: controller.update)
    characters.get(use: controller.index)

    let images = characters.grouped(":characterID", "images")
    images.get(use: imageController.list)
    images.post(use: imageController.generate)
    images.get(":imageID", use: imageController.fetchBinary)
}
