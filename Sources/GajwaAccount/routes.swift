import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }
    
    app.get("auth") { req async throws -> View in
        // academicYear 기준: 3월
        let month: Int = Calendar.current.component(.month, from: Date())
        let year: Int = Calendar.current.component(.year, from: Date())
        let academicYear: String = month >= 3 ? String(year) : String(year - 1)
        return try await req.view.render("auth", ["academicYear": academicYear])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    try app.register(collection: UserAPIController())
}
