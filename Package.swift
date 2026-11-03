// swift-tools-version: 5.9
//  Autor: aagrandaz@gmail.com
//
import PackageDescription

let package = Package(
    name: "GeminiDesktop",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GeminiCore",
            targets: ["GeminiCore"]
        ),
        .library(
            name: "GeminiWebBridge",
            targets: ["GeminiWebBridge"]
        ),
        .library(
            name: "GeminiAppKit",
            targets: ["GeminiAppKit"]
        ),
        .library(
            name: "GeminiUI",
            targets: ["GeminiUI"]
        ),
        .executable(
            name: "GeminiDesktop",
            targets: ["GeminiDesktop"]
        )
    ],
    targets: [
        .target(
            name: "GeminiCore",
            path: "Sources/GeminiCore"
        ),
        .target(
            name: "GeminiWebBridge",
            dependencies: ["GeminiCore"],
            path: "Sources/GeminiWebBridge"
        ),
        .target(
            name: "GeminiAppKit",
            dependencies: ["GeminiCore", "GeminiWebBridge"],
            path: "Sources/GeminiAppKit"
        ),
        .target(
            name: "GeminiUI",
            dependencies: ["GeminiCore", "GeminiWebBridge", "GeminiAppKit"],
            path: "Sources/GeminiUI"
        ),
        .executableTarget(
            name: "GeminiDesktop",
            dependencies: [
                "GeminiCore",
                "GeminiWebBridge",
                "GeminiAppKit",
                "GeminiUI"
            ],
            path: "Sources/GeminiDesktop",
            exclude: [
                "ChatBar",
                "Utils",
                "Views",
                "WebKit",
                "Resources/Info.plist",
                "Resources/GeminiDesktop.entitlements"
            ],
            sources: [
                "App",
                "Coordinators"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "GeminiCoreTests",
            dependencies: [
                "GeminiCore",
                "GeminiWebBridge",
                "GeminiAppKit"
            ],
            path: "Tests/GeminiCoreTests"
        )
    ]
)
