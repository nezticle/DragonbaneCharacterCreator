// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonbaneCharacterCreator",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "DragonbaneCharacterCore",
            targets: ["DragonbaneCharacterCore"]
        ),
        .library(
            name: "DragonbaneCharacterPersistence",
            targets: ["DragonbaneCharacterPersistence"]
        ),
        .executable(
            name: "DragonbaneCharacterCLI",
            targets: ["DragonbaneCharacterCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.4.1"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.2"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0")
    ],
    targets: [
        .target(
            name: "DragonbaneCharacterCore",
            dependencies: [],
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
        .target(
            name: "DragonbaneCharacterPersistence",
            dependencies: [
                "DragonbaneCharacterCore",
                .product(name: "GRDB", package: "GRDB.swift"),
                "SQLiteSnapshotShims",
            ]
        ),
        .executableTarget(
            name: "DragonbaneCharacterCLI",
            dependencies: [
                "DragonbaneCharacterCore",
                "DragonbaneCharacterPersistence",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "SQLiteSnapshotShims",
            dependencies: []
        ),
        .executableTarget(
            name: "DragonbaneCharacterServer",
            dependencies: [
                "DragonbaneCharacterCore",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
            ],
            resources: [
                .copy("Public")
            ]
        ),
    ]
)
