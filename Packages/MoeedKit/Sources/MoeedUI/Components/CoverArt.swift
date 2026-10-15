import MoeedCore
import SwiftUI

/// A lecture's cover art: the course code and number on top, its one word set large below,
/// the English title under it in the serif. Light falls from the top corner.
public struct CoverArt: View {
    let cover: Cover
    var size: CGFloat

    public init(_ cover: Cover, size: CGFloat = 132) {
        self.cover = cover
        self.size = size
    }

    public var body: some View {
        let pad = size * 0.085
        ZStack {
            cover.color
            LinearGradient(
                colors: [.white.opacity(0.18), .black.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.35, y: 1)
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(Cover.code)
                        .font(Typeface.plex(max(9, size * 0.068), .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer(minLength: 0)
                    Text(cover.number.eastern)
                        .font(Typeface.plex(size * 0.15, .bold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                Text(cover.word)
                    .font(Typeface.plex(size * 0.17, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(cover.english)
                    .font(Typeface.serif(max(9, size * 0.072), italic: true))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(pad)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.07, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("المحاضرة \(cover.number.eastern): \(cover.word)")
    }
}
