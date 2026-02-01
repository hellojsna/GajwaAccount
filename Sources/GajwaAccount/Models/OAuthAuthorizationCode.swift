//
//  OAuthAuthorizationCode.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Vapor
import Fluent

final class OAuthAuthorizationCode: Model, @unchecked Sendable {
    static let schema = "oauth_authorization_codes"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "code")
    var code: String

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "client_id")
    var client: OAuthClient

    @Field(key: "redirect_uri")
    var redirectURI: String

    @Field(key: "scope")
    var scope: String

    @Field(key: "expires_at")
    var expiresAt: Date

    @Field(key: "is_used")
    var isUsed: Bool

    @OptionalField(key: "code_challenge")
    var codeChallenge: String?

    @OptionalField(key: "code_challenge_method")
    var codeChallengeMethod: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        code: String,
        userID: UUID,
        clientID: UUID,
        redirectURI: String,
        scope: String,
        expiresAt: Date,
        isUsed: Bool = false,
        codeChallenge: String? = nil,
        codeChallengeMethod: String? = nil
    ) {
        self.id = id
        self.code = code
        self.$user.id = userID
        self.$client.id = clientID
        self.redirectURI = redirectURI
        self.scope = scope
        self.expiresAt = expiresAt
        self.isUsed = isUsed
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
    }

    func isExpired() -> Bool {
        return expiresAt < Date()
    }
}
