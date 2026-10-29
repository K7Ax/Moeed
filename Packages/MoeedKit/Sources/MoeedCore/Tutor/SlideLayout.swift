import Foundation

/// A word found on the page.
public struct WordBox: Hashable, Sendable {
    public var text: String
    public var box: SlideRect
    /// Position in the page's text stream (logical order), so right-to-left lines join in the right order.
    public var order: Int

    public init(_ text: String, _ box: SlideRect, order: Int) {
        self.text = text
        self.box = box
        self.order = order
    }
}

/// A coarse map of where there's ink on the page once the words are masked out.
/// What's left in big connected blobs is drawings: graphs, circuits, diagrams.
public struct InkMask: Sendable {
    public let columns: Int
    public let rows: Int
    /// Slide units per cell.
    public let cell: Double
    public var ink: [Bool]

    public init(columns: Int, rows: Int, cell: Double, ink: [Bool]) {
        precondition(ink.count == columns * rows, "ink must have columns × rows cells")
        self.columns = columns
        self.rows = rows
        self.cell = cell
        self.ink = ink
    }

    /// Connected blobs of ink, grown by `reach` cells so the separate strokes of one drawing join up.
    /// Each box is measured over the original ink only, so the growing doesn't make figures bigger.
    public func blobs(reach: Int = 3) -> [SlideRect] {
        var grown = [Bool](repeating: false, count: ink.count)
        for row in 0..<rows {
            for col in 0..<columns where ink[row * columns + col] {
                for r in max(0, row - reach)...min(rows - 1, row + reach) {
                    for c in max(0, col - reach)...min(columns - 1, col + reach) {
                        grown[r * columns + c] = true
                    }
                }
            }
        }

        var seen = [Bool](repeating: false, count: ink.count)
        var boxes: [SlideRect] = []
        for start in grown.indices where grown[start] && !seen[start] {
            var stack = [start]
            seen[start] = true
            var minC = Int.max, minR = Int.max, maxC = -1, maxR = -1
            while let index = stack.popLast() {
                let row = index / columns
                let col = index % columns
                if ink[index] {
                    minC = min(minC, col); maxC = max(maxC, col)
                    minR = min(minR, row); maxR = max(maxR, row)
                }
                let neighbours = [
                    col > 0 ? index - 1 : -1,
                    col < columns - 1 ? index + 1 : -1,
                    row > 0 ? index - columns : -1,
                    row < rows - 1 ? index + columns : -1,
                ]
                for next in neighbours where next >= 0 && grown[next] && !seen[next] {
                    seen[next] = true
                    stack.append(next)
                }
            }
            guard maxC >= 0 else { continue }
            boxes.append(SlideRect(
                Double(minC) * cell, Double(minR) * cell,
                Double(maxC - minC + 1) * cell, Double(maxR - minR + 1) * cell
            ))
        }
        return boxes
    }
}

/// Turns the words and ink of a slide into the regions the tutor points at:
/// T# for prose, E# for equations, F# for drawings. Ported from the Python prototype's `extract.py`.
public enum SlideLayout {
    struct Line {
        var words: [WordBox]
        var box: SlideRect
        var size: Double
        var text: String
        var bullet: Bool
    }

    public static func regions(words: [WordBox], blobs: [SlideRect], width: Double, height: Double) -> RegionMap {
        let page = SlideRect(0, 0, width, height)
        var drawings = figures(from: blobs, width: width, height: height)
        let paragraphs = blocks(lines(words))

        // Short labels just outside a drawing (axis values, units) belong to it.
        var labels: [Line] = []
        var rest: [Line] = []
        for block in paragraphs {
            let isLabel = !isProse(block.text) && block.text.count <= 8
            if isLabel, let f = drawings.firstIndex(where: { $0.near(block.box, dx: 24, dy: 24) }) {
                drawings[f] = drawings[f].union(block.box)
                labels.append(block)
            } else {
                rest.append(block)
            }
        }
        drawings = ordered(drawings.map { ($0, "") }).map { $0.0 }

        func host(of box: SlideRect) -> String? {
            drawings.firstIndex { $0.contains(box.center) }.map { "F\($0 + 1)" }
        }

        let titleSize = rest.map(\.size).max() ?? 0
        var prose: [(SlideRect, String, Bool)] = []
        var math: [(SlideRect, String)] = []
        for block in rest {
            if isProse(block.text) {
                let isTitle = block.size >= titleSize - 1 && block.box.y < height * 0.2
                prose.append((block.box, block.text, isTitle))
            } else if host(of: block.box) != nil {
                labels.append(block)
            } else {
                math.append((block.box, block.text))
            }
        }

        // An equation is a cluster of math lines sitting close together.
        let equations: [(SlideRect, String)] = cluster(math.map { $0.0 }, gap: 6, gapY: 2.5).compactMap { box -> (SlideRect, String)? in
            let text = math
                .filter { box.contains($0.0.center) }
                .sorted { ($0.0.y, $0.0.x) < ($1.0.y, $1.0.x) }
                .map { $0.1 }
                .joined(separator: " ")
            return ["or", "and", "أو", "و"].contains(text.lowercased()) ? nil : (box, text)
        }

        var regions: [Region] = []
        let texts = ordered(prose.map { ($0.0, $0.1) } + labels.map { ($0.box, $0.text) })
        for (index, item) in texts.enumerated() {
            let isTitle = prose.contains { $0.0 == item.0 && $0.2 }
            regions.append(Region(id: "T\(index + 1)", kind: .text, box: item.0.kept(in: page), text: item.1, isTitle: isTitle, host: host(of: item.0)))
        }
        for (index, item) in ordered(equations).enumerated() {
            regions.append(Region(id: "E\(index + 1)", kind: .equation, box: item.0.kept(in: page), text: item.1.isEmpty ? "(equation)" : item.1))
        }
        for (index, box) in drawings.enumerated() {
            regions.append(Region(id: "F\(index + 1)", kind: .figure, box: box.kept(in: page)))
        }
        return RegionMap(width: width, height: height, regions: regions)
    }

    /// Reading order: top to bottom in 12-unit bands, then across.
    static func ordered(_ items: [(SlideRect, String)]) -> [(SlideRect, String)] {
        items.sorted { a, b in
            let ra = (a.0.y / 12).rounded()
            let rb = (b.0.y / 12).rounded()
            return ra != rb ? ra < rb : a.0.x < b.0.x
        }
    }

    /// The blobs that are drawings, not page furniture.
    public static func figures(from blobs: [SlideRect], width: Double, height: Double) -> [SlideRect] {
        let page = width * height
        let kept = blobs.filter { b in
            if b.w > width * 0.9 && b.h > height * 0.5 { return false }   // background or frame
            if b.w > width * 0.85 && b.h < height * 0.12 { return false } // header or footer band
            if b.w > width * 0.5 && b.h < height * 0.02 { return false }  // a rule under the title
            if b.area < page * 0.015 && b.y < height * 0.15 && b.x < width * 0.2 { return false } // logo
            return b.area > page * 0.01 && b.h > height * 0.07
        }
        return cluster(kept, gap: 6, gapY: 6)
    }

    // MARK: Lines and blocks

    static func lines(_ words: [WordBox]) -> [Line] {
        let sorted = words.sorted { a, b in
            let ya = a.box.y.rounded()
            let yb = b.box.y.rounded()
            return ya != yb ? ya < yb : a.box.x < b.box.x
        }
        var groups: [[WordBox]] = []
        var boxes: [SlideRect] = []
        for word in sorted {
            let size = word.box.h
            let match = boxes.indices.first { i in
                let b = boxes[i]
                return abs(b.y - word.box.y) < max(3, size * 0.35)
                    && word.box.x - b.maxX < size * 2.2
                    && word.box.x >= b.x - 2
            }
            if let i = match {
                groups[i].append(word)
                boxes[i] = boxes[i].union(word.box)
            } else {
                groups.append([word])
                boxes.append(word.box)
            }
        }
        return zip(groups, boxes).map { words, box in
            var text = words.sorted { $0.order < $1.order }.map(\.text).joined(separator: " ")
            let bullet = text.first.map(isBullet) ?? false
            if bullet { text = String(text.drop(while: { isBullet($0) || $0 == " " })) }
            return Line(words: words, box: box, size: words.map(\.box.h).max() ?? 0, text: text, bullet: bullet)
        }
        .sorted { ($0.box.y, $0.box.x) < ($1.box.y, $1.box.x) }
    }

    /// Wrapped lines of one paragraph merge; list items and bullets start a new block.
    static func blocks(_ lines: [Line]) -> [Line] {
        var blocks: [Line] = []
        for line in lines {
            if var last = blocks.last, continues(last, with: line) {
                last.text += " " + line.text
                last.box = last.box.union(line.box)
                last.words += line.words
                blocks[blocks.count - 1] = last
            } else {
                blocks.append(line)
            }
        }
        return blocks
    }

    private static func continues(_ block: Line, with line: Line) -> Bool {
        let gap = line.box.y - block.box.maxY
        let aligned = abs(line.box.x - block.box.x) < 40 || abs(line.box.maxX - block.box.maxX) < 40
        let sentenceEnded = block.text.hasSuffix(".") && (line.text.first?.isUppercase ?? false)
        return isProse(line.text) && isProse(block.text)
            && abs(block.size - line.size) <= 1.5
            && gap >= 0 && gap < line.size * 0.6
            && !line.bullet && !startsItem(line.text)
            && !sentenceEnded && aligned
    }

    // MARK: Text tests

    static let mathWords: Set<String> = ["sin", "cos", "tan", "rad", "rad/s", "cps", "ms", "Hz", "log", "ln", "max", "min"]

    /// Prose reads as words: a list item, three real words, or one word with no digits or equals sign.
    static func isProse(_ text: String) -> Bool {
        if startsItem(text) { return true }
        let real = text.split(separator: " ").filter { token in
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()،؛"))
            return trimmed.filter(\.isLetter).count >= 3 && !mathWords.contains(trimmed)
        }.count
        return real >= 3 || (real >= 1 && !text.contains("=") && !text.contains(where: \.isNumber))
    }

    /// `a)`, `(b)`, `3.`, `أ)` and the like.
    static func startsItem(_ text: String) -> Bool {
        if ["EXAMPLE", "Example", "Solution", "مثال", "الحل"].contains(where: { text.hasPrefix($0) }) { return true }
        var chars = Array(text.prefix(6))
        if chars.first == "(" { chars.removeFirst() }
        guard let first = chars.first else { return false }
        if first.isLetter, chars.count > 1, chars[1] == ")" { return true }
        let digits = chars.prefix(while: \.isNumber).count
        return digits > 0 && digits < chars.count && (chars[digits] == "." || chars[digits] == ")")
    }

    public static func isBullet(_ c: Character) -> Bool {
        if "•▪●◦‣■□➢➤✓".contains(c) { return true }
        return c.unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) }
    }

    /// Merges boxes that come within `gap` across and `gapY` down of each other, until nothing changes.
    static func cluster(_ input: [SlideRect], gap: Double, gapY: Double) -> [SlideRect] {
        var boxes = input
        var merged = true
        while merged {
            merged = false
            var out: [SlideRect] = []
            while let first = boxes.popLast() {
                var current = first
                var i = 0
                while i < boxes.count {
                    if current.near(boxes[i], dx: gap, dy: gapY) {
                        current = current.union(boxes.remove(at: i))
                        merged = true
                    } else {
                        i += 1
                    }
                }
                out.append(current)
            }
            boxes = out
        }
        return boxes
    }
}
