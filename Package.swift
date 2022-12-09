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
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "OracleNIO",
            dependencies: []),
        .testTarget(
            name: "OracleNIOTests",
            dependencies: ["OracleNIO"]),
    ]
)
