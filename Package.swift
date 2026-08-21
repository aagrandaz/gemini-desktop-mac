// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeminiDesktop",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "GeminiDesktop",
            targets: ["GeminiDesktop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GeminiDesktop",
            path: "Sources/GeminiDesktop",
            exclude: [
                "Resources/Info.plist",
                "Resources/GeminiDesktop.entitlements"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
