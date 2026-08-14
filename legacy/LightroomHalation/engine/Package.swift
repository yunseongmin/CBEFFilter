// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LightroomHalationEngine",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "halation-engine", targets: ["halation-engine"])],
    targets: [.executableTarget(name: "halation-engine", path: "Sources/halation-engine")]
)
