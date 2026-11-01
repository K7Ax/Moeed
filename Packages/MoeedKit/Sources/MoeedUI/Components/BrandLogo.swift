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

    static var image: Image? { Bundled.logo }
}
