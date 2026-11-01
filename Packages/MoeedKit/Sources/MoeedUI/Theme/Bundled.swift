import CoreText
import SwiftUI

/// Where the bundled faces and the logo come from: MoeedUI's own resources. The Swift Playgrounds
/// copy has no `Bundle.module` (an app package keeps no resource bundle of its own), so
/// tools/make_playground.py swaps this file for tools/playground/Bundled.swift, which reads the
/// same files from the app's asset catalog.
enum Bundled {
    /// Hands the faces to Core Text for this process; a package can't list fonts in an Info.plist.
    static func registerFonts() -> Bool {
        guard let folder = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return false }
        for file in files where file.pathExtension == "ttf" {
            // An error here is "already registered" on a second launch path; the face is usable either way.
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
        return true
    }

    static let logo: Image? = {
        guard let url = Bundle.module.url(forResource: "Logo", withExtension: "png", subdirectory: "Brand") else { return nil }
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path).map { Image(uiImage: $0) }
        #else
        return NSImage(contentsOf: url).map { Image(nsImage: $0) }
        #endif
    }()
}
