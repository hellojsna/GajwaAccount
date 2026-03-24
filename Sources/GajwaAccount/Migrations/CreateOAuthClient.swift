//
//  CreateOAuthClient.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreateOAuthClient: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("oauth_clients")
            .id()
            .field("client_id", .string, .required)
            .field("client_secret", .string, .required)
            .field("app_name", .string, .required)
            .field("app_description", .string, .required)
            .field("redirect_uris", .array(of: .string), .required)
            .field("homepage_url", .string)
            .field("logo_url", .string)
            .field("is_confidential", .bool, .required)
            .field("developer_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("scopes", .array(of: .string), .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "client_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("oauth_clients").delete()
    }
}
