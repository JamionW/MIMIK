// swift-tools-version:5.9
import PackageDescription

// Phrase data, time buckets, gendered forms, clip paths, search and voice choice: the logic the
// iOS app and widget share with the web app (app/index.html). Foundation only, so the tests run
// on Linux as well as macOS.
let package = Package(
    name: "MimikCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "MimikCore", targets: ["MimikCore"])],
    targets: [
        .target(name: "MimikCore"),
        .testTarget(name: "MimikCoreTests", dependencies: ["MimikCore"]),
    ]
)
