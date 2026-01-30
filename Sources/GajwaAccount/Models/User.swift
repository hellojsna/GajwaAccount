//
//  User.swift
//  GajwaAccount
//
//  Created by Js Na on 2025/12/26.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Vapor
import Fluent

final class User: Model, ModelSessionAuthenticatable, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user_login_id")
    var userLoginID: String
    
    @Field(key: "user_login_password")
    var userLoginPassword: String
    
    @Field(key: "user_name")
    var userName: String
    
    @Field(key: "user_student_id_list")
    var userStudentIDList: [String]

    @Field(key: "user_email")
    var userEmail: String

    @OptionalField(key: "user_phone")
    var userPhone: String?

    @OptionalField(key: "user_discord_token")
    var userDiscordToken: String?
    
    init() { }

    init(id: UUID? = nil, userLoginID: String, userLoginPassword: String, userName: String, userStudentIDList: [String], userEmail: String, userPhone: String? = nil, userDiscordToken: String? = nil) {
        self.id = id
        self.userLoginID = userLoginID
        self.userLoginPassword = userLoginPassword
        self.userName = userName
        self.userStudentIDList = userStudentIDList
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userDiscordToken = userDiscordToken
    }
}
