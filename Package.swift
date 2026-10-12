// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chuckaway",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Chuckaway", targets: ["Chuckaway"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Chuckaway",
            dependencies: [],
            path: "Sources/Chuckaway"
        )
    ]
)
