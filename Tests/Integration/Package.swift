// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "FallbackIntegrationTests",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
    ],
    targets: [
        .testTarget(
            name: "FallbackIntegrationTests",
            dependencies: [
                .product(name: "Fallback", package: "swift-fallback-macro"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Tests"
        ),
    ]
)
