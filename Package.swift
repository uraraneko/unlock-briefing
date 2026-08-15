// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnlockBriefing",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "UnlockBriefingCore", targets: ["UnlockBriefingCore"]),
        .executable(name: "UnlockBriefing", targets: ["UnlockBriefingApp"]),
    ],
    targets: [
        .target(
            name: "UnlockBriefingCore",
            path: "Sources/UnlockBriefingCore"
        ),
        .executableTarget(
            name: "UnlockBriefingApp",
            dependencies: ["UnlockBriefingCore"],
            path: "Sources/UnlockBriefingApp"
        ),
        .testTarget(
            name: "UnlockBriefingCoreTests",
            dependencies: ["UnlockBriefingCore"],
            path: "Tests/UnlockBriefingCoreTests"
        ),
    ]
)
