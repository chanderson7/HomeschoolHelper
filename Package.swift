// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HomeSchoolHelper",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "HomeschoolCore", targets: ["HomeschoolCore"]),
        .library(name: "HomeschoolAuth", targets: ["HomeschoolAuth"])
    ],
    dependencies: [.package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.2")],
    targets: [
        .target(name: "HomeschoolCore"),
        .target(name: "HomeschoolAuth", dependencies: [.product(name: "Supabase", package: "supabase-swift")]),
        .target(
            name: "HomeschoolPresentation",
            dependencies: ["HomeschoolCore"],
            path: "iOS/HomeSchoolHelper",
            exclude: ["HomeSchoolHelperApp.swift", "HomeTabView.swift", "OnboardingView.swift", "AuthRootView.swift", "LoginView.swift", "AccountView.swift", "SupabaseConfiguration.swift"],
            sources: ["HomeschoolStore.swift"]
        ),
        .testTarget(name: "HomeschoolCoreTests", dependencies: ["HomeschoolCore"]),
        .testTarget(name: "HomeschoolAuthTests", dependencies: ["HomeschoolAuth"]),
        .testTarget(name: "HomeschoolStoreTests", dependencies: ["HomeschoolCore", "HomeschoolPresentation"])
    ]
)
