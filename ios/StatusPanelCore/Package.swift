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
    ],
    targets: [
        .target(
            name: "StatusPanelCore",
            dependencies: [
                .product(name: "Diligence", package: "diligence"),
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
