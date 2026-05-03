// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopVaultMac",
    platforms: [
        .macOS("14.4")
    ],
    targets: [
        .executableTarget(
            name: "ShopVaultMac",
            path: "Sources/ShopVaultMac"
        )
    ]
)
