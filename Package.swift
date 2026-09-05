// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PurchaseKit",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .tvOS(.v26),
        .macOS(.v26),
        .macCatalyst(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "RKPurchaseKit",
            type: .static,
            targets: ["RKPurchaseKit"]
        ),
    ],
    targets: [
        .target(
            name: "RKPurchaseKit",
            path: "Sources/PurchaseKit",
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        .testTarget(
            name: "RKPurchaseKitTests",
            dependencies: ["RKPurchaseKit"],
            path: "Tests/RKPurchaseKitTests"
        )
    ]
)
