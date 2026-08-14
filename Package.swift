// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GlaceCoreVerification",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(
            url: "https://github.com/21-DOT-DEV/swift-secp256k1.git",
            exact: "0.23.2"
        )
    ],
    targets: [
        .target(
            name: "GlaceCore",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1")
            ],
            path: "Glace",
            exclude: [
                "Features",
                "GlaceApp.swift",
                "Resources"
            ],
            sources: [
                "Bitcoin",
                "Security"
            ]
        ),
        .testTarget(
            name: "GlaceCoreTests",
            dependencies: ["GlaceCore"],
            path: "GlaceTests"
        )
    ]
)
