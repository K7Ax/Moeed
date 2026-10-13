import SwiftUI
import MoeedCore

/// Caption content for a card floating on the slide.
struct StageCaption {
    var number: Int
    var phrases: [Phrase]
    var revealed: Int
    var placement: CaptionPlacement
}

/// A slide with the ink layer, an optional selection, and an optional floating caption.
/// Everything inside is laid out in slide space, so it's always left-to-right.
struct SlideStage: View {
    var page: SlidePage
    var pastMarks: [InkMark] = []
    var marks: [InkMark] = []
    var drawn = true
    var showInk = true
    var selection: SlideRect?
    var caption: StageCaption?

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / CGFloat(page.width)
            ZStack(alignment: .topLeading) {
                SineSlideArtwork()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                if showInk {
                    InkLayer(pastMarks: pastMarks, marks: marks, scale: scale, drawn: drawn)
                }
                if let selection {
                    SelectionOverlay(rect: selection, scale: scale)
                }
                if let caption {
                    CaptionOverlay(caption: caption, scale: scale)
                }
            }
        }
        .aspectRatio(CGFloat(page.width / page.height), contentMode: .fit)
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: page.title))
    }
}

private struct CaptionOverlay: View {
    var caption: StageCaption
    var scale: CGFloat

    var body: some View {
        let card = caption.placement.card
        ZStack(alignment: .topLeading) {
            if let anchor = caption.placement.anchor {
                let start = card.clamped(anchor)
                Path { p in
                    p.move(to: CGPoint(x: CGFloat(start.x) * scale, y: CGFloat(start.y) * scale))
                    p.addLine(to: CGPoint(x: CGFloat(anchor.x) * scale, y: CGFloat(anchor.y) * scale))
                }
                .stroke(Theme.pen.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 7]))
                .opacity(caption.revealed > 0 ? 1 : 0)
            }
            CaptionCard(number: caption.number, phrases: caption.phrases, revealed: caption.revealed)
                .frame(width: CGFloat(card.w) * scale)
                .environment(\.layoutDirection, .rightToLeft)
                .offset(x: CGFloat(card.x) * scale, y: CGFloat(card.y) * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SelectionOverlay: View {
    var rect: SlideRect
    var scale: CGFloat

    var body: some View {
        let frame = CGRect(
            x: CGFloat(rect.x) * scale, y: CGFloat(rect.y) * scale,
            width: CGFloat(rect.w) * scale, height: CGFloat(rect.h) * scale
        )
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                .fill(Theme.focus.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                        .strokeBorder(Theme.focus, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                )
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
            handle.position(x: frame.maxX, y: frame.minY)
            handle.position(x: frame.minX, y: frame.maxY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var handle: some View {
        Circle()
            .fill(Theme.focus)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .frame(width: 16, height: 16)
    }
}

/// A zoomed crop of a slide around one point, for list thumbnails.
struct SlideCrop: View {
    var page: SlidePage
    var focus: SlidePoint
    var size = CGSize(width: 128, height: 96)
    var zoom: CGFloat = 3

    var body: some View {
        let width = size.width * zoom
        let height = size.height * zoom
        let fx = CGFloat(focus.x / page.width) * width
        let fy = CGFloat(focus.y / page.height) * height
        let ox = min(max(size.width / 2 - fx, size.width - width), 0)
        let oy = min(max(size.height / 2 - fy, size.height - height), 0)
        SlideStage(page: page, marks: [.circle(center: focus, rx: 24, ry: 24)])
            .frame(width: width, height: height)
            .offset(x: ox, y: oy)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .environment(\.layoutDirection, .leftToRight)
    }
}
