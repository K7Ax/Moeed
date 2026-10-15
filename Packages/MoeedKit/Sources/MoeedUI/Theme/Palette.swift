import SwiftUI

/// A colour with a light and a dark value, resolved against the view's own `colorScheme`.
/// Resolving through the environment (not UIColor/NSColor traits) keeps snapshots honest:
/// `.environment(\.colorScheme, .dark)` renders the dark palette even off-screen.
public struct Adaptive: ShapeStyle, Sendable {
    public let light: Color
    public let dark: Color

    public init(_ light: Color, _ dark: Color) {
        self.light = light
        self.dark = dark
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? dark : light
    }

    /// The plain colour for a scheme, for the few APIs that want a `Color` (shadows, gradients).
    public func color(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }

    /// The same colour in both schemes.
    public static func fixed(_ color: Color) -> Adaptive { Adaptive(color, color) }

    public func opacity(_ amount: Double) -> Adaptive {
        Adaptive(light.opacity(amount), dark.opacity(amount))
    }
}

/// «الأصلي»: the iPadOS system palette with one teal accent taken from the logo.
/// Black and white grounds, grouped greys for raised surfaces, label greys for text.
/// Red is kept for a door that is closing; a wrong answer is amber.
public enum Palette {
    // Grounds
    public static let bg = Adaptive(Color(hex: 0xFFFFFF), Color(hex: 0x000000))
    public static let raised = Adaptive(Color(hex: 0xF4F4F7), Color(hex: 0x1C1C1E))
    public static let raised2 = Adaptive(Color(hex: 0xE5E5EA), Color(hex: 0x2C2C2E))
    public static let sidebar = Adaptive(Color(hex: 0xF4F4F7), Color(hex: 0x141416))
    public static let bar = Adaptive(Color(hex: 0xFAFAFA, opacity: 0.94), Color(hex: 0x161618, opacity: 0.92))

    // Labels
    public static let text = Adaptive(Color(hex: 0x000000), Color(hex: 0xFFFFFF))
    public static let text2 = Adaptive(Color(hex: 0x3C3C43, opacity: 0.62), Color(hex: 0xEBEBF5, opacity: 0.6))
    public static let text3 = Adaptive(Color(hex: 0x3C3C43, opacity: 0.3), Color(hex: 0xEBEBF5, opacity: 0.3))

    // Lines and fills
    public static let sep = Adaptive(Color(hex: 0x3C3C43, opacity: 0.18), Color(hex: 0x545458, opacity: 0.6))
    public static let fill = Adaptive(Color(hex: 0x787880, opacity: 0.12), Color(hex: 0x787880, opacity: 0.24))
    public static let hover = Adaptive(Color(hex: 0x787880, opacity: 0.08), Color(hex: 0x787880, opacity: 0.16))

    // The one accent, and the tutor's ink in the chrome.
    public static let accent = Adaptive(Color(hex: 0x0A8F86), Color(hex: 0x3CC8B8))
    public static let accentSoft = Adaptive(Color(hex: 0x0A8F86, opacity: 0.12), Color(hex: 0x3CC8B8, opacity: 0.18))
    public static let onAccent = Adaptive(Color(hex: 0xFFFFFF), Color(hex: 0x00201D))
    public static let ink = Adaptive(Color(hex: 0x0A8F86), Color(hex: 0x5FE0CF))

    /// A closing door: an exam tomorrow, a review that lapses tonight. Nothing else is red.
    public static let alert = Adaptive(Color(hex: 0xD70015), Color(hex: 0xFF6961))
}

/// The player is always night: the slide floats on deep teal like an album on its own colour.
public enum Stage {
    public static let deep = Color(hex: 0x061210)
    public static let mint = Color(hex: 0x8FF2E2)
    public static let rightBG = Color(hex: 0x7CE6CF)
    public static let rightFG = Color(hex: 0x00231C)
    public static let wrongBG = Color(hex: 0xFFB340)
    public static let wrongFG = Color(hex: 0x2A1800)
    /// The tutor's pen on the printed slide, and the student's when they ask.
    public static let pen = Color(hex: 0x0A8F86)
    public static let askPen = Color(hex: 0xE8590C)
    /// Slow light drifting behind the artwork.
    public static let ambient: [Color] = ([0x14776C, 0x0E3F5C, 0x2BA889, 0x0B5A55] as [UInt32]).map { Color(hex: $0) }
}

/// A lecture's cover: one flat colour and one word from it, set large, the way ثمانية covers a show.
public struct Cover: Sendable, Hashable {
    public let number: Int
    public let word: String
    public let english: String
    public let color: Color

    public static let code = "كهر 207"

    public static let samples: [Cover] = [
        Cover(number: 1, word: "الأساس", english: "Circuit Basics", color: Color(hex: 0x2E4C73)),
        Cover(number: 2, word: "أوم", english: "Ohm's Law & Power", color: Color(hex: 0x5D3D8F)),
        Cover(number: 3, word: "كيرشوف", english: "Kirchhoff's Laws", color: Color(hex: 0x2D6A4F)),
        Cover(number: 4, word: "المكثّف", english: "Capacitors & Inductors", color: Color(hex: 0x9A4B1F)),
        Cover(number: 5, word: "الجيبية", english: "Sinusoidal Waveforms", color: Color(hex: 0x0B7F78)),
        Cover(number: 6, word: "الطور", english: "Phasors", color: Color(hex: 0x4B5058)),
    ]
}
