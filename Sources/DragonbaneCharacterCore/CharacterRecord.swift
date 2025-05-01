import GRDB

public struct CharacterRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?

    var name: String
    var race: Race
    var profession: Profession
    var age: Age

    var strength: Int
    var constitution: Int
    var agility: Int
    var intelligence: Int
    var willpower: Int
    var charisma: Int

    // arrays → JSON in one TEXT column
    var heroicAbilities: [HeroicAbilities]
    var trainedSkills: [Skills]
    var magic: [String]
    var gear: [String]
    var appearanceSeeds: [String]

    // small scalars
    var weakness: String
    var memento: String
    var appearance: String
    var background: String


    // Tell GRDB the table name to use
    public static let databaseTableName = "character"
}

// Turn a Character into a record ready to save
public extension Character {
    var record: CharacterRecord {
        CharacterRecord(id: nil,
                        name: name,
                        race: race,
                        profession: profession,
                        age: age,
                        strength: strength,
                        constitution: constitution,
                        agility: agility,
                        intelligence: intelligence,
                        willpower: willpower,
                        charisma: charisma,
                        heroicAbilities: heroicAbilities,
                        trainedSkills: trainedSkills,
                        magic: magic,
                        gear: gear,
                        appearanceSeeds: appearanceSeeds,
                        weakness: weakness,
                        memento: memento,
                        appearance: appearance,
                        background: background)
    }
}
// Convert a CharacterRecord back to a Character.
public extension CharacterRecord {
    /// Convert the record to a Character instance.
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