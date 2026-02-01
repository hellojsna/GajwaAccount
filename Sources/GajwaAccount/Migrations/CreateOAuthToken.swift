//
//  CreateOAuthToken.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreateOAuthToken: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("oauth_tokens")
            .id()
            .field("access_token", .string, .required)
            .field("refresh_token", .string)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("client_id", .uuid, .required, .references("oauth_clients", "id", onDelete: .cascade))
            .field("scope", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("token_type", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "access_token")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("oauth_tokens").delete()
    }
}
