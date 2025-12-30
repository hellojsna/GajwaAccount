//
//  Request+webAuthn.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/25.
//  Copyright © 2025 Js Na. All rights reserved.
//
    
import Vapor
import WebAuthn

extension Request {
    var webAuthn: WebAuthnManager {
        WebAuthnManager(
            configuration: WebAuthnManager.Configuration(
                relyingPartyID: Environment.get("WEBAUTHN_RP_ID") ?? "localhost",
                relyingPartyName: Environment.get("WEBAUTHN_RP_NAME") ?? "Gajwa Dev",
                relyingPartyOrigin: Environment.get("WEBAUTHN_RP_ORIGIN") ?? "http://localhost"
            )
        )
    }
}
