import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application) throws {
    if let url = Environment.get("DATABASE_URL"), var config = PostgresConfiguration(url: url) {
        if let tlsSetting = Environment.get("DATABASE_TLS"), tlsSetting.lowercased() == "disable" {
            config.tlsConfiguration = nil
        }
        app.databases.use(.postgres(configuration: config, maxConnectionsPerEventLoop: 5), as: .psql)
    } else {
        let hostname = Environment.get("POSTGRES_HOST") ?? "localhost"
        let port = Environment.get("POSTGRES_PORT").flatMap(Int.init) ?? PostgresConfiguration.ianaPortNumber
        let username = Environment.get("POSTGRES_USER") ?? "dragonbane"
        let password = Environment.get("POSTGRES_PASSWORD") ?? "dragonbane"
        let database = Environment.get("POSTGRES_DB") ?? "dragonbane"

        app.databases.use(.postgres(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: database
        ), as: .psql)
    }

    app.migrations.add(CreateCharacterMigration())

    // Ensure static resources packaged with the executable are discoverable.
    app.directory.publicDirectory = app.directory.resourcesDirectory + "Public/"
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory, defaultFile: "index.html"))

    try routes(app)
}
