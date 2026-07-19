// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WinList",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WinList", targets: ["WinList"])
    ],
    targets: [
        .executableTarget(
            name: "WinList",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "WinListTests",
            dependencies: ["WinList"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
