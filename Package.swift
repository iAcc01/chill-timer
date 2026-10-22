// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChillTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ChillTimer",
            path: "Sources/ChillTimer"
        )
    ]
)
