//
//  routes.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/25.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Fluent
import Vapor

func routes(_ app: Application) throws {

    @Sendable func getAcademicYear() -> String {
        let month: Int = Calendar.current.component(.month, from: Date())
        let year: Int = Calendar.current.component(.year, from: Date())
        let academicYear: String = month >= 3 ? String(year) : String(year - 1)
        return academicYear
    }
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }
    
    app.get("auth") { req async throws -> Response in
        // 이미 로그인된 사용자는 /home으로 리다이렉트
        if req.auth.has(User.self) {
            return req.redirect(to: "/home")
        }
        
        // academicYear 기준: 3월
        let academicYear: String = getAcademicYear()
        return try await req.view.render("auth", [
            "academicYear": academicYear,
            "title": "Gajwa Account"
        ]).encodeResponse(for: req)
    }
    
    let auth = app.grouped(User.redirectMiddleware(path: "/auth"))
    auth.get("home") { req async throws -> View in
        let user = try req.auth.require(User.self)
        req.logger.info("Home - User authenticated: \(user.userLoginID)")
        req.logger.info("Home - Session ID: \(req.session.id?.string ?? "no session")")
        struct userStudentIDMap: Content {
            let year: String
            let studentID: String
        }
        struct PageContext: Content {
            let user: User
            let userStudentIDMap: [userStudentIDMap?]
            let academicYear: String
            let isDevVerified: Bool
            let devVerifyStatus: String
            let devVerifyInfo: String
        }
        let mappedUserStudentIDList = user.userStudentIDList.map { code -> userStudentIDMap? in
            let parts = code.split(separator: "-")
            guard parts.count == 2 else { return nil }
            return userStudentIDMap(year: String(parts[0]), studentID: String(parts[1]))
        }
        // academicYear 기준: 3월
        let academicYear: String = getAcademicYear()
        
        // 개발자 인증 상태 확인 (365일 이내)
        var isDevVerified = false
        var devVerifyStatus = "미인증"
        var devVerifyInfo = "OAuth 앱 관리를 위해 개발자 인증이 필요합니다."
        
        if let verifyDate = user.userDevVerifyDate {
            let daysSinceVerify = Calendar.current.dateComponents([.day], from: verifyDate, to: Date()).day ?? 0
            if daysSinceVerify <= 365 {
                isDevVerified = true
                devVerifyStatus = "인증됨"
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ko_KR")
                formatter.dateFormat = "yyyy년 M월 d일"
                devVerifyInfo = "마지막 인증: " + formatter.string(from: verifyDate)
            } else {
                devVerifyStatus = "재인증 필요"
                devVerifyInfo = "인증 후 365일이 경과하여 재인증이 필요합니다."
            }
        }
        
        return try await req.view.render("home", PageContext(
            user: user,
            userStudentIDMap: mappedUserStudentIDList,
            academicYear: academicYear,
            isDevVerified: isDevVerified,
            devVerifyStatus: devVerifyStatus,
            devVerifyInfo: devVerifyInfo
        ))
    }

    auth.get("passkeys") { req async throws -> View in
        let user = try req.auth.require(User.self)
        struct PageContext: Content {
            let user: User
            let title: String
            let backLink: String
        }
        return try await req.view.render("passkey", PageContext(
            user: user,
            title: "패스키 관리",
            backLink: "/home"
        ))
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    try app.register(collection: UserAPIController())
    try app.register(collection: OAuthAPIController())
    try app.register(collection: DiscordOAuthController())
}
