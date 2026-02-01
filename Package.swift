// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OlympicSkiJump",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OlympicSkiJump", targets: ["OlympicSkiJump"])
    ],
    targets: [
        .executableTarget(
            name: "OlympicSkiJump",
            path: "Sources"
        )
    ]
)
