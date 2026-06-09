// swift-tools-version: 5.10

import PackageDescription

extension Target.Dependency {
    // Internal Targets
    static let twinkle: Self = "Twinkle"

    // External Dependencies
    static let swiftDependencies: Self = .product(name: "Dependencies", package: "swift-dependencies")
    static let swiftDependenciesMacros: Self = .product(name: "DependenciesMacros", package: "swift-dependencies")
    static let swiftDependenciesTestSupport: Self = .product(name: "DependenciesTestSupport", package: "swift-dependencies")
    static let identifiedCollections: Self = .product(name: "IdentifiedCollections", package: "swift-identified-collections")
    static let swiftSharing: Self = .product(name: "Sharing", package: "swift-sharing")
}

let package = Package(
    name: "Twinkle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Twinkle", targets: ["Twinkle"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.1"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.4")
    ],
    targets: [
        .target(
            name: "Twinkle",
            dependencies: [
                .swiftDependencies,
                .swiftDependenciesMacros,
                .identifiedCollections,
                .swiftSharing
            ]
        ),
        .testTarget(
            name: "TwinkleTests",
            dependencies: [
                .twinkle,
                .swiftDependenciesTestSupport
            ]
        )
    ]
)
