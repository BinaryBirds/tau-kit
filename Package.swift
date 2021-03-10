// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "tau-kit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "TauKit", targets: ["TauKit"]),
        .library(name: "XCTTauKit", targets: ["XCTTauKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.26.0"),
    ],
    targets: [
        .target(name: "TauKit", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "XCTTauKit", dependencies: [
            .target(name: "TauKit"),
        ]),
        .testTarget(name: "TauKitTests", dependencies: [
            .target(name: "XCTTauKit"),
        ], exclude: [
            "Templates/test.html",
            "Templates/SubTemplates/test.html",
        ])
    ]
)
