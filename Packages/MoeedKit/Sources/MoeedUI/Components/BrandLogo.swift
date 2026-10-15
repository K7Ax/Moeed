import SwiftUI

/// The user's own mark (the stair that becomes an arch, a play mark in its doorway),
/// bundled with MoeedUI so the app, the playground and the CI renders all show the real thing.
public struct BrandLogo: View {
    var size: CGFloat

    public init(size: CGFloat = 32) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = Self.image {
                image.resizable().interpolation(.high).scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static let image: Image? = {
        guard let url = Bundle.module.url(forResource: "Logo", withExtension: "png", subdirectory: "Brand") else { return nil }
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path).map { Image(uiImage: $0) }
        #else
        return NSImage(contentsOf: url).map { Image(nsImage: $0) }
        #endif
    }()
}
