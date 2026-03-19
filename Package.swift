// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudienceLabSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "AudienceLabSDK",
            type: .static,
            targets: ["AudienceLabSDK"]
        )
    ],
    targets: [
        .target(
            name: "AudienceLabSDK",
            path: "Sources/AudienceLabSDK"
        )
    ]
)
