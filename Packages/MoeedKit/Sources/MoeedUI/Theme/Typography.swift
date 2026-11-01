import SwiftUI

/// The app's two faces, bundled with MoeedUI (both SIL Open Font License, see Resources/Fonts).
/// IBM Plex Sans Arabic sets every Arabic word: one family, hierarchy by weight and size only.
/// Brygada 1918 sets the English titles a lecture carries. Custom faces don't synthesise
/// weights, so each weight is its own named face.
public enum Typeface {
    /// Registers the bundled faces once, the first time any of them is asked for.
    public static let registered: Bool = Bundled.registerFonts()

    public static func plex(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        _ = registered
        return .custom(plexName(weight), size: size)
    }

    public static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium, italic: Bool = false) -> Font {
        _ = registered
        let name = italic ? "Brygada1918-MediumItalic" : weight.isBold ? "Brygada1918-Bold" : "Brygada1918-Medium"
        return .custom(name, size: size)
    }

    static func plexName(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: "IBMPlexSansArabic-Light"
        case .medium: "IBMPlexSansArabic-Medium"
        case .semibold: "IBMPlexSansArabic-SemiBold"
        case .bold, .heavy, .black: "IBMPlexSansArabic-Bold"
        default: "IBMPlexSansArabic-Regular"
        }
    }
}

private extension Font.Weight {
    var isBold: Bool { self == .semibold || self == .bold || self == .heavy || self == .black }
}
