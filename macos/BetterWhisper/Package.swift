// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BetterWhisper",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BetterWhisper",
            path: ".",
            exclude: ["Package.swift", "Info.plist", "BetterWhisper.entitlements", "BetterWhisper.app", "BetterWhisper.xcodeproj"]
        )
    ]
)
