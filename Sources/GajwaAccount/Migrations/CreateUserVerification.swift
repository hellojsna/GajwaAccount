//
//  CreateUserVerification.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/30.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent

struct CreateUserVerification: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_verifications")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("user_verification_lat", .double) // 재학생 인증 - GPS 위치 (위도)
            .field("user_verification_long", .double) // 재학생 인증 - GPS 위치 (경도)
            .field("user_verification_idcard", .string) // 재학생 인증 - 학생증 바코드 번호
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_verifications").delete()
    }
}
