//
//  CreatePasskey.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/30.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreatePasskey: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("passkeys")
            .field("id", .string, .identifier(auto: false))
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("public_key", .string, .required)
            .field("current_sign_count", .int, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("passkeys").delete()
    }
}
