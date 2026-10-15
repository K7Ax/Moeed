import Foundation

public extension String {
    /// Every figure the app writes is an Eastern Arabic one: ١٦ not 16, ٠٫٣ not 0.3.
    /// English titles in the serif and the lecturer's slide keep their own figures.
    var eastern: String {
        let chars = Array(self)
        var out = ""
        out.reserveCapacity(utf8.count)
        for (i, c) in chars.enumerated() {
            if let v = c.asciiDigit {
                out.unicodeScalars.append(Unicode.Scalar(0x0660 + UInt32(v))!)
            } else if c == ".", i > 0, i + 1 < chars.count, chars[i - 1].asciiDigit != nil, chars[i + 1].asciiDigit != nil {
                out.append("\u{066B}") // Arabic decimal separator
            } else {
                out.append(c)
            }
        }
        return out
    }
}

public extension BinaryInteger {
    /// `12.eastern` → "١٢".
    var eastern: String { String(self).eastern }
}

private extension Character {
    var asciiDigit: Int? {
        guard let a = asciiValue, (48...57).contains(a) else { return nil }
        return Int(a - 48)
    }
}
