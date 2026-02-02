//
//  configure.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/25.
//  Copyright © 2025 Js Na. All rights reserved.
//

import NIOSSL
import Fluent
import FluentPostgresDriver
import Leaf
import Vapor
import Queues
import QueuesFluentDriver

// configures your application
public func configure(_ app: Application) async throws {
    
    app.http.server.configuration.port = Environment.get("APP_PORT").flatMap(Int.init(_:)) ?? 8080

    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
    
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(User.asyncSessionAuthenticator())
    
    // Configure Queues (using Fluent/PostgreSQL)
    app.queues.use(.fluent())
    
    // Register scheduled jobs
    app.queues.schedule(DeleteDeactivatedUsersJob())
        .daily()
        .at(.midnight)
    
    // Queues migrations
    app.migrations.add(JobModelMigration())
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserVerification())
    app.migrations.add(CreatePasskey())
    app.migrations.add(CreateOAuthClient())
    app.migrations.add(CreateOAuthToken())
    app.migrations.add(CreateOAuthAuthorizationCode())

    try await app.autoMigrate()

    app.views.use(.leaf)

    // register routes
    try routes(app)
    
    // Start scheduled jobs in-process
    try app.queues.startScheduledJobs()
}
