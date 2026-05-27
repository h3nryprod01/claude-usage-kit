// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClaudeUsageKit", targets: ["ClaudeUsageKit"]),
        .executable(name: "claude-usage", targets: ["claude-usage"]),
    ],
    targets: [
        .target(name: "ClaudeUsageKit"),
        .executableTarget(name: "claude-usage", dependencies: ["ClaudeUsageKit"]),
        .testTarget(name: "ClaudeUsageKitTests", dependencies: ["ClaudeUsageKit"]),
    ]
)
