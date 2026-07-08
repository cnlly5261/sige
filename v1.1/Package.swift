// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sige",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Sige",
            path: "Sources/Sige",
            resources: [
                .process("../../Resources")
            ]
        )
    ]
)
