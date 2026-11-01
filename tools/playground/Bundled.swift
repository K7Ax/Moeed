import CoreText
import SwiftUI
import UIKit

/// The Swift Playgrounds copy of MoeedUI/Theme/Bundled.swift. An app package has no `Bundle.module`,
/// so tools/make_playground.py puts each face in the asset catalog as a data set, and the logo as an image.
enum Bundled {
    static let faces = [__FACES__]

    static func registerFonts() -> Bool {
        var registered = false
        for name in faces {
            guard let data = NSDataAsset(name: name)?.data,
                  let provider = CGDataProvider(data: data as CFData),
                  let font = CGFont(provider)
            else { continue }
            // An error here is "already registered"; the face is usable either way.
            CTFontManagerRegisterGraphicsFont(font, nil)
            registered = true
        }
        return registered
    }

    static let logo: Image? = UIImage(named: "Logo").map { Image(uiImage: $0) }
}
