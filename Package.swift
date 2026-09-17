// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicState",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MicState",
            path: "Sources/MicState",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
