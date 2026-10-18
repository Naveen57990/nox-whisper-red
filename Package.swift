// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RubricLocal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RubricLocal", targets: ["RubricLocal"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "RubricLocal",
            dependencies: [],
            path: "Sources/RubricLocal",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Vision"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
