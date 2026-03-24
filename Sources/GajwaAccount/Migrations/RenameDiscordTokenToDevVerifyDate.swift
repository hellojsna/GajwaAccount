//
//  RenameDiscordTokenToDevVerifyDate.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2026 Js Na. All rights reserved.
//

import Fluent

struct RenameDiscordTokenToDevVerifyDate: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // user_discord_token 컬럼을 user_dev_verify_date로 변경
        // 기존에 user_discord_token이 있으면 삭제하고 새로운 컬럼 추가
        try await database.schema("users")
            .deleteField("user_discord_token")
            .field("user_dev_verify_date", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        // 롤백: user_dev_verify_date를 user_discord_token으로 변경
        try await database.schema("users")
            .deleteField("user_dev_verify_date")
            .field("user_discord_token", .string)
            .update()
    }
}
