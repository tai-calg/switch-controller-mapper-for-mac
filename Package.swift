// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "switch-controller-mapper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "switch-controller-mapper",
            targets: ["SwitchControllerMapper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SwitchControllerMapper"
        )
    ]
)
