// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "dialog-jumper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "dialog-jumper", targets: ["DialogJumper"])
    ],
    targets: [
        .executableTarget(
            name: "DialogJumper",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "DialogJumperTests",
            dependencies: ["DialogJumper"]
        )
    ]
)
