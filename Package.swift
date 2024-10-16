// swift-tools-version: 5.10.0

import PackageDescription

let package = Package(
    name: "FileBrowser",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "FileBrowser",
            targets: ["FileBrowser"]),
    ],
    targets: [
        .target(
            name: "FileBrowser"),
        .testTarget(
            name: "FileBrowserTests",
            dependencies: ["FileBrowser"]
        ),
    ]
)
