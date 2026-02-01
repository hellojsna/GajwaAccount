//
//  DiscordOAuthController.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2026 Js Na. All rights reserved.
//

import Fluent
import Vapor

struct DevVerifyStatus: Content {
    let isVerified: Bool
    let needsReVerify: Bool
    let verifyDate: Date?
}

struct DiscordOAuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let discord = routes.grouped("discord")
        let protected = discord.grouped(User.asyncSessionAuthenticator()).grouped(User.guardMiddleware())
        
        // Discord OAuth 시작
        protected.get("authorize") { req async throws -> Response in
            guard let clientID = Environment.get("DISCORD_CLIENT_ID"),
                  let redirectURI = Environment.get("DISCORD_REDIRECT_URI") else {
                throw Abort(.internalServerError, reason: "Discord OAuth credentials not configured")
            }
            
            let state = [UInt8].random(count: 32).base64String()
            req.session.data["discord_oauth_state"] = state
            
            let authURL = "https://discord.com/api/oauth2/authorize?" + [
                "client_id=\(clientID)",
                "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "response_type=code",
                "scope=identify guilds",
                "state=\(state)"
            ].joined(separator: "&")
            
            return req.redirect(to: authURL)
        }
        
        // Discord OAuth 콜백
        protected.get("callback") { req async throws -> Response in
            struct DiscordCallbackQuery: Content {
                let code: String
                let state: String
            }
            
            let query = try req.query.decode(DiscordCallbackQuery.self)
            
            // State 검증
            guard let savedState = req.session.data["discord_oauth_state"],
                  savedState == query.state else {
                throw Abort(.badRequest, reason: "Invalid state parameter")
            }
            
            req.session.data["discord_oauth_state"] = nil
            
            guard let clientID = Environment.get("DISCORD_CLIENT_ID"),
                  let clientSecret = Environment.get("DISCORD_SECRET"),
                  let redirectURI = Environment.get("DISCORD_REDIRECT_URI"),
                  let guildID = Environment.get("DISCORD_GUILD_ID") else {
                throw Abort(.internalServerError, reason: "Discord OAuth credentials not configured")
            }
            
            // Access Token 요청
            struct TokenRequest: Content {
                let client_id: String
                let client_secret: String
                let grant_type: String
                let code: String
                let redirect_uri: String
            }
            
            struct TokenResponse: Content {
                let access_token: String
                let token_type: String
                let expires_in: Int
                let refresh_token: String
                let scope: String
            }
            
            let tokenResponse = try await req.client.post("https://discord.com/api/oauth2/token") { tokenReq in
                try tokenReq.content.encode(TokenRequest(
                    client_id: clientID,
                    client_secret: clientSecret,
                    grant_type: "authorization_code",
                    code: query.code,
                    redirect_uri: redirectURI
                ), as: .urlEncodedForm)
            }.content.decode(TokenResponse.self)
            
            // 사용자 길드 확인
            struct GuildInfo: Content {
                let id: String
            }
            
            let guilds = try await req.client.get("https://discord.com/api/users/@me/guilds") { guildReq in
                guildReq.headers.add(name: .authorization, value: "Bearer \(tokenResponse.access_token)")
            }.content.decode([GuildInfo].self)
            
            let isMember = guilds.contains { $0.id == guildID }
            
            if isMember {
                // 인증 성공: 날짜 저장
                let user = try req.auth.require(User.self)
                user.userDevVerifyDate = Date()
                try await user.save(on: req.db)
                
                return req.redirect(to: "/home?dev_verify_status=success")
            } else {
                // 인증 실패: 길드 미가입
                return req.redirect(to: "/home?dev_verify_status=not_member")
            }
        }
        
        // 인증 상태 확인 API
        protected.get("status") { req async throws -> DevVerifyStatus in
            let user = try req.auth.require(User.self)
            
            guard let verifyDate = user.userDevVerifyDate else {
                return DevVerifyStatus(isVerified: false, needsReVerify: false, verifyDate: nil)
            }
            
            let daysSinceVerify = Calendar.current.dateComponents([.day], from: verifyDate, to: Date()).day ?? 0
            let needsReVerify = daysSinceVerify > 365
            
            return DevVerifyStatus(
                isVerified: !needsReVerify,
                needsReVerify: needsReVerify,
                verifyDate: verifyDate
            )
        }
    }
}
