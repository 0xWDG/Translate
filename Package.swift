// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "translate",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "translate", targets: ["translate"])
    ],
    targets: [
        .executableTarget(
            name: "translate",
            linkerSettings: [.linkedFramework("Translation")]
        ),
        .testTarget(name: "translateTests", dependencies: ["translate"])
    ]
)
