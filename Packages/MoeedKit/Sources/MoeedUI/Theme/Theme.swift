import SwiftUI

/// Design tokens: "deep ocean", taken from the logo. Navy-black ground, teal and mint light,
/// one hot pen that clashes with the teal on purpose so the tutor's ink always wins.
enum Theme {
    // Surfaces
    static let abyss = Color(hex: 0x030812)
    static let ground = Color(hex: 0x060E1F)
    static let surface = Color(hex: 0x0C1831)
    static let raised = Color(hex: 0x132546)
    static let sidebar = Color(hex: 0x050C1B)
    static let line = Color.white.opacity(0.09)
    static let faint = Color(hex: 0x3A4C6E)

    // Text
    static let ink = Color(hex: 0xF2F7FF)
    static let secondary = Color(hex: 0xAEBBD6)
    static let muted = Color(hex: 0x7B8CAE)
    static let onBright = Color(hex: 0x021320)
    static let onDark = Color(hex: 0xC9D4E8)

    // Brand light, from the logo
    static let mint = Color(hex: 0x7CF7DE)
    static let teal = Color(hex: 0x18C6B3)
    static let ocean = Color(hex: 0x2E7BFF)
    static let navy = Color(hex: 0x0B2A5E)
    static let brand = LinearGradient(colors: [mint, teal, ocean], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let brandFlat = LinearGradient(colors: [mint, teal], startPoint: .leading, endPoint: .trailing)

    // The pen. It marks what to look at — never "wrong".
    static let pen = Color(hex: 0xFF3D81)
    static let penTint = Color(hex: 0xFF3D81).opacity(0.16)
    static let sunset = LinearGradient(colors: [Color(hex: 0xFF3D81), Color(hex: 0xFF8A4C)], startPoint: .leading, endPoint: .trailing)
    static let highlighter = Color(hex: 0xFFD43B)
    static let spotlight = Color(hex: 0x050C1B).opacity(0.6)

    // States
    static let correct = Color(hex: 0x3BE8A0)
    static let correctText = Color(hex: 0x86F5C6)
    static let correctTint = Color(hex: 0x3BE8A0).opacity(0.14)
    static let working = Color(hex: 0xFFB547)
    static let workingText = Color(hex: 0xFFCB7D)
    static let workingTint = Color(hex: 0xFFB547).opacity(0.14)
    static let focus = Color(hex: 0x5B9BFF)
    static let focusTint = Color(hex: 0x5B9BFF).opacity(0.16)

    // Sample slide (a white document, so these stay dark-on-light)
    static let slideTitle = Color(hex: 0x1C3D6E)
    static let slideInk = Color(hex: 0x1F2328)
    static let slideLabel = Color(hex: 0x3B424A)
    static let slideRule = Color(hex: 0xD5DAE0)
    static let slideAxis = Color(hex: 0x5B636E)
    static let slideGuide = Color(hex: 0x9AA3AE)
    static let slideWave = Color(hex: 0x2F6DB5)

    /// The tutor's handwriting for ink labels.
    static func handwriting(size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }

    /// Arabic needs generous leading (~1.4).
    static func leading(for size: CGFloat) -> CGFloat { size * 0.4 }
}

enum Radius {
    static let slide: CGFloat = 8
    static let control: CGFloat = 14
    static let card: CGFloat = 20
    static let panel: CGFloat = 26
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

extension View {
    /// A glass panel: deep fill, a sheen from the top, and a lit edge.
    /// Drawn with gradients rather than materials so it looks the same in renders.
    func card(radius: CGFloat = Radius.panel, tint: Color = Theme.surface) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            shape
                .fill(tint.opacity(0.92))
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.075), .white.opacity(0.0)], startPoint: .top, endPoint: .center)))
                .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
        }
    }

    /// A slide is a white screen in a dark room: crisp edge, teal light spilling under it.
    func slideFrame(glow: Bool = true) -> some View {
        clipShape(RoundedRectangle(cornerRadius: Radius.slide, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.slide, style: .continuous)
                    .strokeBorder(.white.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Theme.teal.opacity(glow ? 0.28 : 0), radius: 38, y: 18)
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }

    /// Soft coloured light under bright controls.
    func glow(_ color: Color, radius: CGFloat = 16, opacity: Double = 0.45) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, y: radius / 3)
    }
}

extension Theme {
    /// The lit edge of glass: bright at the top-leading corner, fading with a hint of teal.
    static let edge = LinearGradient(
        colors: [.white.opacity(0.22), .white.opacity(0.05), Theme.teal.opacity(0.18)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Background

/// Night-sea aurora: three pools of light over navy-black, and a little dust to give it depth.
struct Aurora: View {
    var intensity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ground, Theme.abyss], startPoint: .top, endPoint: .bottom)
            EllipticalGradient(colors: [Theme.teal.opacity(0.32 * intensity), .clear],
                               center: UnitPoint(x: 0.92, y: -0.05), startRadiusFraction: 0, endRadiusFraction: 0.62)
            EllipticalGradient(colors: [Theme.ocean.opacity(0.30 * intensity), .clear],
                               center: UnitPoint(x: 0.05, y: 1.05), startRadiusFraction: 0, endRadiusFraction: 0.66)
            EllipticalGradient(colors: [Theme.pen.opacity(0.12 * intensity), .clear],
                               center: UnitPoint(x: 0.42, y: 0.38), startRadiusFraction: 0, endRadiusFraction: 0.42)
            Dust()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Fixed, seeded specks of light.
private struct Dust: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            for _ in 0..<140 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.4 + next() * 1.3
                let a = 0.04 + next() * 0.22
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(a)))
            }
        }
    }
}

// MARK: - Rich text

enum RichText {
    /// Wraps a run in a left-to-right isolate so Latin and math keep their order inside Arabic.
    static func ltr(_ text: String) -> String { "\u{2066}" + text + "\u{2069}" }

    /// Renders backtick spans as bold, left-to-right runs: "عند `0.3 s` احنا في القاع".
    static func attributed(_ raw: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in raw.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
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

public extension EnvironmentValues {
    /// True while rendering static screenshots: skip platform-backed controls and playback.
    var isSnapshot: Bool {
        get { self[SnapshotKey.self] }
        set { self[SnapshotKey.self] = newValue }
    }
}
