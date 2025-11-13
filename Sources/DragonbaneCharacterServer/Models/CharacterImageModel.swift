import Vapor
import Fluent
import Foundation

final class CharacterImageModel: Model, Content {
    static let schema = "character_images"

    @ID(custom: "id")
    var id: Int?

    @Parent(key: "character_id")
    var character: CharacterModel

    @Field(key: "data")
    var data: Data

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(characterID: Int, data: Data) {
        self.$character.id = characterID
        self.data = data
    }
}

extension CharacterImageModel: @unchecked Sendable {}
