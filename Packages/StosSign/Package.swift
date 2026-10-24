// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StosSign",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "StosSign",
            targets: ["StosSign"]
        ),
        .library(
            name: "StosSign_API",
            targets: ["StosSign_API"]
        ),
        .library(
            name: "StosSign_Certificate",
            targets: ["StosSign_Certificate"]
        ),
        .library(
            name: "StosSign_Auth",
            targets: ["StosSign_Auth"]
        ),
        .library(
            name: "StosSign_CodeSign",
            targets: ["StosSign_CodeSign"]
        ),
        .library(
            name: "StosSign_Common",
            targets: ["StosSign_Common"]
        ),
        .library(
            name: "StosSign_Anisette",
            targets: ["StosSign_Anisette"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/adam-fowler/swift-srp.git", revision: "ce202c48f8ca68f44b71732f945eb8221d6fe135"),
        .package(url: "https://github.com/krzyzanowskim/OpenSSL", from: "3.3.3001"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "StosSign",
            dependencies: [
                "StosSign_Certificate",
                "StosSign_Auth",
                "StosSign_API",
                "StosSign_CodeSign",
                "StosSign_Common"
            ]
        ),
        .target(
            name: "StosSign_Certificate",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SRP", package: "swift-srp"),
                .product(name: "X509", package: "swift-certificates"),
                .target(
                    name: "StosOpenSSL",
                    condition: .when(platforms: [.iOS, .macOS, .tvOS, .watchOS, .macCatalyst, .visionOS])
                ),
                "StosSign_Common",
                "StosSign_API"
            ]
        ),
        .target(
            name: "StosSign_API",
            dependencies: [
                "StosSign_Common"
            ]
        ),
        .target(
            name: "StosSign_Auth",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "SRP", package: "swift-srp"),
                .product(name: "X509", package: "swift-certificates"),
                "StosSign_API",
                "StosSign_Common"
            ]
        ),
        .target(
            name: "StosSign_Anisette",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "SRP", package: "swift-srp"),
                .product(name: "X509", package: "swift-certificates"),
                "StosSign_API",
                "StosSign_Common"
            ]
        ),
        .target(
            name: "StosOpenSSL",
            dependencies: [
                .product(name: "OpenSSL", package: "OpenSSL"),
            ],
            path: "Sources/Dependencies/Modules/OpenSSL"
        ),
        .target(
            name: "StosSign_CodeSign",
           // path: "Sources/StosSign/StosSign_CodeSign"
        ),
        .target(
            name: "StosSign_Common",
        ),
    ],
)
