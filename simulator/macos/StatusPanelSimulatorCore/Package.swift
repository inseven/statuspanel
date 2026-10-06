// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "StatusPanelSimulatorCore",
    products: [
        .library(
            name: "StatusPanelSimulatorCore",
            targets: ["StatusPanelSimulatorCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/codelynx/DataStream.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "StatusPanelSimulatorCore",
            dependencies: [
                .product(name: "DataStream", package: "DataStream"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "StatusPanelSimulatorCoreTests",
            dependencies: ["StatusPanelSimulatorCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
