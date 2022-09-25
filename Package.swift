// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KindKitInAppPurchase",
    platforms: [
        .iOS(.v11),
        .macOS(.v11)
    ],
    products: [
        .library(name: "KindKitInAppPurchase", type: .static, targets: [ "KindKitInAppPurchase" ])
    ],
    dependencies: [
        .package(
            name: "KindKit",
            url: "https://github.com/KindKit/KindKit.git",
            .upToNextMajor(from: "0.2.7")
        ),
        .package(
            name: "TPInAppReceipt",
            url: "https://github.com/tikhop/TPInAppReceipt.git",
            .upToNextMajor(from: "3.0.0")
        )
    ],
    targets: [
        .target(
            name: "KindKitInAppPurchase",
            dependencies: [
                .product(name: "KindKit", package: "KindKit"),
                .product(name: "TPInAppReceipt", package: "TPInAppReceipt")
            ],
            path: "Sources/InAppPurchase"
        )
    ]
)
