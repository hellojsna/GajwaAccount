//
//  CreateUser.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/30.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .id()
            .field("user_login_id", .string, .required) // 로그인 ID
            .field("user_name", .string, .required) // 이름
            .field("user_student_id_list", .array(of: .string), .required) // 학번 리스트 (매년 변경하는 것이 아닌 추가) YYYY-학번 형식
            .field("user_email", .string, .required) // 이메일 주소
            .field("user_phone", .string) // 전화번호
            .field("user_discord_token", .string) // Discord OAuth2 (Gajwa Dev)
            .unique(on: "user_login_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}
