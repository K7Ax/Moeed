import Foundation

public extension String {
    /// Every figure the app writes goes through here, so the numbering choice lives in one place.
    /// It is Latin digits (16, 0.3, 40%), the user's call on 2026-10-16; anything written in
    /// Eastern Arabic figures (a Hijri date from the formatter, say) comes back Latin too.
    var figures: String {
        var out = ""
        out.reserveCapacity(utf8.count)
        for c in unicodeScalars {
            switch c.value {
            case 0x0660...0x0669: out.unicodeScalars.append(Unicode.Scalar(0x30 + c.value - 0x0660)!)
            case 0x06F0...0x06F9: out.unicodeScalars.append(Unicode.Scalar(0x30 + c.value - 0x06F0)!)
            case 0x066B: out.append(".") // Arabic decimal separator
            case 0x066C: out.append(",") // Arabic thousands separator
            case 0x066A: out.append("%")
            default: out.unicodeScalars.append(c)
            }
        }
        return out
    }
}

public extension BinaryInteger {
    /// `12.figures` → "12".
    var figures: String { String(self).figures }
}
