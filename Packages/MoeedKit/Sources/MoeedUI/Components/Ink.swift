import SwiftUI
import MoeedCore

enum InkTiming {
    static let stroke = 0.55
    static let gap = 0.15

    static func delay(for index: Int) -> Double { Double(index) * (stroke + gap) }
    static func total(for count: Int) -> Double { count == 0 ? 0 : delay(for: count - 1) + stroke }
}

/// The tutor's ink over a slide. Current marks draw on one after another; past marks sit faded.
struct InkLayer: View {
    var pastMarks: [InkMark]
    var marks: [InkMark]
    var scale: CGFloat
    var drawn: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(pastMarks.enumerated()), id: \.offset) { _, mark in
                MarkView(mark: mark, scale: scale, drawn: true, delay: 0)
                    .opacity(0.38)
            }
            ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                MarkView(mark: mark, scale: scale, drawn: drawn, delay: InkTiming.delay(for: index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MarkView: View {
    var mark: InkMark
    var scale: CGFloat
    var drawn: Bool
    var delay: Double
    @Environment(\.inkColor) private var color

    var body: some View {
        content
            .animation(drawn ? .easeInOut(duration: InkTiming.stroke).delay(delay) : nil, value: drawn)
    }

    @ViewBuilder
    private var content: some View {
        let progress: CGFloat = drawn ? 1 : 0
        switch mark {
        case let .spot(rect):
            SpotShape(rect: rect, scale: scale)
                .fill(Theme.spotlight, style: FillStyle(eoFill: true))
                .opacity(drawn ? 1 : 0)
        case let .highlight(rect):
            InkPath(mark: mark, scale: scale)
                .trim(from: 0, to: progress)
                .stroke(Theme.highlighter.opacity(0.4), style: StrokeStyle(lineWidth: CGFloat(rect.h) * scale, lineCap: .butt))
                .blendMode(.multiply)
        case let .label(text, at):
            Text(verbatim: text)
                .font(Theme.handwriting(size: 26 * scale))
                .foregroundStyle(color)
                .fixedSize()
                .position(x: CGFloat(at.x) * scale, y: CGFloat(at.y) * scale)
                .opacity(drawn ? 1 : 0)
                .scaleEffect(drawn ? 1 : 0.92)
        case .dot:
            InkPath(mark: mark, scale: scale)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 7 * scale))
        case .guide:
            InkPath(mark: mark, scale: scale)
                .trim(from: 0, to: progress)
                .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round, dash: [7 * scale, 7 * scale]))
        default:
            InkPath(mark: mark, scale: scale)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4.5 * scale, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Hand-drawn geometry for each mark. Deterministic wobble so the same step always looks the same.
struct InkPath: Shape {
    var mark: InkMark
    var scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch mark {
        case let .circle(center, rx, ry):
            let samples = 56
            for i in 0...samples {
                let f = Double(i) / Double(samples)
                let angle = -2.3 + f * (2 * Double.pi + 0.45)
                let wobble = 1 + 0.05 * sin(f * 9) + 0.08 * f
                let point = pt(center.x + rx * wobble * cos(angle), center.y + ry * wobble * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        case let .box(r):
            path.move(to: pt(r.x - 2, r.y + 1))
            path.addLine(to: pt(r.maxX + 1, r.y - 2))
            path.addLine(to: pt(r.maxX + 2, r.maxY + 1))
            path.addLine(to: pt(r.x - 1, r.maxY + 2))
            path.addLine(to: pt(r.x - 1, r.y - 2))
            path.addLine(to: pt(r.x + 12, r.y - 3))
        case let .underline(a, b):
            path.move(to: pt(a.x, a.y))
            path.addQuadCurve(to: pt(b.x, b.y), control: pt((a.x + b.x) / 2, (a.y + b.y) / 2 - 3))
        case let .highlight(r):
            path.move(to: pt(r.x, r.midY))
            path.addLine(to: pt(r.maxX, r.midY))
        case let .dot(c):
            path.addEllipse(in: CGRect(x: CGFloat(c.x - 3.5) * scale, y: CGFloat(c.y - 3.5) * scale, width: 7 * scale, height: 7 * scale))
        case let .guide(a, b):
            path.move(to: pt(a.x, a.y))
            path.addLine(to: pt(b.x, b.y))
        case let .arrow(a, b, bend):
            let control = SlidePoint((a.x + b.x) / 2 - (b.y - a.y) * bend, (a.y + b.y) / 2 + (b.x - a.x) * bend)
            path.move(to: pt(a.x, a.y))
            path.addQuadCurve(to: pt(b.x, b.y), control: pt(control.x, control.y))
            let tx = b.x - control.x
            let ty = b.y - control.y
            let length = max(1, (tx * tx + ty * ty).squareRoot())
            let ux = -tx / length
            let uy = -ty / length
            let head = 16.0
            let spread = 0.5
            let left = (ux * cos(spread) - uy * sin(spread), ux * sin(spread) + uy * cos(spread))
            let right = (ux * cos(-spread) - uy * sin(-spread), ux * sin(-spread) + uy * cos(-spread))
            path.move(to: pt(b.x + left.0 * head, b.y + left.1 * head))
            path.addLine(to: pt(b.x, b.y))
            path.addLine(to: pt(b.x + right.0 * head, b.y + right.1 * head))
        case .label, .spot:
            break
        }
        return path
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * scale, y: CGFloat(y) * scale)
    }
}

/// Dims the whole slide except a rounded window around `rect`.
struct SpotShape: Shape {
    var rect: SlideRect
    var scale: CGFloat

    func path(in bounds: CGRect) -> Path {
        var path = Path(bounds)
        let hole = CGRect(
            x: CGFloat(rect.x - 8) * scale,
            y: CGFloat(rect.y - 8) * scale,
            width: CGFloat(rect.w + 16) * scale,
            height: CGFloat(rect.h + 16) * scale
        )
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 14 * scale, height: 14 * scale))
        return path
    }
}
