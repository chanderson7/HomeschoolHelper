// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HomeSchoolHelper",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "HomeschoolCore", targets: ["HomeschoolCore"])],
    targets: [
        .target(name: "HomeschoolCore"),
        .target(
            name: "HomeschoolPresentation",
            dependencies: ["HomeschoolCore"],
            path: "iOS/HomeSchoolHelper",
            exclude: ["HomeSchoolHelperApp.swift", "HomeTabView.swift"],
            sources: ["HomeschoolStore.swift"]
        ),
        .testTarget(name: "HomeschoolCoreTests", dependencies: ["HomeschoolCore"]),
        .testTarget(name: "HomeschoolStoreTests", dependencies: ["HomeschoolCore", "HomeschoolPresentation"])
    ]
)
