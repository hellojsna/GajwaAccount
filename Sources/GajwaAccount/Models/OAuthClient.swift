//
//  OAuthClient.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2025 Js Na. All rights reserved.
//

import Vapor
import Fluent

final class OAuthClient: Model, @unchecked Sendable {
    static let schema = "oauth_clients"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "client_id")
    var clientID: String

    @Field(key: "client_secret")
    var clientSecret: String

    @Field(key: "app_name")
    var appName: String

    @Field(key: "app_description")
    var appDescription: String

    @Field(key: "redirect_uris")
    var redirectURIs: [String]

    @OptionalField(key: "homepage_url")
    var homepageURL: String?

    @OptionalField(key: "logo_url")
    var logoURL: String?

    @Field(key: "is_confidential")
    var isConfidential: Bool

    @Parent(key: "developer_id")
    var developer: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        clientID: String,
        clientSecret: String,
        appName: String,
        appDescription: String,
        redirectURIs: [String],
        homepageURL: String? = nil,
        logoURL: String? = nil,
        isConfidential: Bool = true,
        developerID: UUID
    ) {
        self.id = id
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.appName = appName
        self.appDescription = appDescription
        self.redirectURIs = redirectURIs
        self.homepageURL = homepageURL
        self.logoURL = logoURL
        self.isConfidential = isConfidential
        self.$developer.id = developerID
    }
}

// MARK: - DTO for API responses
struct OAuthClientResponse: Content {
    let id: UUID
    let clientID: String
    let appName: String
    let appDescription: String
    let redirectURIs: [String]
    let homepageURL: String?
    let logoURL: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(from client: OAuthClient) throws {
        self.id = try client.requireID()
        self.clientID = client.clientID
        self.appName = client.appName
        self.appDescription = client.appDescription
        self.redirectURIs = client.redirectURIs
        self.homepageURL = client.homepageURL
        self.logoURL = client.logoURL
        self.createdAt = client.createdAt
        self.updatedAt = client.updatedAt
    }
}

struct OAuthClientDetailResponse: Content {
    let id: UUID
    let clientID: String
    let clientSecret: String
    let appName: String
    let appDescription: String
    let redirectURIs: [String]
    let homepageURL: String?
    let logoURL: String?
    let isConfidential: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(from client: OAuthClient) throws {
        self.id = try client.requireID()
        self.clientID = client.clientID
        self.clientSecret = client.clientSecret
        self.appName = client.appName
        self.appDescription = client.appDescription
        self.redirectURIs = client.redirectURIs
        self.homepageURL = client.homepageURL
        self.logoURL = client.logoURL
        self.isConfidential = client.isConfidential
        self.createdAt = client.createdAt
        self.updatedAt = client.updatedAt
    }
}
