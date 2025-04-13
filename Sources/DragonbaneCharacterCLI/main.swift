import DragonbaneCharacterCore
import ArgumentParser

struct DragonbaneCharacterCLI: ParsableCommand {
    mutating func run() throws {
        let newCharacter = generateCharacter()
        print(newCharacter.description())
    }
}

DragonbaneCharacterCLI.main()