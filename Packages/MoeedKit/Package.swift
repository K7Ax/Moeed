// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MoeedKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoeedCore", targets: ["MoeedCore"]),
        .library(name: "MoeedUI", targets: ["MoeedUI"]),
        .executable(name: "Snapshots", targets: ["Snapshots"]),
    ],
    targets: [
        // Pure Swift: lesson model, timing, sample content. No UI.
        .target(name: "MoeedCore"),
        // SwiftUI design system + screens.
        // The bundled faces (IBM Plex Sans Arabic, Brygada 1918) ship as resources and register at first use.
        .target(name: "MoeedUI", dependencies: ["MoeedCore"], resources: [.copy("Resources/Fonts")]),
        // Renders every screen to PNG (used by CI so the design is visible without a Mac).
        .executableTarget(name: "Snapshots", dependencies: ["MoeedUI"]),
        .testTarget(name: "MoeedCoreTests", dependencies: ["MoeedCore"]),
    ]
)
