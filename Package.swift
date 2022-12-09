// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "oracle-nio",
    products: [
        .library(
            name: "OracleNIO",
            targets: ["OracleNIO"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OracleNIO",
            dependencies: []),
        .testTarget(
            name: "OracleNIOTests",
            dependencies: ["OracleNIO"]),
    ]
)
