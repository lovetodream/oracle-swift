// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "oracle-nio",
    products: [
        .library(
            name: "OracleNIO",
            targets: ["OracleNIO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "ODPIC"),
        .target(
            name: "OracleNIO",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                .target(name: "ODPIC"),
            ]),
        .testTarget(
            name: "OracleNIOTests",
            dependencies: ["OracleNIO"]),
    ]
)
