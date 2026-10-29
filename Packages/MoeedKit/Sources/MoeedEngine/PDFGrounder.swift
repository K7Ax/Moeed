import CoreGraphics
import Foundation
import PDFKit
import MoeedCore

/// One slide, read: what the tutor can point at, and a picture of the page.
public struct GroundedSlide {
    /// 1-based, as the student counts.
    public var page: Int
    public var map: RegionMap
    public var words: [WordBox]
    public var image: CGImage
}

public enum EngineError: Error, CustomStringConvertible {
    case unreadable(URL)
    case noPage(Int)
    case renderFailed

    public var description: String {
        switch self {
        case let .unreadable(url): "can't open \(url.lastPathComponent) as a PDF"
        case let .noPage(n): "the PDF has no page \(n)"
        case .renderFailed: "couldn't draw the page"
        }
    }
}

/// Reads a PDF page on the device, at no cost: the words and their boxes come from the PDF's own text layer
/// (PDFKit), and drawings are found as the ink left over once the words are masked out.
public enum PDFGrounder {
    public static func ground(_ url: URL, page number: Int) throws -> GroundedSlide {
        guard let document = PDFDocument(url: url) else { throw EngineError.unreadable(url) }
        return try ground(document, page: number)
    }

    public static func ground(_ document: PDFDocument, page number: Int) throws -> GroundedSlide {
        guard number >= 1, let page = document.page(at: number - 1) else { throw EngineError.noPage(number) }
        let box = page.bounds(for: .cropBox)
        let words = words(on: page, box: box)
        let mask = try inkMask(of: page, box: box, words: words)
        let map = SlideLayout.regions(words: words, blobs: mask.blobs(), width: Double(box.width), height: Double(box.height))
        let image = try render(page, box: box, scale: 2)
        return GroundedSlide(page: number, map: map, words: words, image: image)
    }

    // MARK: Words

    /// Words with their boxes, in slide space (top-left origin). A word breaks at spaces,
    /// at a jump to another line, or at a gap wider than half the letter height.
    static func words(on page: PDFPage, box: CGRect) -> [WordBox] {
        var words: [WordBox] = []
        var current = ""
        var bounds = CGRect.null
        var last = CGRect.null
        var start = 0

        func flush() {
            defer {
                current = ""
                bounds = .null
                last = .null
            }
            guard !current.isEmpty, !bounds.isNull else { return }
            let string = current
                .precomposedStringWithCompatibilityMapping
                .filter { !SlideLayout.isBullet($0) }
            guard !string.isEmpty else { return }
            let rect = SlideRect(
                Double(bounds.minX - box.minX), Double(box.maxY - bounds.maxY),
                Double(bounds.width), Double(bounds.height)
            )
            words.append(WordBox(string, rect, order: start))
        }

        // PDFKit doesn't promise that `page.string`, `characterBounds(at:)` and `selection(for:)` share one
        // character order, so each character's text and bounds come from the same one-character selection.
        for index in 0..<page.numberOfCharacters {
            guard let selection = page.selection(for: NSRange(location: index, length: 1)) else {
                flush()
                continue
            }
            let char = selection.string ?? ""
            let rect = selection.bounds(for: page)
            if char.isEmpty || char.allSatisfy(\.isWhitespace) || rect.isNull || rect.width <= 0 || rect.height <= 0 {
                flush()
                continue
            }
            if !last.isNull {
                let gap = max(0, max(rect.minX, last.minX) - min(rect.maxX, last.maxX))
                let height = max(rect.height, last.height)
                if gap > height * 0.5 || abs(rect.midY - last.midY) > height * 0.5 { flush() }
            }
            if current.isEmpty { start = index }
            current += char
            bounds = bounds.union(rect)
            last = rect
        }
        flush()
        return words
    }

    // MARK: Ink

    /// Draws the page in grey at one pixel per point, marks what differs from the background,
    /// and blanks out the words. Each mask cell is 2 × 2 pixels.
    static func inkMask(of page: PDFPage, box: CGRect, words: [WordBox]) throws -> InkMask {
        let width = Int(box.width.rounded(.up))
        let height = Int(box.height.rounded(.up))
        guard width > 0, height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw EngineError.renderFailed }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        page.draw(with: .cropBox, to: context)
        guard let data = context.data else { throw EngineError.renderFailed }
        let stride = context.bytesPerRow
        let pixels = data.bindMemory(to: UInt8.self, capacity: stride * height)

        // The most common grey is the background, even on dark or tinted slides.
        var histogram = [Int](repeating: 0, count: 256)
        for row in 0..<height {
            for col in 0..<width { histogram[Int(pixels[row * stride + col])] += 1 }
        }
        let background = histogram.indices.max { histogram[$0] < histogram[$1] } ?? 255

        let cellPixels = 2
        let columns = (width + cellPixels - 1) / cellPixels
        let rows = (height + cellPixels - 1) / cellPixels
        var ink = [Bool](repeating: false, count: columns * rows)
        // Bitmap rows run top to bottom, the same way as slide space.
        for row in 0..<height {
            for col in 0..<width where abs(Int(pixels[row * stride + col]) - background) > 40 {
                ink[(row / cellPixels) * columns + col / cellPixels] = true
            }
        }
        let cell = Double(cellPixels)
        for word in words {
            let r = word.box.outset(1.5)
            let c0 = max(0, Int(r.x / cell))
            let c1 = min(columns - 1, Int(r.maxX / cell))
            let r0 = max(0, Int(r.y / cell))
            let r1 = min(rows - 1, Int(r.maxY / cell))
            guard c0 <= c1, r0 <= r1 else { continue }
            for row in r0...r1 {
                for col in c0...c1 { ink[row * columns + col] = false }
            }
        }
        return InkMask(columns: columns, rows: rows, cell: cell, ink: ink)
    }

    // MARK: Picture

    static func render(_ page: PDFPage, box: CGRect, scale: CGFloat) throws -> CGImage {
        let width = Int((box.width * scale).rounded(.up))
        let height = Int((box.height * scale).rounded(.up))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw EngineError.renderFailed }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: context)
        guard let image = context.makeImage() else { throw EngineError.renderFailed }
        return image
    }
}
