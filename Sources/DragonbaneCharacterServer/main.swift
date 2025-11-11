import Vapor
import Fluent

var env = try Environment.detect()
let app = Application(env)
defer { app.shutdown() }

try configure(app)
try app.autoMigrate().wait()
try app.run()
