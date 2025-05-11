// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RKPurchaseKit",
    platforms: [
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "RKPurchaseKit",
            targets: ["RKPurchaseKit"]),
    ],
    targets: [
        .target(
            name: "RKPurchaseKit"),
    ]
)
