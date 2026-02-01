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
                    auth.post("register", "create") { req in
                        struct RegisterOptionsRequest: Content {
                            let userLoginID: String
                            let userLoginPassword: String
                            let userName: String
                            let userStudentIDList: String
                            let userEmail: String
                        }
                        
                        let request = try req.content.decode(RegisterOptionsRequest.self)
                        let userStudentIDList = request.userStudentIDList.components(separatedBy: ":").sorted()
                        let hashedPassword = try Bcrypt.hash(request.userLoginPassword)
                        
                        let user = User(
                            userLoginID: request.userLoginID,
                            userLoginPassword: hashedPassword,
                            userName: request.userName,
                            userStudentIDList: userStudentIDList,
                            userEmail: request.userEmail
                        )
                        
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
                    
                    auth.post("register", "passkey") { req in
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
                    
                    auth.post("register", "skip") { req in
                        let user = try req.auth.require(User.self)
                        req.session.data["registrationChallenge"] = nil
                        return HTTPStatus.ok
                    }
                    
                    auth.get("login", "passkey") { req in
                        let options = try req.webAuthn.beginAuthentication()
                        
                        req.session.data["authChallenge"] = Data(options.challenge).base64EncodedString()
                        
                        return RequestCredentialOptions(publicKey: options)
                    }
                    
                    auth.post("login", "passkey") { req in
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
                        
                        struct LoginResponse: Content {
                            let success: Bool
                            let redirectURL: String
                        }
                        
                        // Check for redirect URL (from OAuth flow)
                        let redirectURL = req.session.data["oauth_redirect_after_login"] ?? "/home"
                        req.session.data["oauth_redirect_after_login"] = nil
                        
                        return LoginResponse(success: true, redirectURL: redirectURL)
                    }
                    
                    auth.post("login", "password") { req in
                        struct PasswordLoginRequest: Content {
                            let userLoginID: String
                            let userLoginPassword: String
                        }
                        
                        struct PasswordLoginResponse: Content {
                            let success: Bool
                            let redirectURL: String
                        }
                        
                        let request = try req.content.decode(PasswordLoginRequest.self)
                        
                        guard let user = try await User.query(on: req.db)
                            .filter(\.$userLoginID == request.userLoginID)
                            .first() else {
                            throw Abort(.unauthorized, reason: "Invalid credentials")
                        }
                        
                        let verifiedHashed = (try? Bcrypt.verify(request.userLoginPassword, created: user.userLoginPassword)) == true
                        let verifiedPlain = user.userLoginPassword == request.userLoginPassword
                        guard verifiedHashed || verifiedPlain else {
                            throw Abort(.unauthorized, reason: "Invalid credentials")
                        }
                        if verifiedPlain && !verifiedHashed {
                            user.userLoginPassword = try Bcrypt.hash(request.userLoginPassword)
                            try await user.save(on: req.db)
                        }
                        
                        req.auth.login(user)
                        
                        // Check for redirect URL (from OAuth flow)
                        let redirectURL = req.session.data["oauth_redirect_after_login"] ?? "/home"
                        req.session.data["oauth_redirect_after_login"] = nil
                        
                        return PasswordLoginResponse(success: true, redirectURL: redirectURL)
                    }
                    
                    auth.post("logout") { req -> HTTPStatus in
                        req.auth.logout(User.self)
                        req.session.destroy()
                        return HTTPStatus.ok
                    }
                }

                apiv1.group("user") { user in
                    let protected = user.grouped(User.asyncSessionAuthenticator()).grouped(User.guardMiddleware())

                    protected.patch("profile") { req async throws -> HTTPStatus in
                        struct UpdateProfileRequest: Content {
                            let userName: String
                            let userEmail: String
                        }
                        
                        let user = try req.auth.require(User.self)
                        let request = try req.content.decode(UpdateProfileRequest.self)
                        
                        user.userName = request.userName
                        user.userEmail = request.userEmail
                        
                        try await user.save(on: req.db)
                        return HTTPStatus.ok
                    }

                    protected.post("student-id") { req async throws -> HTTPStatus in
                        struct AddStudentIDRequest: Content {
                            let userStudentIDList: String
                        }
                        
                        let user = try req.auth.require(User.self)
                        let request = try req.content.decode(AddStudentIDRequest.self)
                        
                        // 중복 검사
                        if user.userStudentIDList.contains(request.userStudentIDList) {
                            throw Abort(.conflict, reason: "Student ID already exists")
                        }
                        
                        user.userStudentIDList.append(request.userStudentIDList)
                        user.userStudentIDList.sort()
                        try await user.save(on: req.db)
                        
                        return HTTPStatus.ok
                    }

                    protected.delete("student-id", ":studentIdFull") { req async throws -> HTTPStatus in
                        let user = try req.auth.require(User.self)
                        
                        guard let studentIdFull = req.parameters.get("studentIdFull") else {
                            throw Abort(.badRequest, reason: "Missing student ID")
                        }
                        
                        user.userStudentIDList.removeAll { $0 == studentIdFull }
                        try await user.save(on: req.db)
                        
                        return HTTPStatus.ok
                    }

                    protected.patch("password") { req async throws -> HTTPStatus in
                        struct ChangePasswordRequest: Content {
                            let currentPassword: String
                            let newPassword: String
                        }
                        
                        let user = try req.auth.require(User.self)
                        let request = try req.content.decode(ChangePasswordRequest.self)
                        
                        // 현재 비밀번호 검증
                        let verifiedHashed = (try? Bcrypt.verify(request.currentPassword, created: user.userLoginPassword)) == true
                        let verifiedPlain = user.userLoginPassword == request.currentPassword
                        
                        guard verifiedHashed || verifiedPlain else {
                            throw Abort(.unauthorized, reason: "Current password is incorrect")
                        }
                        
                        // 새 비밀번호 해시화
                        user.userLoginPassword = try Bcrypt.hash(request.newPassword)
                        try await user.save(on: req.db)
                        
                        return HTTPStatus.ok
                    }
                }

                apiv1.group("passkeys") { passkeys in
                    let protected = passkeys.grouped(User.asyncSessionAuthenticator()).grouped(User.guardMiddleware())

                    protected.get { req async throws -> [PasskeySummary] in
                        let user = try req.auth.require(User.self)
                        let userID = try user.requireID()
                        let items = try await Passkey.query(on: req.db)
                            .filter(\.$user.$id == userID)
                            .all()
                        return items.map { PasskeySummary(id: $0.id ?? "", currentSignCount: $0.currentSignCount) }
                    }

                    protected.post("create") { req async throws -> CreateCredentialOptions in
                        let user = try req.auth.require(User.self)
                        let options = req.webAuthn.beginRegistration(user:
                                .init(
                                    id: try [UInt8](user.requireID().uuidString.utf8),
                                    name: user.userLoginID,
                                    displayName: user.userName
                                )
                        )
                        req.session.data["passkeyManageChallenge"] = Data(options.challenge).base64EncodedString()
                        return CreateCredentialOptions(publicKey: options)
                    }

                    protected.post { req async throws -> HTTPStatus in
                        let user = try req.auth.require(User.self)
                        let userID = try user.requireID()

                        guard let challengeEncoded = req.session.data["passkeyManageChallenge"],
                              let challenge = Data(base64Encoded: challengeEncoded) else {
                            throw Abort(.badRequest, reason: "Missing passkey challenge")
                        }

                        req.session.data["passkeyManageChallenge"] = nil

                        let registration = try req.content.decode(RegistrationCredential.self)

                        if let existing = try await Passkey.query(on: req.db)
                            .filter(\.$id == registration.id.urlDecoded.asString())
                            .first(), existing.$user.id == userID {
                            throw Abort(.conflict, reason: "Passkey already exists")
                        }

                        let credential = try await req.webAuthn.finishRegistration(
                            challenge: [UInt8](challenge),
                            credentialCreationData: registration,
                            confirmCredentialIDNotRegisteredYet: { _ in true }
                        )

                        try await Passkey(
                            id: credential.id,
                            userID: userID,
                            publicKey: credential.publicKey.base64URLEncodedString().asString(),
                            currentSignCount: Int(credential.signCount)
                        ).save(on: req.db)

                        return HTTPStatus.ok
                    }

                    protected.delete(":id") { req async throws -> HTTPStatus in
                        let user = try req.auth.require(User.self)
                        let userID = try user.requireID()
                        guard let id = req.parameters.get("id") else {
                            throw Abort(.badRequest, reason: "Missing passkey id")
                        }

                        guard let passkey = try await Passkey.query(on: req.db)
                            .filter(\.$id == id)
                            .filter(\.$user.$id == userID)
                            .first() else {
                            throw Abort(.notFound)
                        }

                        try await passkey.delete(on: req.db)
                        return HTTPStatus.ok
                    }
                }
            }
        }
    }
}

private struct PasskeySummary: Content {
    let id: String
    let currentSignCount: Int
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
