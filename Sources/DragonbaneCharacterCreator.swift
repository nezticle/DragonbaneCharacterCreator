import ArgumentParser
import Foundation

// Define available races for your characters.
enum Race: String, CaseIterable {
    case human = "Human"                    // Adaptive
    case halfling = "Halfling"              // Hard to Catch
    case dwarf = "Dwarf"                    // Unforving
    case elf = "Elf"                        // Inner Peace
    case mallard = "Mallard"                // Ill-Tempered, Webbed Feet
    case wolfkin = "Wolfkin"                // Hunting Instinct
    // Nightkin
    case goblin = "Goblin"                  // Resilient
    case hobgoblin = "Hobgoblin"            // Fearless
    case ogre = "Ogre"                      // Body Slam
    case orc = "Orc"                        // Tough
    // Rare Kin
    case catpeople = "Cat People"           // Nine Lives
    case frogpeople = "Frog People"         // Leaping
    case karkion = "Karkion"                // Wings
    case lizardpeople = "Lizard People"     // Camouflage
    case satyr = "Satyr"                    // Raise Spirits
}

// Create an enum for kin categories to help with weighted selection.
enum KinCategory {
    case common, nightkin, rare
}

// Extend Race with computed properties
extension Race {
    /// Returns the starting ability as specified in the comment for the kin.
    var startingAbilities: [HeroicAbilities] {
        switch self {
        case .human:      return [.adaptive]
        case .halfling:   return [.hardtocatch]
        case .dwarf:      return [.unforgiving]
        case .elf:        return [.innerpeace]
        case .mallard:    return [.illtempered, .webbedfeet]
        case .wolfkin:    return [.huntinginstinct]
        case .goblin:     return [.resilient]
        case .hobgoblin:  return [.fearless]
        case .ogre:       return [.bodyslam]
        case .orc:        return [.tough]
        case .catpeople:  return [.ninelives]
        case .frogpeople: return [.leaping]
        case .karkion:    return [.wings]
        case .lizardpeople: return [.camouflage]
        case .satyr:      return [.raisespirits]
        }
    }

    /// Determines which kin category a given Race belongs to.
    var category: KinCategory {
        switch self {
        case .human, .halfling, .dwarf, .elf, .mallard, .wolfkin:
            return .common
        case .goblin, .hobgoblin, .ogre, .orc:
            return .nightkin
        case .catpeople, .frogpeople, .karkion, .lizardpeople, .satyr:
            return .rare
        }
    }
}

/// Selects a Race (kin) based on the weighted distribution.
///
/// - 93% chance to pick from common kin using weights 4, 3, 2, 1, 1, 1.
/// - 2% chance to pick any nightkin.
/// - 1% chance to pick any rare kin
func selectKin() -> Race {
    let randomCategory = Double.random(in: 0.0...1.0)

    if randomCategory < 0.97 {
        // Select from common kin with weighted distribution (97% chance).
        let commonOptions: [(race: Race, weight: Double)] = [
            (.human, 4), (.halfling, 3), (.dwarf, 2),
            (.elf, 1), (.mallard, 1), (.wolfkin, 1)
        ]
        let totalWeight = commonOptions.reduce(0) { $0 + $1.weight }
        let randomWeight = Double.random(in: 0...totalWeight)
        var cumulativeWeight = 0.0
        for option in commonOptions {
            cumulativeWeight += option.weight
            if randomWeight <= cumulativeWeight {
                return option.race
            }
        }
        // Fallback, though it should never be reached.
        return .human
    } else if randomCategory < 0.97 + 0.02 {
        // 2% chance: Select uniformly from nightkin.
        let nightkinOptions: [Race] = [.goblin, .hobgoblin, .ogre, .orc]
        return nightkinOptions.randomElement() ?? .goblin
    } else {
        // The remaining 1%: Rare kin.
        let rareOptions: [Race] = [.catpeople, .frogpeople, .karkion, .lizardpeople, .satyr]
        return rareOptions.randomElement() ?? .catpeople
    }
}

// Define available character classes for your characters.
enum Profession: String, CaseIterable {
    case artisan = "Artisan"
    case bard = "Bard"
    case fighter = "Fighter"
    case hunter = "Hunter"
    case knight = "Knight"
    case animist = "Mage (Animist)"
    case elementalist = "Mage (Elementalist)"
    case mentalist = "Mage (Mentalist)"
    case mariner = "Mariner"
    case merchant = "Merchant"
    case scholar = "Scholar"
    case thief = "Thief"
}

extension Profession {
    var keyAttribute: Attributes {
        switch self {
        case .artisan: return .str
        case .bard: return .cha
        case .fighter: return .str
        case .hunter: return .agl
        case .knight: return .str
        case .animist: return .wil
        case .elementalist: return .wil
        case .mentalist: return .int
        case .mariner: return .agl
        case .merchant: return .cha
        case .scholar: return .int
        case .thief: return .agl
        }
    }
    var skills: [Skills] {
        switch self {
        case .artisan: return [.axes, .brawling, .crafting, .hammers, .knives, .slightofhand, .spothidden, .swords]
        case .bard: return [.acrobatics, .bluffing, .evade, .knives, .language, .mythsandlegends, .performance, .persuasion]
        case .fighter: return [.axes, .bows, .brawling, .crossbows, .evade, .hammers, .spears, .swords]
        case .hunter: return [.acrobatics, .awareness, .bows, .bushcraft, .huntingandfishing, .knives, .slings, .sneaking]
        case .knight: return [.beastlore, .hammers, .mythsandlegends, .performance, .persuasion, .riding, .spears, .swords]
        case .animist: return [.beastlore, .bushcraft, .evade, .healing, .huntingandfishing, .sneaking, .staves]
        case .elementalist: return [.awareness, .evade, .healing, .language, .mythsandlegends, .spothidden, .staves]
        case .mentalist: return [.acrobatics, .awareness, .brawling, .evade, .healing, .language, .mythsandlegends]
        case .mariner: return [.acrobatics, .awareness, .huntingandfishing, .knives, .language, .seamenship, .swimming, .swords]
        case .merchant: return [.awareness, .bartering, .bluffing, .evade, .knives, .persuasion, .slightofhand, .spothidden]
        case .scholar: return [.awareness, .beastlore, .bushcraft, .evade, .healing, .language, .mythsandlegends, .spothidden]
        case .thief: return [.acrobatics, .awareness, .bluffing, .evade, .knives, .slightofhand, .sneaking, .spothidden]
        }
    }

    var heroicAbilities: [HeroicAbilities] {
        switch self {
        case .artisan: return [.masterblacksmith, .mastercarpenter, .mastertanner]
        case .bard: return [.musician]
        case .fighter: return [.veteran]
        case .hunter: return [.companion]
        case .knight: return [.guardian]
        case .animist: return []
        case .elementalist: return []
        case .mentalist: return []
        case .mariner: return [.sealegs]
        case .merchant: return [.treasurehunter]
        case .scholar: return [.intuition]
        case .thief: return [.backstabbing]
        }
    }
}

enum Skills: String, CaseIterable {
    case acrobatics = "Acrobatics"
    case awareness = "Awareness"
    case bartering = "Bartering"
    case beastlore = "Beast Lore"
    case bluffing = "Bluffing"
    case bushcraft = "Bushcraft"
    case crafting = "Crafting"
    case evade = "Evade"
    case healing = "Healing"
    case huntingandfishing = "Hunting & Fishing"
    case language = "Language"
    case mythsandlegends = "Myths & Legends"
    case performance = "Performance"
    case persuasion = "Persuasion"
    case riding = "Riding"
    case seamenship = "Seamanship"
    case slightofhand = "Slight of Hand"
    case sneaking = "Sneaking"
    case spothidden = "Spot Hidden"
    case swimming = "Swimming"
    case axes = "Axes"
    case bows = "Bows"
    case brawling = "Brawling"
    case crossbows = "Crossbows"
    case hammers = "Hammers"
    case knives = "Knives"
    case slings = "Slings"
    case spears = "Spears"
    case staves = "Staves"
    case swords = "Swords"
}

enum HeroicAbilities: String, CaseIterable {
    case assassin = "Assassin"
    case backstabbing = "Backstabbing"
    case battlecry = "Battle Cry"
    case berserk = "Berserk"
    case catlike = "Catlike"
    case companion = "Companion"
    case contortionist = "Contortionist"
    case defensive = "Defensive"
    case deflectarrow = "Deflect Arrow"
    case disguise = "Disguise"
    case doubleslash = "Double Slash"
    case dragonslayer = "Dragonslayer"
    case dualwield = "Dual Wield"
    case eagleeye = "Eagle Eye"
    case fastfootwork = "Fast Footwork"
    case fasthealer = "Fast Healer"
    case fearless = "Fearless"
    case focused = "Focused"
    case guardian = "Guardian"
    case insight = "Insight"
    case intuition = "Intuition"
    case ironfist = "Iron Fist"
    case irongrip = "Iron Grip"
    case lightningfast = "Lightning Fast"
    case lonewolf = "Lone Wolf"
    case magictalent = "Magic Talent"
    case massiveblow = "Massive Blow"
    case masterblacksmith = "Master Blacksmith"
    case mastercarpenter = "Master Carpenter"
    case masterchef = "Master Chef"
    case masterspellcaster = "Master Spellcaster"
    case mastertanner = "Master Tanner"
    case monsterhunter = "Monster Hunter"
    case musician = "Musician"
    case pathfinder = "Pathfinder"
    case quatermaster = "Quartermaster"
    case robust = "Robust"
    case sealegs = "Sea Legs"
    case sheildblock = "Shield Block"
    case throwingarm = "Throwing Arm"
    case treasurehunter = "Treasure Hunter"
    case twinshot = "Twin Shot"
    case veteran = "Veteran"
    case weasel = "Weasel"
    // Kin Specific Abilities
    case adaptive = "Adaptive" // human
    case hardtocatch = "Hard to Catch" // halfling
    case unforgiving = "Unforgiving" // dwarf
    case innerpeace = "Inner Peace" // elf
    case illtempered = "Ill-Tempered" // mallard
    case webbedfeet = "Webbed Feet" // mallard
    case huntinginstinct = "Hunting Instinct" // wolfkin
    case resilient = "Resilient" // goblin
    case bodyslam = "Body Slam" // ogre
    case tough = "Tough" // orc
    case ninelives = "Nine Lives" // catpeople
    case leaping = "Leaping" // frogpeople
    case wings = "Wings" // karkion
    case camouflage = "Camouflage" // lizardpeople
    case raisespirits = "Raise Spirits" // satyr
}

enum Attributes: String, CaseIterable {
    case str = "Strength"
    case con = "Constitution"
    case agl = "Agility"
    case int = "Intelligence"
    case wil = "Willpower"
    case cha = "Charisma"
}

enum Age : String, CaseIterable {
    // Normally a D6 roll
    case young = "Young"    // 1-3, Trained skills +2, AGL and CON + 1
    case adult = "Adult"    // 4-5, Trained skills +4, AGL and CON + 0
    case old = "Old"        // 6, Trained skills +6, STR, AGL and CON -2, INT and WIL +1
}

// Roll a D6 to determine Age based on the rules:
func rollAge() -> Age {
    let roll = Int.random(in: 1...6)
    if roll <= 3 {
        return .young  // Roll 1-3
    } else if roll <= 5 {
        return .adult  // Roll 4-5
    } else {
        return .old    // Roll 6
    }
}

func rollGear(profession : Profession) -> [String] {
    // This function should return a list of gear based on the profession.
    // For now, we will return an empty array.
    let roll = Int.random(in: 1...6)
    var gear: [String] = []
    var rations: Int = 0
    var silver: Int = 0

    switch profession {
        case .artisan:
            rations = Int.random(in: 1...8)
            silver = Int.random(in: 1...8)
            if roll <= 2 {
                gear.append("Warhammer, Light")
                gear.append("Leather Armour")
                gear.append("Blacksmithing Tools")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Handaxe, Leather, Carpentry Tools, Torch, Rope, Hemp (10 meters), Flint & Tinder, D8xField Ration, D8 silver
                gear.append("Handaxe")
                gear.append("Leather Armour")
                gear.append("Carpentry Tools")
                gear.append("Torch")
                gear.append("Rope (10 meters)")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                //	Knife, Leather, Tanning Tools, Lantern, Lamp Oil, Flint & Tinder, D8xField Ration, D8 silver
                gear.append("Knife")
                gear.append("Leather Armour")
                gear.append("Tanning Tools")
                gear.append("Lantern")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .bard:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...8)
            if roll <= 2 {
                //Lyre, Knife, Oil Lamp, Lamp Oil, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Lyre")
                gear.append("Knife")
                gear.append("Oil Lamp")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                //Flute, Dagger, Rope, Hemp (10 meters), Torch, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Flute")
                gear.append("Dagger")
                gear.append("Rope (10 meters)")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                //Horn, Knife, Torch, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Horn")
                gear.append("Knife")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .fighter:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...6)
            if roll <= 2 {
                //Broadsword or Battleaxe or Morningstar, Shield, Small, Chainmail, Torch, Flint & Tinder, D6xField Ration, D6 silver
                let weapon = ["Broadsword", "Battleaxe", "Morningstar"].randomElement()!
                gear.append(weapon)
                gear.append("Shield")
                gear.append("Chainmail Armour")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                //Short Sword or Handaxe or Short Spear, Crossbow, Light, Quiver of Arrows, Iron Head, Leather, Torch, Flint & Tinder, D6xField Ration, D6 silver
                let weapon = ["Short Sword", "Handaxe", "Short Spear"].randomElement()!
                gear.append(weapon)
                gear.append("Crossbow, Light")
                gear.append("Quiver of Arrows, Iron Head")
                gear.append("Leather Armour")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                //Long Spear, Studded Leather, Open Helmet, Torch, Flint & Tinder, D6xField Ration, D6 silver
                gear.append("Long Spear")
                gear.append("Studded Leather Armour")
                gear.append("Open Helmet")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .hunter:
            rations = Int.random(in: 1...8)
            silver = Int.random(in: 1...6)
            if roll <= 2 {
                // Dagger, Short Bow, Quiver of Arrows, Iron Head, Leather, Sleeping Fur, Torch, Flint & Tinder, Rope, Hemp (10 meters), Snare, D8xField Ration, D6 silver
                gear.append("Dagger")
                gear.append("Short Bow")
                gear.append("Quiver of Arrows, Iron Head")
                gear.append("Leather Armour")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("Rope (10 meters)")
                gear.append("Snare")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Knife, Longbow, Quiver of Arrows, Iron Head, Leather, Sleeping Fur, Torch, Flint & Tinder, Rope, Hemp (10 meters), Fishing Rod, D8xField Ration, D6 silver
                gear.append("Knife")
                gear.append("Longbow")
                gear.append("Quiver of Arrows, Iron Head")
                gear.append("Leather Armour")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("Rope (10 meters)")
                gear.append("Fishing Rod")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Dagger, Sling, Leather, Sleeping Fur, Torch, Flint & Tinder, Rope, Hemp (10 meters), Snare, D8xField Ration, D6 silver
                gear.append("Dagger")
                gear.append("Sling")
                gear.append("Leather Armour")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("Rope (10 meters)")
                gear.append("Snare")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .knight:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...12)
            if roll <= 2 {
                // Broadsword or Morningstar, Shield, Small, Plate Armor, Great Helm, Torch, Flint & Tinder, D6xField Ration, D12 silver
                let weapon = ["Broadsword", "Morningstar"].randomElement()!
                gear.append(weapon)
                gear.append("Shield, Small")
                gear.append("Plate Armor")
                gear.append("Great Helm")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Flail or Warhammer, Light, Shield, Small, Chainmail, Open Helmet, Torch, Flint & Tinder, D6xField Ration, D12 silver
                let weapon = ["Flail", "Warhammer"].randomElement()!
                gear.append(weapon)
                gear.append("Shield, Small")
                gear.append("Chainmail Armour")
                gear.append("Open Helmet")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Short Sword, Lance, Shield, Small, Chainmail, Open Helmet, Combat Trained Horse, D6xField Ration, D12 silver
                gear.append("Short Sword")
                gear.append("Lance")
                gear.append("Shield, Small")
                gear.append("Chainmail Armour")
                gear.append("Open Helmet")
                gear.append("Combat Trained Horse")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .animist, .elementalist, .mentalist:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...8)
            if roll <= 2 {
                // Staff, Orbuculum, Grimoire, Torch, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Staff")
                gear.append("Orbuculum")
                gear.append("Grimoire")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Knife, Wand, Grimoire, Torch, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Knife")
                gear.append("Wand")
                gear.append("Grimoire")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Amulet, Sleeping Fur, Grimoire, Torch, Flint & Tinder, D6xField Ration, D8 silver
                gear.append("Amulet")
                gear.append("Sleeping Fur")
                gear.append("Grimoire")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .mariner:
            rations = Int.random(in: 1...8)
            silver = Int.random(in: 1...10)
            if roll <= 2 {
                // Dagger, Short Bow, Quiver of Arrows, Iron Head, Rope, Hemp (10 meters), Grappling Hook, Sleeping Fur, Torch, Flint & Tinder, D8xField Ration, D10 silver
                gear.append("Dagger")
                gear.append("Short Bow")
                gear.append("Quiver of Arrows, Iron Head")
                gear.append("Rope (10 meters)")
                gear.append("Grappling Hook")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Scimitar, Leather, Rope, Hemp (10 meters), Grappling Hook, Torch, Flint & Tinder, D8xField Ration, D10 silver
                gear.append("Scimitar")
                gear.append("Leather Armour")
                gear.append("Rope (10 meters)")
                gear.append("Grappling Hook")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Trident, Spyglass, Rope, Hemp (10 meters), Grappling Hook, Torch, Flint & Tinder, D8xField Ration, D10 silver
                gear.append("Trident")
                gear.append("Spyglass")
                gear.append("Rope (10 meters)")
                gear.append("Grappling Hook")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .merchant:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...12)
            if roll <= 2 {
                // Dagger, Sleeping Fur, Torch, Flint & Tinder, Rope, Hemp (10 meters), Donkey, D6xField Ration, D12 silver
                gear.append("Dagger")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("Rope (10 meters)")
                gear.append("Donkey")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Knife, Sleeping Fur, Lantern, Lamp Oil, Flint & Tinder, Field Kitchen, Donkey, Cart, D6xField Ration, D12 silver
                gear.append("Knife")
                gear.append("Sleeping Fur")
                gear.append("Lantern")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("Field Kitchen")
                gear.append("Donkey")
                gear.append("Cart")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Dagger, Sleeping Fur, Tent, Large, Oil Lamp, Lamp Oil, Flint & Tinder, Backpack, D6xField Ration, D12 silver
                gear.append("Dagger")
                gear.append("Sleeping Fur")
                gear.append("Tent, Large")
                gear.append("Oil Lamp")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("Backpack")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .scholar:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...10)
            if roll <= 2 {
                // Staff, Notebook, Quill & Ink, Sleeping Fur, Torch, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("Staff")
                gear.append("Notebook")
                gear.append("Quill & Ink")
                gear.append("Sleeping Fur")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Knife, Book (any subject), Sleeping Fur, Oil Lamp, Lamp Oil, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("Knife")
                gear.append("Book (any subject)")
                gear.append("Sleeping Fur")
                gear.append("Oil Lamp")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // Short Sword, Bandages (10), Poison, Sleeping (1 dose), Sleeping Fur, Lantern, Lamp Oil, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("Short Sword")
                gear.append("Bandages (10)")
                gear.append("Poison, Sleeping (1 dose)")
                gear.append("Sleeping Fur")
                gear.append("Lantern")
                gear.append("Lamp Oil")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
        case .thief:
            rations = Int.random(in: 1...6)
            silver = Int.random(in: 1...10)
            if roll <= 2 {
                // Dagger, Sling, Rope, Hemp (10 meters), Grappling Hook, Torch, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("Dagger")
                gear.append("Sling")
                gear.append("Rope (10 meters)")
                gear.append("Grappling Hook")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else if roll <= 4 {
                // Knife, Lockpicks, Simple, Torch, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("Knife")
                gear.append("Lockpicks, Simple")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            } else {
                // 2xDagger, Marbles, Rope, Hemp (10 meters), Torch, Flint & Tinder, D6xField Ration, D10 silver
                gear.append("2x Dagger")
                gear.append("Marbles")
                gear.append("Rope (10 meters)")
                gear.append("Torch")
                gear.append("Flint & Tinder")
                gear.append("\(rations) Field Rations")
                gear.append("\(silver) Silver")
            }
    }
    return gear
}

// Define the structure for a Dragonbane character.
// You can include additional properties or change the set of abilities based on your game rules.
struct Character {
    var name: String
    var race: Race
    var profession: Profession
    var age: Age
    var heroicAbilities: [HeroicAbilities]
    var trainedSkills: [Skills]
    var magic: [String]
    var weakness: String
    var strength: Int
    var constitution: Int
    var agility: Int
    var intelligence: Int
    var willpower: Int
    var charisma: Int
    var gear: [String]
    var memento: String
    var appearanceSeeds: [String]

    func description() -> String {
        return """
        ---- Dragonbane Character ----
        Kin: \(race.rawValue)
        Profession: \(profession.rawValue)
        Age: \(age.rawValue)
        Abilities: \(heroicAbilities.map { $0.rawValue }.joined(separator: ", "))
        Trained Skills: \(trainedSkills.map { $0.rawValue }.joined(separator: ", "))
        Magic: \(magic.joined(separator: ", "))
        Weakness: \(weakness)
        Attributes:
          STR: \(strength)
          CON: \(constitution)
          AGL: \(agility)
          INT: \(intelligence)
          WIL: \(willpower)
          CHR: \(charisma)
        Gear:
        \(gear.map { "  \($0)" }.joined(separator: "\n"))
        Memento: \(memento)
        Appearance Seeds:
        \(appearanceSeeds.map { "  \($0)" }.joined(separator: "\n"))
        """
    }
}

// Generate a random character name from a predefined list.
func generateName() -> String {
    let names = ["Aragorn", "Baldur", "Celeste", "Darian", "Elora", "Fendrel", "Garen", "Helena", "Ivor", "Jora"]
    return names.randomElement() ?? "Hero"
}

// Roll four 6-sided dice, drop the lowest, and return the total.
// This is a common method to determine ability scores.
func rollAbilityScore() -> Int {
    var rolls: [Int] = []
    for _ in 0..<4 {
        let roll = Int.random(in: 1...6)
        rolls.append(roll)
    }
    // Sort in descending order and sum the three highest values.
    let total = rolls.sorted(by: >).prefix(3).reduce(0, +)
    return total
}

func selectProfession() -> Profession {
    let roll = Double.random(in: 0.0...1.0)
    if roll < 0.10 {
        // 10% chance to be a mage: select one of the three mage subclasses
        let mageProfessions: [Profession] = [.animist, .elementalist, .mentalist]
        return mageProfessions.randomElement()!
    } else {
        // 90% chance: select any profession that is not a mage
        let nonMageProfessions = Profession.allCases.filter { ![.animist, .elementalist, .mentalist].contains($0) }
        return nonMageProfessions.randomElement()!
    }
}

// Create a new character with randomly generated traits.
func generateCharacter() -> Character {
    let profession = selectProfession()
    let age = rollAge()
    let attributeDict = generateAttributes(for: profession, age: age)
    let kin = selectKin()
    var newCharacter = Character(
        name: generateName(),
        race: kin,
        profession: profession,
        age: age,
        heroicAbilities: [],
        trainedSkills: [],
        magic: selectStartingMagic(profession: profession),
        weakness: "",
        strength: attributeDict[.str] ?? 0,
        constitution: attributeDict[.con] ?? 0,
        agility: attributeDict[.agl] ?? 0,
        intelligence: attributeDict[.int] ?? 0,
        willpower: attributeDict[.wil] ?? 0,
        charisma: attributeDict[.cha] ?? 0,
        gear: rollGear(profession: profession),
        memento: selectMemento(),
        appearanceSeeds: selectAppearanceSeeds(kin: kin)
    )

    newCharacter.heroicAbilities = newCharacter.race.startingAbilities
    if !profession.heroicAbilities.isEmpty {
        let selectedProfessionHeroic = profession.heroicAbilities.randomElement()!
        newCharacter.heroicAbilities.append(selectedProfessionHeroic)
    }

    // Select 6 skills from the profession's skills list
    let requiredSkills = Array(profession.skills.shuffled().prefix(6))

    // Determine additional skills count based on age
    let additionalCount: Int
    switch age {
    case .young:
        additionalCount = 2
    case .adult:
        additionalCount = 4
    case .old:
        additionalCount = 6
    }

    // From the remaining Skills pool (all skills not in requiredSkills), select additional skills
    let remainingPool = Skills.allCases.filter { !requiredSkills.contains($0) }
    let additionalSkills = Array(remainingPool.shuffled().prefix(additionalCount))

    // Assign trained skills by combining the required and additional skills
    newCharacter.trainedSkills = requiredSkills + additionalSkills

    newCharacter.weakness = selectWeakness()

    return newCharacter
}

func generateAttributes(for profession: Profession, age: Age) -> [Attributes: Int] {
    // Roll 6 times using 4d6 drop the lowest
    var rolls = (0..<6).map { _ in rollAbilityScore() }

    // Assign the highest roll to the profession's key attribute
    let keyAttr = profession.keyAttribute
    let maxRoll = rolls.max()!
    if let index = rolls.firstIndex(of: maxRoll) {
        rolls.remove(at: index)
    }

    // Get the remaining attributes (excluding the key attribute) and shuffle them
    let remainingAttributes = Attributes.allCases.filter { $0 != keyAttr }
    let shuffledRolls = rolls.shuffled()

    var result: [Attributes: Int] = [:]
    result[keyAttr] = maxRoll
    for (index, attribute) in remainingAttributes.enumerated() {
        result[attribute] = shuffledRolls[index]
    }

    return applyAgeModifiers(to: result, for: age)
}

func applyAgeModifiers(to attributes: [Attributes: Int], for age: Age) -> [Attributes: Int] {
    var modified = attributes
    switch age {
    case .young:
        // Young: Agility and Constitution +1
        modified[.agl]? += 1
        modified[.con]? += 1
    case .adult:
        // Adult: no attribute modifications
        break
    case .old:
        // Old: Strength, Agility, Constitution -2; Intelligence and Willpower +1
        modified[.str]? -= 2
        modified[.agl]? -= 2
        modified[.con]? -= 2
        modified[.int]? += 1
        modified[.wil]? += 1
    }
    return modified
}

func readWeaknesses() -> [String] {
    guard let fileURL = Bundle.module.url(forResource: "weaknesses", withExtension: "txt"),
          let content = try? String(contentsOf: fileURL) else {
        return []
    }
    let lines = content.components(separatedBy: .newlines)
    return lines.filter { !$0.isEmpty }
}

func selectWeakness() -> String {
    let weaknesses = readWeaknesses()
    if weaknesses.isEmpty {
        return "No weakness specified"
    } else {
        return weaknesses.randomElement()!
    }
}

func readMementos() -> [String] {
    guard let fileURL = Bundle.module.url(forResource: "mementos", withExtension: "txt"),
          let content = try? String(contentsOf: fileURL) else {
        return []
    }
    let lines = content.components(separatedBy: .newlines)
    return lines.filter { !$0.isEmpty }
}

func selectMemento() -> String {
    let mementos = readMementos()
    if mementos.isEmpty {
        return "No memento specified"
    } else {
        return mementos.randomElement()!
    }
}

func readAppearanceSeeds(kin : Race) -> [String] {
    guard let fileURL = Bundle.module.url(forResource: "appearance_\(kin.rawValue.lowercased())", withExtension: "txt"),
          let content = try? String(contentsOf: fileURL) else {
        return []
    }
    let lines = content.components(separatedBy: .newlines)
    return lines.filter { !$0.isEmpty }
}

// Select two random appearance traits from the file
func selectAppearanceSeeds(kin: Race) -> [String] {
    let appearanceSeeds = readAppearanceSeeds(kin: kin)
    if appearanceSeeds.isEmpty {
        return ["No appearance specified"]
    } else {
        let selectedSeeds = appearanceSeeds.shuffled().prefix(2)
        return Array(selectedSeeds)
    }
}

func selectStartingMagic(profession: Profession) -> [String] {
    // This function should return a list of starting magic spells based on the profession.
    // For now, we will return an empty array.
    // return []

    let generalMagicTricks: [String] = [
        "FETCH",
        "FLICK",
        "LIGHT",
        "OPEN/CLOSE",
        "REPAIR CLOTHES",
        "SENSE MAGIC"
    ]

    let generalMagicRank1: [String] = [
        "DISPEL",
        "PROTECTOR"
    ]

    let animismMagicTricks: [String] = [
        "BIRDSONG",
        "CLEAN",
        "COOK FOOD",
        "FLORAL TRAIL",
        "HAIRSTYLE"
    ]

    let animismMagicRank1: [String] = [
        "ANIMAL WHISPERER",
        "BANISH",
        "ENSNARING ROOTS",
        "LIGHTNING FLASH",
        "TREAT WOUND"
    ]

    let elementalistMagicTricks: [String] = [
        "HEAT/CHILL",
        "IGNIGHT",
        "PUFF OF SMOKE"
    ]

    let elementalistMagicRank1: [String] = [
        "FIREBALL",
        "FROST",
        "GUST OF WIND",
        "PILLAR",
        "SHATTER"
    ]

    let mentalismMagicTricks: [String] = [
        "LOCK/UNLOCK",
        "MAGIC STOOL",
        "SLOW FALL"
    ]

    let mentalismMagicRank1: [String] = [
        "FARSIGHT",
        "LEVITATE",
        "LONGSTRIDER",
        "POWER FIST",
        "STONE SKIN"
    ]

    var magicTricks: [String] = []
    var magicRank1: [String] = []
    switch profession {
    case .animist:
        magicTricks = animismMagicTricks + generalMagicTricks
        magicRank1 = animismMagicRank1 + generalMagicRank1
    case .elementalist:
        magicTricks = elementalistMagicTricks + generalMagicTricks
        magicRank1 = elementalistMagicRank1 + generalMagicRank1
    case .mentalist:
        magicTricks = mentalismMagicTricks + generalMagicTricks
        magicRank1 = mentalismMagicRank1 + generalMagicRank1
    default:
        return [];
    }

    let selectedTricks: Array<String>.SubSequence = magicTricks.shuffled().prefix(3)
    let selectedRank1: Array<String>.SubSequence = magicRank1.shuffled().prefix(3)

    return Array(selectedTricks) + Array(selectedRank1)
}

@main
struct DragonbaneCharacterCreator: ParsableCommand {
    mutating func run() throws {
        let newCharacter = generateCharacter()
        print(newCharacter.description())
    }
}
