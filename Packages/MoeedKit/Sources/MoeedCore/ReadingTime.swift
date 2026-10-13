import Foundation

/// How long a caption phrase stays before the next one appears.
/// Same formula as the web prototype: 400 ms per Arabic word, 450 per Latin word,
/// 600 per math span (text between backticks), plus 300 ms of breathing room.
public enum ReadingTime {
    public static func milliseconds(for text: String) -> Int {
        var arabic = 0
        var latin = 0
        var math = 0
        for (index, part) in text.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
            if index % 2 == 1 {
                math += 1
                continue
            }
            for word in part.split(whereSeparator: \.isWhitespace) {
                if word.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) {
                    arabic += 1
                } else if word.contains(where: \.isLetter) {
                    latin += 1
                }
            }
        }
        return 400 * arabic + 450 * latin + 600 * math + 300
    }
}
