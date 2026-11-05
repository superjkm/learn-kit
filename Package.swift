// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LearnKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LearnKit", targets: ["LearnKit"]),
        .library(name: "LearnKitUI", targets: ["LearnKitUI"]),
    ],
    targets: [
        .target(name: "LearnKit"),
        .target(name: "LearnKitUI", dependencies: ["LearnKit"],
                resources: [.process("Resources/Sounds")]),
        .testTarget(name: "LearnKitTests", dependencies: ["LearnKit", "LearnKitUI"],
                    resources: [.copy("Fixtures/progress-v1.json")]),
    ],
    swiftLanguageModes: [.v6]
)
