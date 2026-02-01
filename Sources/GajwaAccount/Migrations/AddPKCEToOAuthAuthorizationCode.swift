//
//  AddPKCEToOAuthAuthorizationCode.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/02.
//  Copyright © 2026 Js Na. All rights reserved.
//

import Fluent

struct AddPKCEToOAuthAuthorizationCode: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("oauth_authorization_codes")
            .field("code_challenge", .string)
            .field("code_challenge_method", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("oauth_authorization_codes")
            .deleteField("code_challenge")
            .deleteField("code_challenge_method")
            .update()
    }
}
