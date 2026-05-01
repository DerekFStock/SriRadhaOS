// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SriRadhaOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ResourceObserverCore",
            targets: ["ResourceObserverCore"]
        ),
        .executable(
            name: "ResourceObserverCLI",
            targets: ["ResourceObserverCLI"]
        )
    ],
    targets: [
        .target(
            name: "ResourceObserverCore"
        ),
        .executableTarget(
            name: "ResourceObserverCLI",
            dependencies: ["ResourceObserverCore"]
        ),
        .testTarget(
            name: "ResourceObserverCoreTests",
            dependencies: ["ResourceObserverCore"]
        )
    ]
)
