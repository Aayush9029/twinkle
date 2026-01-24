// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwinkleExample",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TwinkleExample", targets: ["TwinkleExample"])
    ],
    dependencies: [
        .package(name: "twinkle", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "TwinkleExample",
            dependencies: [
                .product(name: "Twinkle", package: "twinkle")
            ],
            path: "Sources/TwinkleExample"
        )
    ]
)
