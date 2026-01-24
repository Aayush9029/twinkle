// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwinkleE2ETests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "twinkle", path: "..")
    ],
    targets: [
        .testTarget(
            name: "TwinkleE2ETests",
            dependencies: [
                .product(name: "Twinkle", package: "twinkle")
            ],
            path: "Tests/TwinkleE2ETests",
            resources: [
                .copy("../../Fixtures")
            ]
        )
    ]
)
