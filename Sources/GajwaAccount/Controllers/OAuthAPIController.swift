//
//  OAuthAPIController.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Vapor
import Fluent
import Crypto

// MARK: - OAuth2 Error Response
struct OAuth2ErrorResponse: Content, Error, AbortError {
    let error: String
    let errorDescription: String?
    let errorUri: String?
    
    var status: HTTPStatus {
        switch OAuth2Error(rawValue: error) {
        case .invalidClient:
            return .unauthorized
        case .invalidGrant, .invalidRequest, .unsupportedGrantType, .invalidScope, .unsupportedResponseType:
            return .badRequest
        default:
            return .internalServerError
        }
    }
    
    var reason: String {
        errorDescription ?? "OAuth error"
    }
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case errorUri = "error_uri"
    }
    
    init(error: OAuth2Error, description: String? = nil) {
        self.error = error.rawValue
        self.errorDescription = description ?? error.defaultDescription
        self.errorUri = nil
    }
}

enum OAuth2Error: String {
    case invalidRequest = "invalid_request"
    case unauthorizedClient = "unauthorized_client"
    case accessDenied = "access_denied"
    case unsupportedResponseType = "unsupported_response_type"
    case invalidScope = "invalid_scope"
    case serverError = "server_error"
    case temporarilyUnavailable = "temporarily_unavailable"
    case invalidClient = "invalid_client"
    case invalidGrant = "invalid_grant"
    case unsupportedGrantType = "unsupported_grant_type"
    
    var defaultDescription: String {
        switch self {
        case .invalidRequest: return "The request is missing a required parameter or is otherwise malformed"
        case .unauthorizedClient: return "The client is not authorized to request an authorization code"
        case .accessDenied: return "The resource owner denied the request"
        case .unsupportedResponseType: return "The authorization server does not support this response type"
        case .invalidScope: return "The requested scope is invalid or unknown"
        case .serverError: return "The authorization server encountered an unexpected error"
        case .temporarilyUnavailable: return "The authorization server is temporarily unavailable"
        case .invalidClient: return "Client authentication failed"
        case .invalidGrant: return "The provided authorization grant is invalid"
        case .unsupportedGrantType: return "The authorization grant type is not supported"
        }
    }
}

struct OAuthAPIController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // MARK: - Developer App Management (Requires Authentication)
        routes.group("api", "v1", "oauth") { oauth in
            let protected = oauth.grouped(User.guardMiddleware())

            protected.group("apps") { apps in
                // Create OAuth app
                apps.post { req async throws -> OAuthClientDetailResponse in
                    struct CreateOAuthAppRequest: Content {
                        let appName: String
                        let appDescription: String
                        let redirectURIs: [String]
                        let homepageURL: String?
                        let logoURL: String?
                    }

                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()
                    let request = try req.content.decode(CreateOAuthAppRequest.self)

                    // Validate redirect URIs
                    for uri in request.redirectURIs {
                        guard let url = URL(string: uri), url.scheme != nil else {
                            throw Abort(.badRequest, reason: "Invalid redirect URI format")
                        }
                    }

                    // Generate client credentials
                    let clientID = "client_\(UUID().uuidString.prefix(12))"
                    let clientSecret = generateSecureSecret()

                    let oauthClient = OAuthClient(
                        clientID: clientID,
                        clientSecret: clientSecret,
                        appName: request.appName,
                        appDescription: request.appDescription,
                        redirectURIs: request.redirectURIs,
                        homepageURL: request.homepageURL,
                        logoURL: request.logoURL,
                        developerID: developerID
                    )

                    try await oauthClient.create(on: req.db)
                    return try OAuthClientDetailResponse(from: oauthClient)
                }

                // List developer's apps
                apps.get { req async throws -> [OAuthClientResponse] in
                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()

                    let clients = try await OAuthClient.query(on: req.db)
                        .filter(\.$developer.$id == developerID)
                        .all()

                    return try clients.map { try OAuthClientResponse(from: $0) }
                }

                // Get app details
                apps.get(":id") { req async throws -> OAuthClientDetailResponse in
                    guard let id = req.parameters.get("id", as: UUID.self) else {
                        throw Abort(.badRequest, reason: "Invalid app ID")
                    }

                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()

                    guard let client = try await OAuthClient.query(on: req.db)
                        .filter(\.$id == id)
                        .filter(\.$developer.$id == developerID)
                        .first() else {
                        throw Abort(.notFound, reason: "OAuth app not found")
                    }

                    return try OAuthClientDetailResponse(from: client)
                }

                // Update app
                apps.patch(":id") { req async throws -> OAuthClientDetailResponse in
                    struct UpdateOAuthAppRequest: Content {
                        let appName: String?
                        let appDescription: String?
                        let redirectURIs: [String]?
                        let homepageURL: String?
                        let logoURL: String?
                    }

                    guard let id = req.parameters.get("id", as: UUID.self) else {
                        throw Abort(.badRequest, reason: "Invalid app ID")
                    }

                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()
                    let request = try req.content.decode(UpdateOAuthAppRequest.self)

                    guard let client = try await OAuthClient.query(on: req.db)
                        .filter(\.$id == id)
                        .filter(\.$developer.$id == developerID)
                        .first() else {
                        throw Abort(.notFound, reason: "OAuth app not found")
                    }

                    if let appName = request.appName {
                        client.appName = appName
                    }
                    if let appDescription = request.appDescription {
                        client.appDescription = appDescription
                    }
                    if let redirectURIs = request.redirectURIs {
                        for uri in redirectURIs {
                            guard let url = URL(string: uri), url.scheme != nil else {
                                throw Abort(.badRequest, reason: "Invalid redirect URI format")
                            }
                        }
                        client.redirectURIs = redirectURIs
                    }
                    if let homepageURL = request.homepageURL {
                        client.homepageURL = homepageURL
                    }
                    if let logoURL = request.logoURL {
                        client.logoURL = logoURL
                    }

                    try await client.save(on: req.db)
                    return try OAuthClientDetailResponse(from: client)
                }

                // Delete app
                apps.delete(":id") { req async throws -> HTTPStatus in
                    guard let id = req.parameters.get("id", as: UUID.self) else {
                        throw Abort(.badRequest, reason: "Invalid app ID")
                    }

                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()

                    guard let client = try await OAuthClient.query(on: req.db)
                        .filter(\.$id == id)
                        .filter(\.$developer.$id == developerID)
                        .first() else {
                        throw Abort(.notFound, reason: "OAuth app not found")
                    }

                    // Delete related tokens and authorization codes
                    try await OAuthToken.query(on: req.db)
                        .filter(\.$client.$id == id)
                        .delete()

                    try await OAuthAuthorizationCode.query(on: req.db)
                        .filter(\.$client.$id == id)
                        .delete()

                    try await client.delete(on: req.db)
                    return .ok
                }

                // Regenerate client secret
                apps.post(":id", "regenerate-secret") { req async throws -> OAuthClientDetailResponse in
                    guard let id = req.parameters.get("id", as: UUID.self) else {
                        throw Abort(.badRequest, reason: "Invalid app ID")
                    }

                    let developer = try req.auth.require(User.self)
                    let developerID = try developer.requireID()

                    guard let client = try await OAuthClient.query(on: req.db)
                        .filter(\.$id == id)
                        .filter(\.$developer.$id == developerID)
                        .first() else {
                        throw Abort(.notFound, reason: "OAuth app not found")
                    }

                    client.clientSecret = generateSecureSecret()
                    try await client.save(on: req.db)
                    return try OAuthClientDetailResponse(from: client)
                }
            }
        }

        // MARK: - OAuth Authorization & Token Endpoints
        routes.post("oauth", "authorize", "confirm") { req async throws -> Response in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized, reason: "Authentication required")
            }
            
            guard let clientID = req.session.data["oauth_client_id"],
                  let redirectURIString = req.session.data["oauth_redirect_uri"],
                  let scope = req.session.data["oauth_scope"] else {
                throw Abort(.badRequest, reason: "Invalid authorization session")
            }

            let userID = try user.requireID()

            guard let client = try await OAuthClient.query(on: req.db)
                .filter(\.$clientID == clientID)
                .first() else {
                throw Abort(.unauthorized, reason: "Invalid client")
            }

            // Generate authorization code
            let authCode = generateSecureSecret()
            let expiresAt = Date().addingTimeInterval(600) // 10 minutes

            let authorizationCode = OAuthAuthorizationCode(
                code: authCode,
                userID: userID,
                clientID: try client.requireID(),
                redirectURI: redirectURIString,
                scope: scope,
                expiresAt: expiresAt,
                isUsed: false,
                codeChallenge: req.session.data["oauth_code_challenge"],
                codeChallengeMethod: req.session.data["oauth_code_challenge_method"]
            )

            try await authorizationCode.create(on: req.db)

            // Clean session data
            let state = req.session.data["oauth_state"]
            req.session.data["oauth_client_id"] = nil
            req.session.data["oauth_redirect_uri"] = nil
            req.session.data["oauth_scope"] = nil
            req.session.data["oauth_state"] = nil
            req.session.data["oauth_code_challenge"] = nil
            req.session.data["oauth_code_challenge_method"] = nil

            // Redirect to redirect_uri with authorization code
            var redirectURI = URLComponents(string: redirectURIString)!
            var queryItems = [
                URLQueryItem(name: "code", value: authCode)
            ]
            if let state = state {
                queryItems.append(URLQueryItem(name: "state", value: state))
            }
            redirectURI.queryItems = queryItems

            return req.redirect(to: redirectURI.string ?? redirectURIString)
        }
        
        routes.post("oauth", "authorize", "deny") { req async throws -> Response in
            guard let redirectURIString = req.session.data["oauth_redirect_uri"] else {
                throw Abort(.badRequest, reason: "Invalid authorization session")
            }

            let state = req.session.data["oauth_state"]

            // Clean session data
            req.session.data["oauth_client_id"] = nil
            req.session.data["oauth_redirect_uri"] = nil
            req.session.data["oauth_scope"] = nil
            req.session.data["oauth_state"] = nil
            req.session.data["oauth_code_challenge"] = nil
            req.session.data["oauth_code_challenge_method"] = nil

            return redirectWithError(
                to: redirectURIString,
                error: .accessDenied,
                description: "The user denied the authorization request",
                state: state
            )
        }
        
        // OAuth authorize endpoint (uses global session authentication from configure.swift)
        routes.get("oauth", "authorize") { req async throws -> Response in
            struct AuthorizeQuery: Content {
                let clientID: String
                let redirectURI: String
                let scope: String?
                let state: String?
                let responseType: String?
                let codeChallenge: String?
                let codeChallengeMethod: String?

                enum CodingKeys: String, CodingKey {
                    case clientID = "client_id"
                    case redirectURI = "redirect_uri"
                    case scope
                    case state
                    case responseType = "response_type"
                    case codeChallenge = "code_challenge"
                    case codeChallengeMethod = "code_challenge_method"
                }
            }

            // Require user to be logged in
            req.logger.info("OAuth authorize - Session ID: \(req.session.id?.string ?? "no session")")
            req.logger.info("OAuth authorize - Request headers: \(req.headers)")
            req.logger.info("OAuth authorize - Cookies: \(req.cookies.all)")
            
            let user = req.auth.get(User.self)
            req.logger.info("OAuth authorize - User authenticated: \(user != nil)")
            if let user = user {
                req.logger.info("OAuth authorize - User ID: \(user.id?.uuidString ?? "nil"), Login ID: \(user.userLoginID)")
            }
            
            guard let user = user else {
                req.logger.info("OAuth authorize - Redirecting to /auth")
                // Store the OAuth authorize URL in session for redirect after login
                let oauthAuthorizeURL = "/oauth/authorize?\(req.url.query ?? "")"
                req.session.data["oauth_redirect_after_login"] = oauthAuthorizeURL
                return req.redirect(to: "/auth")
            }
            
            req.logger.info("OAuth authorize - User is logged in, proceeding to consent")

            do {
                let query = try req.query.decode(AuthorizeQuery.self)
                let responseType = query.responseType ?? "code"

                // Validate response_type
                guard responseType == "code" else {
                    return redirectWithError(
                        to: query.redirectURI,
                        error: .unsupportedResponseType,
                        state: query.state
                    )
                }

                // Validate client
                guard let client = try await OAuthClient.query(on: req.db)
                    .filter(\.$clientID == query.clientID)
                    .first() else {
                    return redirectWithError(
                        to: query.redirectURI,
                        error: .unauthorizedClient,
                        description: "Invalid client_id",
                        state: query.state
                    )
                }

                // Validate redirect_uri
                guard client.redirectURIs.contains(query.redirectURI) else {
                    // Cannot redirect to invalid URI - show error page
                    throw Abort(.badRequest, reason: "Invalid redirect_uri")
                }

                // Validate PKCE if provided
                if let codeChallenge = query.codeChallenge {
                    let challengeMethod = query.codeChallengeMethod ?? "plain"
                    guard ["plain", "S256"].contains(challengeMethod) else {
                        return redirectWithError(
                            to: query.redirectURI,
                            error: .invalidRequest,
                            description: "Invalid code_challenge_method",
                            state: query.state
                        )
                    }
                    // Store for later verification
                    req.session.data["oauth_code_challenge"] = codeChallenge
                    req.session.data["oauth_code_challenge_method"] = challengeMethod
                }

                // let allScopes = ["profile", "email", "phone", "student_id", "developer"]
                // Internal developer API: accept any requested scopes without validation
                let requestedScopes = (query.scope ?? "profile student_id").split(separator: " ").map(String.init)

                // Store authorization request in session for consent screen
                req.session.data["oauth_client_id"] = query.clientID
                req.session.data["oauth_redirect_uri"] = query.redirectURI
                req.session.data["oauth_scope"] = requestedScopes.joined(separator: " ")
                req.session.data["oauth_state"] = query.state

                struct ConsentContext: Content {
                    let appName: String
                    let appDescription: String
                    let appLogoURL: String?
                    let userName: String
                    let userLoginID: String
                    let scopes: [String]
                }

                let context = ConsentContext(
                    appName: client.appName,
                    appDescription: client.appDescription,
                    appLogoURL: client.logoURL,
                    userName: user.userName,
                    userLoginID: user.userLoginID,
                    scopes: requestedScopes
                )

                return try await req.view.render("OAuth/consent", context).encodeResponse(for: req)
            } catch is DecodingError {
                throw Abort(.badRequest, reason: "Missing or invalid parameters")
            } catch {
                throw error
            }
        }
        
        // OAuth token and userinfo endpoints (no session auth required)
        routes.group("oauth") { oauthRoutes in
            // Token endpoint (no auth required - clients authenticate via credentials)
            oauthRoutes.post("token") { req async throws -> OAuthTokenResponse in
                struct TokenRequest: Content {
                    let grantType: String
                    let code: String?
                    let redirectURI: String?
                    let clientID: String
                    let clientSecret: String?
                    let refreshToken: String?
                    let scope: String?
                    let codeVerifier: String?

                    enum CodingKeys: String, CodingKey {
                        case grantType = "grant_type"
                        case code
                        case redirectURI = "redirect_uri"
                        case clientID = "client_id"
                        case clientSecret = "client_secret"
                        case refreshToken = "refresh_token"
                        case scope
                        case codeVerifier = "code_verifier"
                    }
                }

                do {
                    let request = try req.content.decode(TokenRequest.self)

                    guard let client = try await OAuthClient.query(on: req.db)
                        .filter(\.$clientID == request.clientID)
                        .first() else {
                        throw OAuth2ErrorResponse(error: .invalidClient, description: "Invalid client_id")
                    }

                    // Verify client secret for confidential clients
                    if client.isConfidential {
                        guard let clientSecret = request.clientSecret, clientSecret == client.clientSecret else {
                            throw OAuth2ErrorResponse(error: .invalidClient, description: "Invalid client_secret")
                        }
                    }

                    let clientID = try client.requireID()
                    var token: OAuthToken?

                    if request.grantType == "authorization_code" {
                        guard let code = request.code,
                              let redirectURI = request.redirectURI else {
                            throw OAuth2ErrorResponse(error: .invalidRequest, description: "Missing required parameters")
                        }

                        guard let authCode = try await OAuthAuthorizationCode.query(on: req.db)
                            .filter(\.$code == code)
                            .filter(\.$client.$id == clientID)
                            .with(\.$user)
                            .first() else {
                            throw OAuth2ErrorResponse(error: .invalidGrant, description: "Invalid authorization code")
                        }

                        // Validate authorization code
                        guard !authCode.isExpired() else {
                            throw OAuth2ErrorResponse(error: .invalidGrant, description: "Authorization code expired")
                        }

                        guard !authCode.isUsed else {
                            // Code replay attack detected - revoke all tokens for this client/user
                            let attackedUserID = try authCode.user.requireID()
                            try await OAuthToken.query(on: req.db)
                                .filter(\.$client.$id == clientID)
                                .filter(\.$user.$id == attackedUserID)
                                .delete()
                            throw OAuth2ErrorResponse(error: .invalidGrant, description: "Authorization code already used")
                        }

                        guard authCode.redirectURI == redirectURI else {
                            throw OAuth2ErrorResponse(error: .invalidGrant, description: "Redirect URI mismatch")
                        }

                        // Verify PKCE if code challenge was used
                        if let codeChallenge = authCode.codeChallenge {
                            guard let codeVerifier = request.codeVerifier else {
                                throw OAuth2ErrorResponse(error: .invalidRequest, description: "Missing code_verifier")
                            }

                            let challengeMethod = authCode.codeChallengeMethod ?? "plain"
                            let computedChallenge: String

                            if challengeMethod == "S256" {
                                let hash = SHA256.hash(data: Data(codeVerifier.utf8))
                                computedChallenge = Data(hash).base64EncodedString()
                                    .replacingOccurrences(of: "+", with: "-")
                                    .replacingOccurrences(of: "/", with: "_")
                                    .replacingOccurrences(of: "=", with: "")
                            } else {
                                computedChallenge = codeVerifier
                            }

                            guard computedChallenge == codeChallenge else {
                                throw OAuth2ErrorResponse(error: .invalidGrant, description: "Invalid code_verifier")
                            }
                        }

                        // Generate access token
                        let accessToken = generateSecureSecret()
                        let refreshToken = generateSecureSecret()
                        let expiresAt = Date().addingTimeInterval(3600) // 1 hour

                        token = OAuthToken(
                            accessToken: accessToken,
                            refreshToken: refreshToken,
                            userID: try authCode.user.requireID(),
                            clientID: clientID,
                            scope: authCode.scope,
                            expiresAt: expiresAt
                        )

                        try await token!.create(on: req.db)

                        // Mark authorization code as used
                        authCode.isUsed = true
                        try await authCode.save(on: req.db)

                        // Delete used authorization code for security
                        try await authCode.delete(on: req.db)

                    } else if request.grantType == "refresh_token" {
                        guard let refreshTokenStr = request.refreshToken else {
                            throw OAuth2ErrorResponse(error: .invalidRequest, description: "Missing refresh_token")
                        }

                        guard let existingToken = try await OAuthToken.query(on: req.db)
                            .filter(\.$refreshToken == refreshTokenStr)
                            .filter(\.$client.$id == clientID)
                            .with(\.$user)
                            .first() else {
                            throw OAuth2ErrorResponse(error: .invalidGrant, description: "Invalid refresh_token")
                        }

                        // Generate new access token
                        let newAccessToken = generateSecureSecret()
                        let expiresAt = Date().addingTimeInterval(3600)

                        existingToken.accessToken = newAccessToken
                        existingToken.expiresAt = expiresAt
                        try await existingToken.save(on: req.db)

                        token = existingToken

                    } else {
                        throw OAuth2ErrorResponse(error: .unsupportedGrantType)
                    }

                    guard let token = token else {
                        throw OAuth2ErrorResponse(error: .serverError, description: "Failed to generate token")
                    }

                    return OAuthTokenResponse(from: token)
                } catch {
                    throw error
                }
            }

            // User info endpoint (requires valid access token)
            oauthRoutes.get("userinfo") { req async throws -> UserInfoResponse in
                guard let authorizationHeader = req.headers.first(name: "Authorization") else {
                    throw OAuth2ErrorResponse(error: .invalidRequest, description: "Missing authorization header")
                }

                let parts = authorizationHeader.split(separator: " ")
                guard parts.count == 2, parts[0] == "Bearer" else {
                    throw OAuth2ErrorResponse(error: .invalidRequest, description: "Invalid authorization header format")
                }

                let accessToken = String(parts[1])

                guard let token = try await OAuthToken.query(on: req.db)
                    .filter(\.$accessToken == accessToken)
                    .with(\.$user)
                    .first() else {
                    throw OAuth2ErrorResponse(error: .invalidGrant, description: "Invalid access token")
                }

                guard !token.isExpired() else {
                    throw OAuth2ErrorResponse(error: .invalidGrant, description: "Access token expired")
                }

                // Return user info based on granted scopes
                return UserInfoResponse(from: token.user, scopes: token.scope)
            }
        }
    }
}

// MARK: - Helper Functions
private func generateSecureSecret() -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    return String((0..<32).map { _ in characters.randomElement()! })
}

private func redirectWithError(
    to redirectURI: String,
    error: OAuth2Error,
    description: String? = nil,
    state: String?
) -> Response {
    var components = URLComponents(string: redirectURI)!
    var queryItems = components.queryItems ?? []
    
    queryItems.append(URLQueryItem(name: "error", value: error.rawValue))
    if let description = description {
        queryItems.append(URLQueryItem(name: "error_description", value: description))
    }
    if let state = state {
        queryItems.append(URLQueryItem(name: "state", value: state))
    }
    
    components.queryItems = queryItems
    
    let response = Response(status: .seeOther)
    response.headers.replaceOrAdd(name: .location, value: components.string ?? redirectURI)
    return response
}

// MARK: - Response DTOs
struct UserInfoResponse: Content {
    let id: UUID
    let userLoginID: String?
    let userName: String?
    let userEmail: String?
    let userPhone: String?
    let userStudentIDList: [String]?
    let userDevVerifyDate: Date?

    init(from user: User, scopes: String) {
        let scopeList = scopes.split(separator: " ").map(String.init)
        
        self.id = user.id ?? UUID()
        
        // Only include fields if the corresponding scope is granted
        if scopeList.contains("profile") {
            self.userLoginID = user.userLoginID
            self.userName = user.userName
        } else {
            self.userLoginID = nil
            self.userName = nil
        }
        
        if scopeList.contains("email") {
            self.userEmail = user.userEmail
        } else {
            self.userEmail = nil
        }
        
        if scopeList.contains("phone") {
            self.userPhone = user.userPhone
        } else {
            self.userPhone = nil
        }
        
        if scopeList.contains("student_id") {
            self.userStudentIDList = user.userStudentIDList
        } else {
            self.userStudentIDList = nil
        }
        
        if scopeList.contains("developer") {
            self.userDevVerifyDate = user.userDevVerifyDate
        } else {
            self.userDevVerifyDate = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userLoginID = "login_id"
        case userName = "name"
        case userEmail = "email"
        case userPhone = "phone"
        case userStudentIDList = "student_id_list"
        case userDevVerifyDate = "dev_verify_date"
    }
}
