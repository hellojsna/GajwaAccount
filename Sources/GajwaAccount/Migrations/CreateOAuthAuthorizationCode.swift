//
//  CreateOAuthAuthorizationCode.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreateOAuthAuthorizationCode: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("oauth_authorization_codes")
            .id()
            .field("code", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("client_id", .uuid, .required, .references("oauth_clients", "id", onDelete: .cascade))
            .field("redirect_uri", .string, .required)
            .field("scope", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("is_used", .bool, .required)
            .field("created_at", .datetime)
            .unique(on: "code")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("oauth_authorization_codes").delete()
    }
}
