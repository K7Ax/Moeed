import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import MoeedCore
import MoeedUI

/// Renders every screen in `Gallery` to a PNG so the design can be reviewed without Xcode.
/// Usage: swift run Snapshots <output-directory>
///        swift run Snapshots <output-directory> --lesson <lesson.json>   (each step of an engine-written lesson)
@main
struct SnapshotTool {
    @MainActor
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let outDir = URL(fileURLWithPath: args.first ?? "snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        if let flag = args.firstIndex(of: "--lesson"), flag + 1 < args.count {
            let data = try Data(contentsOf: URL(fileURLWithPath: args[flag + 1]))
            let page = try JSONDecoder().decode(SlidePage.self, from: data)
            for entry in Gallery.lesson(page, prefix: "12-engine") { try render(entry, to: outDir) }
            return
        }

        for entry in Gallery.entries() { try render(entry, to: outDir) }

        // The sample slide as a PDF, for the engine step in CI to read like a real lecture.
        let pdf = outDir.appendingPathComponent("sample-slide.pdf")
        try SampleSlide.pdf().write(to: pdf)
        print("wrote \(pdf.path)")
    }

    @MainActor
    static func render(_ entry: GalleryEntry, to outDir: URL) throws {
        let content = entry.view
            .frame(width: entry.size.width, height: entry.size.height)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
            .environment(\.isSnapshot, true)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw SnapshotError.renderFailed(entry.name) }

        let url = outDir.appendingPathComponent(entry.name + ".png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw SnapshotError.writeFailed(entry.name)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SnapshotError.writeFailed(entry.name) }
        print("rendered \(url.path)")
    }
}

enum SnapshotError: Error {
    case renderFailed(String)
    case writeFailed(String)
}
