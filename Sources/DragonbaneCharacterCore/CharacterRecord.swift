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
// MARK: - Sendable conformance
extension CharacterRecord: @unchecked Sendable {}

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
// MARK: - Statistics

/// Aggregated statistics about saved characters.
public struct CharacterStats {
    /// Total number of saved characters.
    public let total: Int
    /// Count of saved characters by race.
    public let byRace: [String: Int]
    /// Count of saved characters by profession.
    public let byProfession: [String: Int]
}

public extension CharacterRecord {
    /// Total number of saved characters.
    static func count() throws -> Int {
        try DB.queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM character") ?? 0
        }
    }

    /// Counts saved characters grouped by race.
    static func countByRace() throws -> [String: Int] {
        try DB.queue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT race, COUNT(*) AS count FROM character GROUP BY race")
            var result: [String: Int] = [:]
            for row in rows {
                if let race = row["race"] as? String {
                    let count = Int((row["count"] as? Int64) ?? 0)
                    result[race] = count
                }
            }
            return result
        }
    }

    /// Counts saved characters grouped by profession.
    static func countByProfession() throws -> [String: Int] {
        try DB.queue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT profession, COUNT(*) AS count FROM character GROUP BY profession")
            var result: [String: Int] = [:]
            for row in rows {
                if let prof = row["profession"] as? String {
                    let count = Int((row["count"] as? Int64) ?? 0)
                    result[prof] = count
                }
            }
            return result
        }
    }

    /// Fetches aggregated character statistics.
    static func stats() throws -> CharacterStats {
        let total = try count()
        let byRace = try countByRace()
        let byProfession = try countByProfession()
        return CharacterStats(total: total, byRace: byRace, byProfession: byProfession)
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