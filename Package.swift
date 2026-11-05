// swift-tools-version:5.9
// Builds only the simulation engine, so it can be tested with `swift test`
// on a Mac or Linux without Xcode. The app itself is built from project.yml.
import PackageDescription

let package = Package(
    name: "BeadLabEngine",
    targets: [
        .target(name: "Engine", path: "BeadLab/Engine"),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], path: "Tests/EngineTests"),
    ]
)
