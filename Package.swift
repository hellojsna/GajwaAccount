// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GajwaAccount",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/swift-server/swift-webauthn.git", from: "1.0.0-beta.1"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor-community/vapor-queues-fluent-driver.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "GajwaAccount",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "WebAuthn", package: "swift-webauthn"),
                .product(name: "Queues", package: "queues"),
                .product(name: "QueuesFluentDriver", package: "vapor-queues-fluent-driver")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "GajwaAccountTests",
            dependencies: [
                .target(name: "GajwaAccount"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
