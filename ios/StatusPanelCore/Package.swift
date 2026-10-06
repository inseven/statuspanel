// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "StatusPanelCore",
    products: [
        .library(
            name: "StatusPanelCore",
            targets: ["StatusPanelCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/inseven/diligence.git", from: "2.0.1"),
        .package(url: "https://github.com/jedisct1/swift-sodium.git", from: "0.11.0"),
    ],
    targets: [
        .target(
            name: "StatusPanelCore",
            dependencies: [
                .product(name: "Diligence", package: "diligence"),
                .product(name: "Sodium", package: "swift-sodium"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "StatusPanelCoreTests",
            dependencies: ["StatusPanelCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
