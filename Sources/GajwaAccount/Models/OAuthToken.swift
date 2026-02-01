//
//  OAuthToken.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Vapor
import Fluent

final class OAuthToken: Model, @unchecked Sendable {
    static let schema = "oauth_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "access_token")
    var accessToken: String

    @OptionalField(key: "refresh_token")
    var refreshToken: String?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "client_id")
    var client: OAuthClient

    @Field(key: "scope")
    var scope: String

    @Field(key: "expires_at")
    var expiresAt: Date

    @Field(key: "token_type")
    var tokenType: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        accessToken: String,
        refreshToken: String? = nil,
        userID: UUID,
        clientID: UUID,
        scope: String,
        expiresAt: Date,
        tokenType: String = "Bearer"
    ) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.$user.id = userID
        self.$client.id = clientID
        self.scope = scope
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }

    func isExpired() -> Bool {
        return expiresAt < Date()
    }
}

struct OAuthTokenResponse: Content {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }

    init(from token: OAuthToken) {
        self.accessToken = token.accessToken
        self.refreshToken = token.refreshToken
        self.tokenType = token.tokenType
        // Ensure expiresIn is never negative
        self.expiresIn = max(0, Int(token.expiresAt.timeIntervalSince(Date())))
        self.scope = token.scope
    }
}
