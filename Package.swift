// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "zapret",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "zapret", targets: ["zapret"])
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "zapret",
            dependencies: ["SDWebImageSwiftUI"],
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)