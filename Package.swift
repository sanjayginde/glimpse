// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimpse",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(name: "Glimpse", path: "Sources")
    ]
)
