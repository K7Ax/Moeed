import SwiftUI

/// Design tokens. One accent: the tutor's pen. Everything else stays quiet so the ink reads.
enum Theme {
    // Surfaces
    static let ground = Color(hex: 0xEEF0F2)
    static let surface = Color.white
    static let sidebar = Color(hex: 0xF8F9FA)
    static let line = Color(hex: 0xDDE1E6)
    static let faint = Color(hex: 0xB8C0C9)

    // Text
    static let ink = Color(hex: 0x15181C)
    static let secondary = Color(hex: 0x444B55)
    static let muted = Color(hex: 0x5B636E)
    static let onDark = Color(hex: 0xC9CED4)

    // Accent: the pen. It marks what to look at — never "wrong".
    static let pen = Color(hex: 0xC2255C)
    static let penTint = Color(hex: 0xFCE8EF)
    static let highlighter = Color(hex: 0xFFD43B)
    static let spotlight = Color(hex: 0x15181C).opacity(0.55)

    // States
    static let correct = Color(hex: 0x2F9E44)
    static let correctText = Color(hex: 0x1F7A33)
    static let correctTint = Color(hex: 0xEAF6EC)
    static let working = Color(hex: 0xB35C00)
    static let workingText = Color(hex: 0x8A4700)
    static let workingTint = Color(hex: 0xFCEBD7)
    static let focus = Color(hex: 0x1F5FBF)
    static let focusTint = Color(hex: 0xE5EEFA)

    // Sample slide
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
    static let slide: CGFloat = 6
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    static let panel: CGFloat = 20
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
    /// White card with a soft, low shadow.
    func card(radius: CGFloat = Radius.panel) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.05), radius: 1, y: 1)
            .shadow(color: Theme.ink.opacity(0.06), radius: 14, y: 6)
    }

    /// A slide is a document: small radius, hairline edge, soft shadow.
    func slideFrame() -> some View {
        clipShape(RoundedRectangle(cornerRadius: Radius.slide, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.slide, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
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
