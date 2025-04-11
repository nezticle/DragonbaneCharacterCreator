// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonbaneCharacterCreator",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "DragonbaneCharacterCreator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .copy("weaknesses.txt"),
                .copy("mementos.txt"),
                .copy("appearance_catpeople.txt"),
                .copy("appearance_dwarf.txt"),
                .copy("appearance_elf.txt"),
                .copy("appearance_frogpeople.txt"),
                .copy("appearance_goblin.txt"),
                .copy("appearance_halfling.txt"),
                .copy("appearance_hobgoblin.txt"),
                .copy("appearance_human.txt"),
                .copy("appearance_karkion.txt"),
                .copy("appearance_lizardpeople.txt"),
                .copy("appearance_mallard.txt"),
                .copy("appearance_ogre.txt"),
                .copy("appearance_orc.txt"),
                .copy("appearance_satyr.txt"),
                .copy("appearance_wolfkin.txt")
            ]
        ),
    ]
)
