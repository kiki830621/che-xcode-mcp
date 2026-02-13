// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheXcodeMCP",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "CheXcodeMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/CheXcodeMCP"
        ),
        .testTarget(
            name: "CheXcodeMCPTests",
            dependencies: ["CheXcodeMCP"],
            path: "Tests/CheXcodeMCPTests"
        )
    ]
)
