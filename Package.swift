// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchTeleprompter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchTeleprompter",
            path: "Sources/NotchTeleprompter",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
