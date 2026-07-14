// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UniversalPassportReader",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "UniversalPassportReader",
            type: .dynamic,
            targets: ["UniversalPassportReader"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UniversalPassportReader",
            dependencies: [],
            path: "Sources/UniversalPassportReader"
        ),
        .testTarget(
            name: "UniversalPassportReaderTests",
            dependencies: ["UniversalPassportReader"],
            path: "Tests/UniversalPassportReaderTests"
        )
    ]
)
