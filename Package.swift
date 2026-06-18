// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.bluetooth",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.bluetooth",
            targets: [
                "com.awareframework.ios.sensor.bluetooth"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.bluetooth",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.bluetooth"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.bluetoothTests",
            dependencies: ["com.awareframework.ios.core", "com.awareframework.ios.sensor.bluetooth"]
        )
    ],
    swiftLanguageModes: [.v5]
)
