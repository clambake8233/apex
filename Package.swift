// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Apex",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project contains exactly one library product = the main app.
        .library(
            name: "Apex",
            targets: ["Apex"]
        ),
    ],
    targets: [
        .target(
            name: "Apex"
        ),
        .testTarget(
            name: "ApexTests",
            dependencies: ["Apex"]
        ),
    ]
)
