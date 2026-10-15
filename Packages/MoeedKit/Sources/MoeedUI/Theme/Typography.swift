import CoreText
import SwiftUI

/// The app's two faces, bundled with MoeedUI (both SIL Open Font License, see Resources/Fonts).
/// IBM Plex Sans Arabic sets every Arabic word: one family, hierarchy by weight and size only.
/// Brygada 1918 sets the English titles a lecture carries. Custom faces don't synthesise
/// weights, so each weight is its own named face.
public enum Typeface {
    /// Registers the bundled faces once, the first time any of them is asked for. A package can't
    /// list fonts in an Info.plist, so they're handed to Core Text for this process instead.
    public static let registered: Bool = {
        guard let folder = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return false }
        for file in files where file.pathExtension == "ttf" {
            // An error here is "already registered" on a second launch path; the face is usable either way.
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
        return true
    }()

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
