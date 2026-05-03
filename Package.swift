// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopVault",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ShopVault",
            targets: ["ShopVault"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ShopVault",
            dependencies: [],
            path: "ShopVault",
            exclude: [
                "App",
                "Theme",
                "Views",
                "Info.plist"
            ],
            resources: [
                .copy("Database/schema.sql")
            ]
        ),
        .testTarget(
            name: "ShopVaultTests",
            dependencies: ["ShopVault"],
            path: "ShopVaultTests"
        )
    ]
)
