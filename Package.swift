// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIPower",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AIPower", targets: ["AIPower"]),
        .executable(name: "AIPowerCoreSelfTest", targets: ["AIPowerCoreSelfTest"]),
        .library(name: "AIPowerCore", targets: ["AIPowerCore"])
    ],
    targets: [
        .target(
            name: "AIPowerCore"
        ),
        .executableTarget(
            name: "AIPower",
            dependencies: ["AIPowerCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AIPowerCoreSelfTest",
            dependencies: ["AIPowerCore"],
            path: "SelfTests/AIPowerCoreSelfTest"
        )
    ],
    swiftLanguageVersions: [.v5]
)
