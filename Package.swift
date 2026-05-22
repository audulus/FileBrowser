// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FileBrowser",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FileBrowser",
            targets: ["FileBrowser"]),
    ],
    targets: [
        .target(
            name: "FileBrowser",
            resources: [.process("Media.xcassets")]),
        .testTarget(
            name: "FileBrowserTests",
            dependencies: ["FileBrowser"]
        ),
    ]
)
