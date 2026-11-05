// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LearnKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LearnKit", targets: ["LearnKit"]),
    ],
    targets: [
        .target(name: "LearnKit"),
        .testTarget(name: "LearnKitTests", dependencies: ["LearnKit"],
                    resources: [.copy("Fixtures/progress-v1.json")]),
    ],
    swiftLanguageModes: [.v6]
)
