//
//  routes.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/25.
//  Copyright © 2025 Js Na. All rights reserved.
//

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
    
    let auth = app.grouped(User.asyncSessionAuthenticator()).grouped(User.redirectMiddleware(path: "/auth"))
    auth.get("home") { req async throws -> View in
        let user = try req.auth.require(User.self)
        struct userStudentIDMap: Content {
            let year: String
            let studentID: String
        }
        struct PageContext: Content {
            let user: User
            let userStudentIDMap: [userStudentIDMap?]
        }
        let mappedUserStudentIDList = user.userStudentIDList.map { code -> userStudentIDMap? in
            let parts = code.split(separator: "-")
            guard parts.count == 2 else { return nil }
            return userStudentIDMap(year: String(parts[0]), studentID: String(parts[1]))
        }
        return try await req.view.render("home", PageContext(user: user, userStudentIDMap: mappedUserStudentIDList))
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    try app.register(collection: UserAPIController())
}
