import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import MoeedUI

/// Renders every screen in `Gallery` to a PNG so the design can be reviewed without Xcode.
/// Usage: swift run Snapshots <output-directory>
@main
struct SnapshotTool {
    @MainActor
    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first ?? "snapshots"
        let outDir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for entry in Gallery.entries() {
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
}

enum SnapshotError: Error {
    case renderFailed(String)
    case writeFailed(String)
}
