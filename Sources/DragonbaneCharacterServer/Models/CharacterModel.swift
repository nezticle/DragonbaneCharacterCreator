import Vapor
import Fluent
import DragonbaneCharacterCore

final class CharacterModel: Model, Content {
    static let schema = "characters"

    @ID(custom: "id")
    var id: Int?

    @Field(key: "name")
    var name: String

    @Field(key: "race")
    var race: String

    @Field(key: "profession")
    var profession: String

    @Field(key: "age")
    var age: String

    @Field(key: "strength")
    var strength: Int

    @Field(key: "constitution")
    var constitution: Int

    @Field(key: "agility")
    var agility: Int

    @Field(key: "intelligence")
    var intelligence: Int

    @Field(key: "willpower")
    var willpower: Int

    @Field(key: "charisma")
    var charisma: Int

    @Field(key: "heroic_abilities")
    var heroicAbilities: [String]

    @Field(key: "trained_skills")
    var trainedSkills: [String]

    @Field(key: "magic")
    var magic: [String]

    @Field(key: "gear")
    var gear: [String]

    @Field(key: "appearance_seeds")
    var appearanceSeeds: [String]

    @Field(key: "weakness")
    var weakness: String

    @Field(key: "memento")
    var memento: String

    @Field(key: "appearance")
    var appearance: String

    @Field(key: "background")
    var background: String

    init() { }

    convenience init(character: Character) {
        self.init()
        apply(character: character)
    }

    func apply(character: Character) {
        name = character.name
        race = character.race.rawValue
        profession = character.profession.rawValue
        age = character.age.rawValue
        strength = character.strength
        constitution = character.constitution
        agility = character.agility
        intelligence = character.intelligence
        willpower = character.willpower
        charisma = character.charisma
        heroicAbilities = character.heroicAbilities.map { $0.rawValue }
        trainedSkills = character.trainedSkills.map { $0.rawValue }
        magic = character.magic
        gear = character.gear
        appearanceSeeds = character.appearanceSeeds
        weakness = character.weakness
        memento = character.memento
        appearance = character.appearance
        background = character.background
    }

    func toResponse() throws -> CharacterResponse {
        guard let raceEnum = Race(rawValue: race),
              let professionEnum = Profession(rawValue: profession),
              let ageEnum = Age(rawValue: age) else {
            throw Abort(.internalServerError, reason: "Stored character has invalid categorical data")
        }

        let heroic = try heroicAbilities.map { value -> HeroicAbilities in
            guard let ability = HeroicAbilities(rawValue: value) else {
                throw Abort(.internalServerError, reason: "Unknown heroic ability \(value)")
            }
            return ability
        }

        let skills = try trainedSkills.map { value -> Skills in
            guard let skill = Skills(rawValue: value) else {
                throw Abort(.internalServerError, reason: "Unknown skill \(value)")
            }
            return skill
        }
        let skillLevels = calculateSkillLevels(
            strength: strength,
            constitution: constitution,
            agility: agility,
            intelligence: intelligence,
            willpower: willpower,
            charisma: charisma,
            trainedSkills: skills
        )

        return CharacterResponse(
            id: id,
            name: name,
            race: raceEnum,
            profession: professionEnum,
            age: ageEnum,
            strength: strength,
            constitution: constitution,
            agility: agility,
            intelligence: intelligence,
            willpower: willpower,
            charisma: charisma,
            heroicAbilities: heroic,
            trainedSkills: skills,
            skills: skillLevels,
            magic: magic,
            gear: gear,
            appearanceSeeds: appearanceSeeds,
            weakness: weakness,
            memento: memento,
            appearance: appearance,
            background: background
        )
    }

    func toCharacter() throws -> Character {
        try toResponse().toCharacter()
    }
}

extension CharacterModel: @unchecked Sendable {}

struct CharacterResponse: Content {
    let id: Int?
    let name: String
    let race: Race
    let profession: Profession
    let age: Age
    let strength: Int
    let constitution: Int
    let agility: Int
    let intelligence: Int
    let willpower: Int
    let charisma: Int
    let heroicAbilities: [HeroicAbilities]
    let trainedSkills: [Skills]
    let skills: [SkillLevel]
    let magic: [String]
    let gear: [String]
    let appearanceSeeds: [String]
    let weakness: String
    let memento: String
    let appearance: String
    let background: String

    func toCharacter() -> Character {
        Character(
            name: name,
            race: race,
            profession: profession,
            age: age,
            heroicAbilities: heroicAbilities,
            trainedSkills: trainedSkills,
            magic: magic,
            weakness: weakness,
            strength: strength,
            constitution: constitution,
            agility: agility,
            intelligence: intelligence,
            willpower: willpower,
            charisma: charisma,
            gear: gear,
            memento: memento,
            appearanceSeeds: appearanceSeeds,
            background: background,
            appearance: appearance
        )
    }
}

struct CharacterUpdateRequest: Content {
    let name: String?
    let race: Race?
    let profession: Profession?
    let age: Age?
    let strength: Int?
    let constitution: Int?
    let agility: Int?
    let intelligence: Int?
    let willpower: Int?
    let charisma: Int?
    let heroicAbilities: [HeroicAbilities]?
    let trainedSkills: [Skills]?
    let magic: [String]?
    let gear: [String]?
    let appearanceSeeds: [String]?
    let weakness: String?
    let memento: String?
    let appearance: String?
    let background: String?
}

extension CharacterModel {
    func apply(update: CharacterUpdateRequest) {
        if let value = update.name { name = value }
        if let value = update.race { race = value.rawValue }
        if let value = update.profession { profession = value.rawValue }
        if let value = update.age { age = value.rawValue }
        if let value = update.strength { strength = value }
        if let value = update.constitution { constitution = value }
        if let value = update.agility { agility = value }
        if let value = update.intelligence { intelligence = value }
        if let value = update.willpower { willpower = value }
        if let value = update.charisma { charisma = value }
        if let value = update.heroicAbilities { heroicAbilities = value.map { $0.rawValue } }
        if let value = update.trainedSkills { trainedSkills = value.map { $0.rawValue } }
        if let value = update.magic { magic = value }
        if let value = update.gear { gear = value }
        if let value = update.appearanceSeeds { appearanceSeeds = value }
        if let value = update.weakness { weakness = value }
        if let value = update.memento { memento = value }
        if let value = update.appearance { appearance = value }
        if let value = update.background { background = value }
    }
}

extension CharacterResponse {
    init(character: Character) {
        self.init(
            id: nil,
            name: character.name,
            race: character.race,
            profession: character.profession,
            age: character.age,
            strength: character.strength,
            constitution: character.constitution,
            agility: character.agility,
            intelligence: character.intelligence,
            willpower: character.willpower,
            charisma: character.charisma,
            heroicAbilities: character.heroicAbilities,
            trainedSkills: character.trainedSkills,
            skills: character.skillLevels,
            magic: character.magic,
            gear: character.gear,
            appearanceSeeds: character.appearanceSeeds,
            weakness: character.weakness,
            memento: character.memento,
            appearance: character.appearance,
            background: character.background
        )
    }
}
