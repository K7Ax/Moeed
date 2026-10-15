import MoeedCore
import SwiftUI

/// Design tokens: «الملزمة», the photocopied lecture packet a معيد goes through with you.
/// Everything is something you could find on a study desk: paper stock, black toner,
/// the tutor's red pen, your own blue ballpoint, and a yellow highlighter. No glow, no glass.
enum Theme {
    // Stock
    static let desk = Color(hex: 0xD9CFBD)
    static let paper = Color(hex: 0xF5EFE3)
    static let paperShade = Color(hex: 0xECE4D4)
    static let card = Color(hex: 0xFBF8F1)

    // Toner
    static let ink = Color(hex: 0x171513)
    static let inkSoft = Color(hex: 0x56504A)
    static let mark = Color(hex: 0x8C8579)
    static let rule = Color(hex: 0xCBC2B2)
    static let hole = Color(hex: 0xBDB19C)

    // Pens. Red is the tutor's: it marks what to look at, never "wrong".
    static let red = Color(hex: 0xC23B22)
    static let redTint = Color(hex: 0xC23B22, opacity: 0.09)
    /// The student's own ballpoint: your picks, your questions.
    static let blue = Color(hex: 0x24418F)
    static let blueTint = Color(hex: 0x24418F, opacity: 0.08)
    static let highlighter = Color(hex: 0xF3D13A)
    /// Rubber-stamp teal, from the logo: done, ready, understood.
    static let stamp = Color(hex: 0x0F5B63)
    static let spotlight = Color(hex: 0x171513, opacity: 0.5)

    // Sample slide (a printed page, so these stay dark-on-light)
    static let slideTitle = Color(hex: 0x1C3D6E)
    static let slideInk = Color(hex: 0x1F2328)
    static let slideLabel = Color(hex: 0x3B424A)
    static let slideRule = Color(hex: 0xD5DAE0)
    static let slideAxis = Color(hex: 0x5B636E)
    static let slideGuide = Color(hex: 0x9AA3AE)
    static let slideWave = Color(hex: 0x2F6DB5)

    /// One family for Arabic: hierarchy is weight and size, never a second face.
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Typeface.plex(size, weight)
    }

    /// Latin titles are set the way a paper sets them: in a serif.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Typeface.serif(size, weight)
    }

    /// The tutor's handwriting for ink labels.
    static func handwriting(size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }

    /// Arabic needs generous leading (~1.4).
    static func leading(for size: CGFloat) -> CGFloat { size * 0.4 }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Paper

extension View {
    /// A sheet of paper lying on the desk: square corners, grain, and the tight shadow paper actually casts.
    func paperSheet(_ stock: Color = Theme.paper, lift: CGFloat = 1) -> some View {
        background {
            ZStack {
                Rectangle().fill(stock)
                Grain(density: 0.6)
            }
            .overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.07), lineWidth: 0.5))
            .shadow(color: Theme.ink.opacity(0.18), radius: 0.6 * lift, y: 0.6 * lift)
            .shadow(color: Theme.ink.opacity(0.12), radius: 9 * lift, x: 0, y: 5 * lift)
        }
    }

    /// A slide printed into the packet: the page itself, with a hairline where the copier caught the edge.
    func slideFrame() -> some View {
        overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.75))
            .background {
                Rectangle().fill(.white)
                    .shadow(color: Theme.ink.opacity(0.2), radius: 0.8, y: 0.8)
                    .shadow(color: Theme.ink.opacity(0.14), radius: 14, y: 8)
            }
    }

    /// A strip of clear tape holding something down.
    func taped(_ alignment: Alignment = .top, angle: Double = -4) -> some View {
        overlay(alignment: alignment) {
            Tape().rotationEffect(.degrees(angle)).offset(y: alignment == .top ? -9 : 0)
        }
    }
}

/// The desk under the packet.
struct Desk: View {
    var body: some View {
        ZStack {
            Theme.desk
            Grain(density: 1.2)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Paper grain and toner specks, seeded so every render is the same.
struct Grain: View {
    var density: Double = 1

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x2545F4914F6CDD1D
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            let area = Double(size.width * size.height)
            let count = Int(area / 900 * density)
            for _ in 0..<min(count, 6000) {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.3 + next() * 0.7
                let dark = next() > 0.35
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(dark ? Theme.ink.opacity(0.035 + next() * 0.05) : .white.opacity(0.25))
                )
            }
            // A few long fibres in the stock.
            for _ in 0..<min(Int(Double(count) / 60), 120) {
                let x = next() * size.width
                let y = next() * size.height
                let a = next() * .pi
                let l = 4 + next() * 10
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + cos(a) * l, y: y + sin(a) * l))
                context.stroke(p, with: .color(Theme.ink.opacity(0.04)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A short piece of matte tape.
struct Tape: View {
    var width: CGFloat = 64

    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xEDE6D3, opacity: 0.78))
            .overlay(Rectangle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
            .frame(width: width, height: 20)
            .shadow(color: Theme.ink.opacity(0.08), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Rules

/// A printed hairline.
struct Hairline: View {
    var color: Color = Theme.ink
    var weight: CGFloat = 0.75

    var body: some View {
        Rectangle().fill(color).frame(height: weight)
    }
}

/// The masthead's thick-over-thin rule.
struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2.5) {
            Rectangle().fill(Theme.ink).frame(height: 2.5)
            Rectangle().fill(Theme.ink).frame(height: 0.75)
        }
        .accessibilityHidden(true)
    }
}

/// A column rule between two columns of a page.
struct ColumnRule: View {
    var body: some View {
        Rectangle().fill(Theme.rule).frame(width: 0.75)
    }
}

/// The dotted leader of a table of contents: «المحاضرة الخامسة ........ ص ١٦».
struct Leader: View {
    var body: some View {
        Line()
            .stroke(Theme.mark, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 5]))
            .frame(height: 2)
            .frame(minWidth: 16)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// A highlighter swipe: uneven ends, a little off the baseline, multiplied into the paper.
struct HighlighterSwipe: Shape {
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let s = Double(seed % 5)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.12))
        p.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + rect.height * (0.05 + s * 0.02)))
        p.addLine(to: CGPoint(x: rect.maxX + 2, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * (0.02 + s * 0.015)))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// Marks text with the highlighter.
    func highlighted(_ on: Bool = true, seed: Int = 0) -> some View {
        background {
            if on {
                HighlighterSwipe(seed: seed)
                    .fill(Theme.highlighter.opacity(0.62))
                    .padding(.horizontal, -5)
                    .padding(.vertical, 1)
                    .blendMode(.multiply)
            }
        }
    }
}

// MARK: - Rich text

enum RichText {
    /// Wraps a run in a left-to-right isolate so Latin and math keep their order inside Arabic.
    static func ltr(_ text: String) -> String { "\u{2066}" + text + "\u{2069}" }

    /// Renders backtick spans as bold, left-to-right runs: "عند `0.3 s` احنا في القاع",
    /// with every figure in Eastern Arabic, math included: "عند ٠٫٣ s".
    static func attributed(_ raw: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in raw.eastern.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
            if index % 2 == 1 {
                var run = AttributedString(ltr(String(part)))
                run.inlinePresentationIntent = .stronglyEmphasized
                result += run
            } else {
                result += AttributedString(String(part))
            }
        }
        return result
    }
}

// MARK: - Environment

private struct SnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

private struct InkColorKey: EnvironmentKey {
    static let defaultValue = Theme.red
}

extension EnvironmentValues {
    /// The tutor's pen on a slide: red on the paper screens, teal in «الأصلي».
    var inkColor: Color {
        get { self[InkColorKey.self] }
        set { self[InkColorKey.self] = newValue }
    }
}

public extension EnvironmentValues {
    /// True while rendering static screenshots: skip platform-backed controls and playback.
    var isSnapshot: Bool {
        get { self[SnapshotKey.self] }
        set { self[SnapshotKey.self] = newValue }
    }
}
