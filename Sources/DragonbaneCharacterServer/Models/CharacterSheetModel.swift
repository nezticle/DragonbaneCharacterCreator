import Vapor
import Fluent
import DragonbaneCharacterCore

final class CharacterSheetModel: Model, Content {
    static let schema = "character_sheets"

    @ID(key: .id)
    var id: UUID?

    @OptionalParent(key: "character_id")
    var character: CharacterModel?

    @Field(key: "token")
    var token: String

    @Field(key: "payload")
    var payload: CharacterSheetPayload

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(characterID: Int?, token: String, payload: CharacterSheetPayload) {
        self.$character.id = characterID
        self.token = token
        self.payload = payload
    }
}

extension CharacterSheetModel: @unchecked Sendable {}

struct CharacterSheetPayload: Content, Equatable {
    var characterName: String
    var playerName: String
    var kin: String
    var profession: String
    var age: String
    var weakness: String
    var appearance: String
    var attributes: AttributeBlock
    var conditions: ConditionFlags
    var movement: Int
    var encumbranceLimit: Int?
    var spells: [SpellEntry] = []
    var abilitiesAndSpells: [String]
    var skills: SkillSections
    var inventory: [InventoryItem]
    var gold: Int
    var silver: Int
    var copper: Int
    var memento: String
    var tinyItems: String
    var armour: ArmourBlock
    var helmet: HelmetBlock
    var weapons: [WeaponEntry]
    var rests: RestFlags
    var willpower: ResourceTrack
    var hitPoints: ResourceTrack
    var deathRolls: DeathRollTrack
    var notes: String
    var background: String

    mutating func normalize() {
        weapons = Array(weapons.prefix(3))
        while weapons.count < 3 {
            weapons.append(.empty())
        }
        deathRolls.successes = normalizedToggles(from: deathRolls.successes)
        deathRolls.failures = normalizedToggles(from: deathRolls.failures)
        inventory = inventory.map { item in
            InventoryItem(
                name: item.name.trimmedOrEmpty,
                details: item.details.trimmedOrEmpty,
                slots: max(item.slots, 0)
            )
        }
        encumbranceLimit = max(
            encumbranceLimit ?? CharacterSheetPayload.defaultEncumbranceLimit(for: attributes.strength),
            0
        )
        spells = spells
            .map { $0.normalized() }
            .filter { !$0.name.isEmpty }
        abilitiesAndSpells = abilitiesAndSpells.map { $0.trimmedOrEmpty }.filter { !$0.isEmpty }
        skills.primary = skills.primary.map { $0.normalized() }
        skills.weapon = skills.weapon.map { $0.normalized() }
        skills.secondary = skills.secondary.map { $0.normalized() }
    }

    private func normalizedToggles(from source: [Bool]) -> [Bool] {
        var toggles = Array(source.prefix(3))
        while toggles.count < 3 {
            toggles.append(false)
        }
        return toggles
    }
}

extension CharacterSheetPayload {
    struct AttributeBlock: Content, Equatable {
        var strength: Int
        var constitution: Int
        var agility: Int
        var intelligence: Int
        var willpower: Int
        var charisma: Int
    }

    struct ConditionFlags: Content, Equatable {
        var exhausted: Bool
        var sickly: Bool
        var dazed: Bool
        var angry: Bool
        var scared: Bool
        var disheartened: Bool

        static func empty() -> ConditionFlags {
            ConditionFlags(exhausted: false, sickly: false, dazed: false, angry: false, scared: false, disheartened: false)
        }
    }

    struct SkillSections: Content, Equatable {
        var primary: [SkillEntry]
        var weapon: [SkillEntry]
        var secondary: [SkillEntry]
    }

    struct SkillEntry: Content, Equatable {
        var name: String
        var level: Int
        var needsImprovement: Bool

        func normalized() -> SkillEntry {
            SkillEntry(name: name.trimmedOrEmpty, level: max(level, 0), needsImprovement: needsImprovement)
        }
    }

    struct InventoryItem: Content, Equatable {
        var name: String
        var details: String
        var slots: Int

        static func empty() -> InventoryItem {
            InventoryItem(name: "", details: "", slots: 1)
        }
    }

    struct SpellEntry: Content, Equatable {
        var name: String
        var inGrimoire: Bool
        var prepared: Bool

        func normalized() -> SpellEntry {
            SpellEntry(
                name: name.trimmedOrEmpty,
                inGrimoire: inGrimoire,
                prepared: prepared
            )
        }

        static func learned(_ name: String) -> SpellEntry {
            SpellEntry(name: name, inGrimoire: true, prepared: false).normalized()
        }
    }

    struct ArmourBlock: Content, Equatable {
        var armourType: String
        var rating: Int
        var banes: ArmourBanes

        static func empty() -> ArmourBlock {
            ArmourBlock(armourType: "", rating: 0, banes: .init(sneaking: false, evade: false, acrobatics: false))
        }
    }

    struct ArmourBanes: Content, Equatable {
        var sneaking: Bool
        var evade: Bool
        var acrobatics: Bool
    }

    struct HelmetBlock: Content, Equatable {
        var helmetType: String
        var rating: Int
        var banes: HelmetBanes

        static func empty() -> HelmetBlock {
            HelmetBlock(helmetType: "", rating: 0, banes: .init(awareness: false, rangedAttacks: false))
        }
    }

    struct HelmetBanes: Content, Equatable {
        var awareness: Bool
        var rangedAttacks: Bool
    }

    struct WeaponEntry: Content, Equatable {
        var name: String
        var grip: String
        var range: String
        var damage: String
        var durability: Int
        var features: String

        static func empty() -> WeaponEntry {
            WeaponEntry(name: "", grip: "", range: "", damage: "", durability: 0, features: "")
        }
    }

    struct RestFlags: Content, Equatable {
        var roundRest: Bool
        var stretchRest: Bool

        static func empty() -> RestFlags {
            RestFlags(roundRest: false, stretchRest: false)
        }
    }

    struct ResourceTrack: Content, Equatable {
        var max: Int
        var current: Int

        static func empty() -> ResourceTrack {
            ResourceTrack(max: 0, current: 0)
        }
    }

    struct DeathRollTrack: Content, Equatable {
        var successes: [Bool]
        var failures: [Bool]

        static func empty() -> DeathRollTrack {
            DeathRollTrack(successes: [false, false, false], failures: [false, false, false])
        }
    }
}

extension CharacterSheetPayload {
    static func from(character: CharacterResponse, playerName: String?) -> CharacterSheetPayload {
        let attributeBlock = AttributeBlock(
            strength: character.strength,
            constitution: character.constitution,
            agility: character.agility,
            intelligence: character.intelligence,
            willpower: character.willpower,
            charisma: character.charisma
        )

        let weaponSkills: Set<Skills> = [
            .axes, .bows, .brawling, .crossbows, .hammers, .knives, .slings, .spears, .staves, .swords
        ]

        let skillLevels = Dictionary(uniqueKeysWithValues: character.skills.map { ($0.skill, $0.value) })
        let primarySkills = Skills.allCases.filter { !weaponSkills.contains($0) }.map { skill in
            SkillEntry(name: skill.rawValue, level: skillLevels[skill] ?? 0, needsImprovement: false)
        }
        let weaponSkillEntries = Skills.allCases.filter { weaponSkills.contains($0) }.map { skill in
            SkillEntry(name: skill.rawValue, level: skillLevels[skill] ?? 0, needsImprovement: false)
        }
        var secondarySkills: [SkillEntry] = []
        if let mageSchool = CharacterSheetPayload.mageSecondarySkillName(for: character.profession) {
            let level = CharacterSheetPayload.trainedSkillLevel(forAttribute: character.intelligence)
            secondarySkills.append(SkillEntry(name: mageSchool, level: level, needsImprovement: false))
        }

        var armourBlock = ArmourBlock.empty()
        var helmetBlock = HelmetBlock.empty()
        var weaponEntries: [WeaponEntry] = [.empty(), .empty(), .empty()]
        var inventoryItems: [InventoryItem] = []
        var weaponIndex = 0
        var currency = CurrencyAccumulator()

        for gearItem in character.gear {
            if currency.absorb(gearItem) {
                continue
            }
            if let armourPreset = CharacterSheetPayload.lookupArmour(for: gearItem) {
                armourBlock = armourPreset
                continue
            }
            if let helmetPreset = CharacterSheetPayload.lookupHelmet(for: gearItem) {
                helmetBlock = helmetPreset
                continue
            }
            if weaponIndex < weaponEntries.count, let weaponPreset = CharacterSheetPayload.lookupWeapon(for: gearItem) {
                weaponEntries[weaponIndex] = weaponPreset
                weaponIndex += 1
                continue
            }
            inventoryItems.append(InventoryItem(name: gearItem, details: "", slots: 1))
        }

        var payload = CharacterSheetPayload(
            characterName: character.name,
            playerName: playerName ?? "",
            kin: character.race.rawValue,
            profession: character.profession.rawValue,
            age: character.age.rawValue,
            weakness: character.weakness,
            appearance: character.appearance,
            attributes: attributeBlock,
            conditions: .empty(),
            movement: CharacterSheetPayload.defaultMovement(for: character.race.rawValue, agility: character.agility),
            encumbranceLimit: CharacterSheetPayload.defaultEncumbranceLimit(for: character.strength),
            spells: character.magic.map { SpellEntry.learned($0) },
            abilitiesAndSpells: character.heroicAbilities.map { $0.rawValue }.deduplicatedPreservingOrder(),
            skills: SkillSections(
                primary: primarySkills,
                weapon: weaponSkillEntries,
                secondary: secondarySkills
            ),
            inventory: inventoryItems,
            gold: currency.gold,
            silver: currency.silver,
            copper: currency.copper,
            memento: character.memento,
            tinyItems: "",
            armour: armourBlock,
            helmet: helmetBlock,
            weapons: weaponEntries,
            rests: .empty(),
            willpower: ResourceTrack(max: character.willpower, current: character.willpower),
            hitPoints: ResourceTrack(max: character.constitution, current: character.constitution),
            deathRolls: .empty(),
            notes: "",
            background: character.background
        )

        payload.normalize()
        return payload
    }

    static func defaultMovement(for kin: String, agility: Int) -> Int {
        let base: Int
        switch kin {
        case "Human", "Elf":
            base = 10
        case "Halfling", "Dwarf", "Mallard":
            base = 8
        case "Wolfkin":
            base = 12
        default:
            base = 10
        }

        let modifier: Int
        switch agility {
        case Int.min...6:
            modifier = -4
        case 7...9:
            modifier = -2
        case 10...12:
            modifier = 0
        case 13...15:
            modifier = 2
        case 16...Int.max:
            modifier = 4
        default:
            modifier = 0
        }

        return max(base + modifier, 0)
    }

    static func defaultEncumbranceLimit(for strength: Int) -> Int {
        max((strength + 1) / 2, 0)
    }

    static func mageSecondarySkillName(for profession: Profession) -> String? {
        switch profession {
        case .animist:
            return "Animism"
        case .elementalist:
            return "Elementalism"
        case .mentalist:
            return "Mentalism"
        default:
            return nil
        }
    }

    static func trainedSkillLevel(forAttribute score: Int) -> Int {
        let base: Int
        switch score {
        case ..<6:
            base = 3
        case 6...8:
            base = 4
        case 9...12:
            base = 5
        case 13...15:
            base = 6
        default:
            base = 7
        }
        return base * 2
    }

    static func normalizeSpells(_ spells: [SpellEntry]) -> [SpellEntry] {
        spells.map { $0.normalized() }.filter { !$0.name.isEmpty }
    }

    static func lookupArmour(for raw: String) -> ArmourBlock? {
        EquipmentCatalog.matchArmour(raw)
    }

    static func lookupHelmet(for raw: String) -> HelmetBlock? {
        EquipmentCatalog.matchHelmet(raw)
    }

    static func lookupWeapon(for raw: String) -> WeaponEntry? {
        EquipmentCatalog.matchWeapon(raw)
    }
}

private extension String {
    var trimmedOrEmpty: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func deduplicatedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if seen.contains(trimmed) {
                return nil
            }
            seen.insert(trimmed)
            return trimmed
        }
    }
}

private struct CurrencyAccumulator {
    var gold = 0
    var silver = 0
    var copper = 0

    mutating func absorb(_ raw: String) -> Bool {
        let normalized = normalizeEquipmentString(raw)
        guard !normalized.isEmpty else { return false }
        let tokens = normalized.split(separator: " ")
        guard let currencyIndex = tokens.firstIndex(where: { ["gold", "silver", "copper"].contains($0) }) else {
            return false
        }
        guard currencyIndex > 0, let amount = Int(tokens[currencyIndex - 1]) else {
            return false
        }
        switch tokens[currencyIndex] {
        case "gold":
            gold += amount
        case "silver":
            silver += amount
        case "copper":
            copper += amount
        default:
            return false
        }
        return true
    }
}

private struct EquipmentCatalog {
    struct ArmourPreset {
        let keys: [String]
        let block: CharacterSheetPayload.ArmourBlock
    }

    struct HelmetPreset {
        let keys: [String]
        let block: CharacterSheetPayload.HelmetBlock
    }

    struct WeaponPreset {
        let keys: [String]
        let entry: CharacterSheetPayload.WeaponEntry
    }

    static let armourPresets: [ArmourPreset] = [
        ArmourPreset(
            keys: ["leather armour", "leather"],
            block: CharacterSheetPayload.ArmourBlock(
                armourType: "Leather Armour",
                rating: 1,
                banes: .init(sneaking: false, evade: false, acrobatics: false)
            )
        ),
        ArmourPreset(
            keys: ["studded leather armour", "studded leather"],
            block: CharacterSheetPayload.ArmourBlock(
                armourType: "Studded Leather Armour",
                rating: 2,
                banes: .init(sneaking: true, evade: false, acrobatics: false)
            )
        ),
        ArmourPreset(
            keys: ["chainmail armour", "chainmail"],
            block: CharacterSheetPayload.ArmourBlock(
                armourType: "Chainmail",
                rating: 4,
                banes: .init(sneaking: true, evade: true, acrobatics: false)
            )
        ),
        ArmourPreset(
            keys: ["plate armour", "plate"],
            block: CharacterSheetPayload.ArmourBlock(
                armourType: "Plate Armour",
                rating: 6,
                banes: .init(sneaking: true, evade: true, acrobatics: true)
            )
        )
    ]

    static let helmetPresets: [HelmetPreset] = [
        HelmetPreset(
            keys: ["open helmet"],
            block: CharacterSheetPayload.HelmetBlock(
                helmetType: "Open Helmet",
                rating: 1,
                banes: .init(awareness: true, rangedAttacks: false)
            )
        ),
        HelmetPreset(
            keys: ["great helm", "great helmet"],
            block: CharacterSheetPayload.HelmetBlock(
                helmetType: "Great Helm",
                rating: 2,
                banes: .init(awareness: true, rangedAttacks: true)
            )
        )
    ]

    static let weaponPresets: [WeaponPreset] = [
        WeaponPreset(keys: ["unarmed"], entry: weaponEntry(name: "Unarmed", grip: "-", range: "1", damage: "D6", durability: 0, features: "Bludgeoning")),
        WeaponPreset(keys: ["blunt object light", "light blunt"], entry: weaponEntry(name: "Light Blunt Object", grip: "1H", range: "STR", damage: "D8", durability: 3, features: "Bludgeoning, can be thrown")),
        WeaponPreset(keys: ["blunt object heavy", "heavy blunt"], entry: weaponEntry(name: "Heavy Blunt Object", grip: "2H", range: "2", damage: "2D8", durability: 3, features: "Bludgeoning")),
        WeaponPreset(keys: ["knife"], entry: weaponEntry(name: "Knife", grip: "1H", range: "STR", damage: "D8", durability: 6, features: "Subtle, piercing, can be thrown")),
        WeaponPreset(keys: ["dagger"], entry: weaponEntry(name: "Dagger", grip: "1H", range: "STR", damage: "D8", durability: 9, features: "Subtle, piercing, slashing, can be thrown")),
        WeaponPreset(keys: ["parrying dagger"], entry: weaponEntry(name: "Parrying Dagger", grip: "1H", range: "1", damage: "D6", durability: 12, features: "Subtle, piercing, slashing")),
        WeaponPreset(keys: ["short sword"], entry: weaponEntry(name: "Short Sword", grip: "1H", range: "2", damage: "D10", durability: 12, features: "Piercing, slashing")),
        WeaponPreset(keys: ["broadsword"], entry: weaponEntry(name: "Broadsword", grip: "1H", range: "2", damage: "2D6", durability: 15, features: "Piercing, slashing")),
        WeaponPreset(keys: ["longsword"], entry: weaponEntry(name: "Longsword", grip: "1H", range: "2", damage: "2D8", durability: 15, features: "Piercing, slashing")),
        WeaponPreset(keys: ["greatsword"], entry: weaponEntry(name: "Greatsword", grip: "2H", range: "2", damage: "2D10", durability: 15, features: "Piercing, slashing")),
        WeaponPreset(keys: ["scimitar"], entry: weaponEntry(name: "Scimitar", grip: "1H", range: "2", damage: "2D6", durability: 12, features: "Toppling, slashing")),
        WeaponPreset(keys: ["handaxe", "hand axe"], entry: weaponEntry(name: "Handaxe", grip: "1H", range: "STR", damage: "2D6", durability: 9, features: "Toppling, slashing, can be thrown")),
        WeaponPreset(keys: ["battleaxe", "battle axe"], entry: weaponEntry(name: "Battleaxe", grip: "1H", range: "2", damage: "2D8", durability: 9, features: "Toppling, slashing")),
        WeaponPreset(keys: ["two handed axe", "great axe"], entry: weaponEntry(name: "Two-Handed Axe", grip: "2H", range: "2", damage: "2D10", durability: 9, features: "Toppling, slashing")),
        WeaponPreset(keys: ["mace"], entry: weaponEntry(name: "Mace", grip: "1H", range: "2", damage: "2D4", durability: 12, features: "Bludgeoning")),
        WeaponPreset(keys: ["morningstar"], entry: weaponEntry(name: "Morningstar", grip: "1H", range: "2", damage: "2D8", durability: 12, features: "Bludgeoning")),
        WeaponPreset(keys: ["flail"], entry: weaponEntry(name: "Flail", grip: "1H", range: "2", damage: "2D8", durability: 0, features: "Bludgeoning, toppling, cannot be used for parrying")),
        WeaponPreset(keys: ["warhammer light"], entry: weaponEntry(name: "Light Warhammer", grip: "1H", range: "2", damage: "2D6", durability: 12, features: "Bludgeoning, toppling")),
        WeaponPreset(keys: ["warhammer heavy"], entry: weaponEntry(name: "Heavy Warhammer", grip: "2H", range: "2", damage: "2D10", durability: 12, features: "Bludgeoning, toppling")),
        WeaponPreset(keys: ["wooden club small", "small club"], entry: weaponEntry(name: "Small Wooden Club", grip: "1H", range: "2", damage: "D8", durability: 9, features: "Bludgeoning")),
        WeaponPreset(keys: ["wooden club large", "large club"], entry: weaponEntry(name: "Large Wooden Club", grip: "2H", range: "2", damage: "2D8", durability: 12, features: "Bludgeoning")),
        WeaponPreset(keys: ["staff"], entry: weaponEntry(name: "Staff", grip: "2H", range: "2", damage: "D8", durability: 9, features: "Bludgeoning, toppling")),
        WeaponPreset(keys: ["short spear"], entry: weaponEntry(name: "Short Spear", grip: "1H", range: "STR×2", damage: "D10", durability: 9, features: "Piercing, can be thrown")),
        WeaponPreset(keys: ["long spear"], entry: weaponEntry(name: "Long Spear", grip: "2H", range: "4", damage: "2D8", durability: 9, features: "Long, piercing")),
        WeaponPreset(keys: ["lance"], entry: weaponEntry(name: "Lance", grip: "1H", range: "4", damage: "2D10", durability: 12, features: "Long, piercing, requires combat trained mount")),
        WeaponPreset(keys: ["halberd"], entry: weaponEntry(name: "Halberd", grip: "2H", range: "4", damage: "2D8", durability: 12, features: "Long, toppling, piercing, slashing")),
        WeaponPreset(keys: ["trident"], entry: weaponEntry(name: "Trident", grip: "1H", range: "STR", damage: "2D6", durability: 9, features: "Toppling, piercing, can be thrown")),
        WeaponPreset(keys: ["shield small", "small shield"], entry: weaponEntry(name: "Small Shield", grip: "1H", range: "2", damage: "D8", durability: 15, features: "Bludgeoning")),
        WeaponPreset(keys: ["shield large", "large shield"], entry: weaponEntry(name: "Large Shield", grip: "1H", range: "2", damage: "D8", durability: 18, features: "Bludgeoning")),
        WeaponPreset(keys: ["sling"], entry: weaponEntry(name: "Sling", grip: "1H", range: "20", damage: "D8", durability: 0, features: "Bludgeoning, tiny item")),
        WeaponPreset(keys: ["short bow"], entry: weaponEntry(name: "Short Bow", grip: "2H", range: "30", damage: "D10", durability: 3, features: "Piercing, requires quiver")),
        WeaponPreset(keys: ["longbow", "long bow"], entry: weaponEntry(name: "Longbow", grip: "2H", range: "100", damage: "D12", durability: 6, features: "Piercing, requires quiver")),
        WeaponPreset(keys: ["crossbow light", "light crossbow"], entry: weaponEntry(name: "Light Crossbow", grip: "2H", range: "40", damage: "2D6", durability: 6, features: "Piercing, requires quiver, no damage bonus")),
        WeaponPreset(keys: ["crossbow heavy", "heavy crossbow"], entry: weaponEntry(name: "Heavy Crossbow", grip: "2H", range: "60", damage: "2D8", durability: 9, features: "Piercing, requires quiver, no damage bonus")),
        WeaponPreset(keys: ["crossbow hand", "hand crossbow"], entry: weaponEntry(name: "Hand Crossbow", grip: "1H", range: "30", damage: "2D6", durability: 6, features: "Piercing, requires quiver, no damage bonus"))
    ]

    static func matchArmour(_ raw: String) -> CharacterSheetPayload.ArmourBlock? {
        match(raw, presets: armourPresets.map { ($0.keys, $0.block) })
    }

    static func matchHelmet(_ raw: String) -> CharacterSheetPayload.HelmetBlock? {
        match(raw, presets: helmetPresets.map { ($0.keys, $0.block) })
    }

    static func matchWeapon(_ raw: String) -> CharacterSheetPayload.WeaponEntry? {
        match(raw, presets: weaponPresets.map { ($0.keys, $0.entry) })
    }

    private static func match<T>(_ raw: String, presets: [([String], T)]) -> T? {
        let normalized = normalizeEquipmentString(raw)
        guard !normalized.isEmpty else { return nil }
        if let exact = presets.first(where: { preset in
            preset.0.contains { normalizeEquipmentString($0) == normalized }
        }) {
            return exact.1
        }
        return presets.first(where: { preset in
            preset.0.contains { normalized.contains(normalizeEquipmentString($0)) }
        })?.1
    }

    private static func weaponEntry(name: String, grip: String, range: String, damage: String, durability: Int, features: String) -> CharacterSheetPayload.WeaponEntry {
        CharacterSheetPayload.WeaponEntry(
            name: name,
            grip: formattedGrip(grip),
            range: range,
            damage: damage,
            durability: max(durability, 0),
            features: features
        )
    }

    private static func formattedGrip(_ raw: String) -> String {
        let value = raw.lowercased()
        switch value {
        case "1h":
            return "R"
        case "2h":
            return "RL"
        case "shield", "lh":
            return "L"
        default:
            return raw == "-" ? "" : raw
        }
    }
}

private func normalizeEquipmentString(_ value: String) -> String {
    let lowered = value
        .lowercased()
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: ",", with: " ")
        .replacingOccurrences(of: "armor", with: "armour")
    let space = Swift.Character(" ")
    let cleaned = lowered.map { character -> Swift.Character in
        (character.isLetter || character.isNumber || character == space) ? character : space
    }
    return String(cleaned)
        .split(separator: " ")
        .joined(separator: " ")
}
