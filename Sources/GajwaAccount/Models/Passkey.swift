//
//  Passkey.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/26.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent
import Vapor
import WebAuthn

final class Passkey: Model, Content, @unchecked Sendable {
    static let schema = "passkeys"

    @ID(custom: "id", generatedBy: .user)
    var id: String?

    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "public_key")
    var publicKey: String

    @Field(key: "current_sign_count")
    var currentSignCount: Int

    init() {}

    init(id: String, userID: UUID, publicKey: String, currentSignCount: Int) {
        self.id = id
        self.$user.id = userID
        self.publicKey = publicKey
        self.currentSignCount = currentSignCount
    }

    convenience init(from credential: Credential, userID: UUID) {
        self.init(
            id: credential.id,
            userID: userID,
            publicKey: credential.publicKey.base64URLEncodedString().asString(),
            currentSignCount: Int(credential.signCount)
        )
    }
}

extension Passkey {
    struct Create: Content {
        let id: String
        let publicKey: String
        let currentSignCount: UInt32
        let userID: UUID
    }
}
