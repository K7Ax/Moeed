// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MoeedKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoeedCore", targets: ["MoeedCore"]),
        .library(name: "MoeedEngine", targets: ["MoeedEngine"]),
        .library(name: "MoeedUI", targets: ["MoeedUI"]),
        .executable(name: "Snapshots", targets: ["Snapshots"]),
        .executable(name: "moeed", targets: ["MoeedTool"]),
    ],
    targets: [
        // Pure Swift: lesson model, timing, sample content, and the tutor's language
        // (regions, TDP-L parser and validator, compiler, prompt). No Apple frameworks.
        .target(name: "MoeedCore"),
        // Reads PDFs on the device (PDFKit), draws the Set-of-Marks image, and talks to the model.
        .target(name: "MoeedEngine", dependencies: ["MoeedCore"]),
        // SwiftUI design system + screens.
        // The bundled faces (IBM Plex Sans Arabic, Brygada 1918) and the logo ship as resources.
        .target(name: "MoeedUI", dependencies: ["MoeedCore"], resources: [.copy("Resources/Fonts"), .copy("Resources/Brand")]),
        // Renders every screen to PNG (used by CI so the design is visible without a Mac),
        // and writes the sample slide as a PDF for the engine to read.
        .executableTarget(name: "Snapshots", dependencies: ["MoeedCore", "MoeedUI"]),
        // The engine on the command line: ground a PDF page, compile a script, or ask Claude.
        .executableTarget(name: "MoeedTool", dependencies: ["MoeedEngine"]),
        .testTarget(name: "MoeedCoreTests", dependencies: ["MoeedCore"]),
        .testTarget(name: "MoeedEngineTests", dependencies: ["MoeedEngine"]),
    ]
)
