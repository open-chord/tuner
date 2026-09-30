// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TunerCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Tuner", targets: ["Tuner"]),
    ],
    targets: [
        .target(
            name: "Tuner",
            path: "Tuner",
            exclude: ["App", "UI", "Audio/TunerEngine.swift", "Resources"],
            sources: ["Audio/PitchDetector.swift", "Domain/GuitarString.swift"]
        ),
        .testTarget(
            name: "TunerTests",
            dependencies: ["Tuner"],
            path: "TunerTests"
        ),
    ]
)
