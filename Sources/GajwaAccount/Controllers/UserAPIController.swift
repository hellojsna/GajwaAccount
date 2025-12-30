//
//  UserAPIController.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/26.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent
import Vapor
import WebAuthn

struct UserAPIController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // MARK: Gajwa Domain API
        routes.group("api") { api in
            api.get { req async -> String in
                "API page"
            }
            api.group("v1") { apiv1 in
                apiv1.group("auth") { auth in
                    auth.get("signup") { req in
                        let userLoginID = try req.query.get(String.self, at: "userLoginID")
                        let userName = try req.query.get(String.self, at: "userName")
                        let userStudentIDList = try req.query.get(String.self, at: "userStudentIDList").components(separatedBy: ":")
                        let userEmail = try req.query.get(String.self, at: "userEmail")
                        
                        let user = User(userLoginID: userLoginID, userName: userName, userStudentIDList: userStudentIDList, userEmail: userEmail)
                        
                        try await user.create(on: req.db)
                        req.auth.login(user)
                        
                        let options = req.webAuthn.beginRegistration(user:
                                .init(
                                    id: try [UInt8](user.requireID().uuidString.utf8),
                                    name: user.userLoginID,
                                    displayName: user.userName
                                )
                        )
                        req.session.data["registrationChallenge"] = Data(options.challenge).base64EncodedString()
                        
                        return CreateCredentialOptions(publicKey: options)
                    }
                    
                    auth.post("signup") { req in
                        let user = try req.auth.require(User.self)
                        
                        guard let challengeEncoded = req.session.data["registrationChallenge"],
                              let challenge = Data(base64Encoded: challengeEncoded) else {
                            throw Abort(.badRequest, reason: "Missing registration challenge")
                        }
                        
                        req.session.data["registrationChallenge"] = nil
                        
                        let credential = try await req.webAuthn.finishRegistration(
                            challenge: [UInt8](challenge),
                            credentialCreationData: req.content.decode(RegistrationCredential.self),
                            confirmCredentialIDNotRegisteredYet: { _ in true}
                        )
                        
                        try await Passkey(
                            id: credential.id,
                            userID: user.requireID(), publicKey: credential.publicKey.base64URLEncodedString().asString(),
                            currentSignCount: Int(credential.signCount)
                        ).save(on: req.db)
                        
                        return HTTPStatus.ok
                    }
                    
                    auth.get("signin") { req in
                        let options = try req.webAuthn.beginAuthentication()
                        
                        req.session.data["authChallenge"] = Data(options.challenge).base64EncodedString()
                        
                        return RequestCredentialOptions(publicKey: options)
                    }
                    
                    auth.post("signin") { req in
                        guard let challengeEncoded = req.session.data["authChallenge"],
                              let challenge = Data(base64Encoded: challengeEncoded) else {
                            throw Abort(.badRequest, reason: "Missing authentication challenge")
                        }
                        
                        req.session.data["authChallenge"] = nil
                        
                        let authenticationCredential = try req.content.decode(AuthenticationCredential.self)
                        
                        guard let credential = try await Passkey.query(on: req.db)
                            .filter(\.$id == authenticationCredential.id.urlDecoded.asString())
                            .with(\.$user)
                            .first() else {
                            throw Abort(.unauthorized)
                        }
                        
                        let verifiedAuthentication = try req.webAuthn.finishAuthentication(
                            credential: authenticationCredential,
                            expectedChallenge: [UInt8](challenge),
                            credentialPublicKey: [UInt8](URLEncodedBase64(credential.publicKey).urlDecoded.decoded!),
                            credentialCurrentSignCount: UInt32(credential.currentSignCount)
                        )
                        
                        credential.currentSignCount = Int(verifiedAuthentication.newSignCount)
                        try await credential.save(on: req.db)
                        
                        req.auth.login(credential.user)
                        return HTTPStatus.ok
                    }
                }
            }
        }
    }
}

struct CreateCredentialOptions: Encodable, AsyncResponseEncodable {
    let publicKey: PublicKeyCredentialCreationOptions

    func encodeResponse(for request: Request) async throws -> Response {
        var headers = HTTPHeaders()
        headers.contentType = .json
        return try Response(status: .ok, headers: headers, body: .init(data: JSONEncoder().encode(self)))
    }
}

struct RequestCredentialOptions: Encodable, AsyncResponseEncodable {
    let publicKey: PublicKeyCredentialRequestOptions

    func encodeResponse(for request: Request) async throws -> Response {
        var headers = HTTPHeaders()
        headers.contentType = .json
        return try Response(status: .ok, headers: headers, body: .init(data: JSONEncoder().encode(self)))
    }
}
