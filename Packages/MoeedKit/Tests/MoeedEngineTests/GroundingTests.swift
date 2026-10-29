import CoreGraphics
import CoreText
import PDFKit
import XCTest
@testable import MoeedCore
@testable import MoeedEngine

final class GroundingTests: XCTestCase {
    /// A slide made the way lecture PDFs are: real text, and a graph drawn with strokes.
    /// Positions are given in slide space (top-left origin) and flipped into PDF space.
    private func makeSlide() throws -> PDFDocument {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 800, height: 600)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)

        func text(_ string: String, x: CGFloat, top: CGFloat, size: CGFloat) {
            let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
            let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            context.textPosition = CGPoint(x: x, y: 600 - top - size * 0.8)
            CTLineDraw(line, context)
        }
        text("Reading the Graph", x: 220, top: 30, size: 36)
        text("a) the peak value", x: 56, top: 150, size: 22)
        text("b) the period", x: 56, top: 190, size: 22)
        text("f = 1 / T", x: 56, top: 300, size: 26)

        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(2.5)
        context.strokeLineSegments(between: [
            CGPoint(x: 360, y: 600 - 260), CGPoint(x: 360, y: 600 - 540),
            CGPoint(x: 350, y: 600 - 400), CGPoint(x: 760, y: 600 - 400),
        ])
        let wave = CGMutablePath()
        wave.move(to: CGPoint(x: 360, y: 200))
        for i in 0..<6 {
            let x0 = 360 + CGFloat(i) * 65
            let control = CGPoint(x: x0 + 32.5, y: i % 2 == 0 ? 420 : -20)
            wave.addQuadCurve(to: CGPoint(x: x0 + 65, y: 200), control: control)
        }
        context.addPath(wave)
        context.strokePath()

        context.endPDFPage()
        context.closePDF()
        return try XCTUnwrap(PDFDocument(data: data as Data))
    }

    func testTheTextLayerBecomesRegionsInSlideSpace() throws {
        let slide = try PDFGrounder.ground(makeSlide(), page: 1)
        let map = slide.map
        print("WORDS", slide.words.map { "\($0.text)@\(Int($0.box.x)),\(Int($0.box.y)),\(Int($0.box.w))x\(Int($0.box.h))#\($0.order)" })
        print("LISTING", map.listing)
        let page = try XCTUnwrap(makeSlide().page(at: 0))
        let units = Array((page.string ?? "").utf16)
        print("COUNTS", page.numberOfCharacters, units.count)
        for i in 0..<min(40, page.numberOfCharacters) {
            let b = page.characterBounds(at: i)
            let u = i < units.count ? String(decoding: [units[i]], as: UTF16.self).debugDescription : "-"
            let one = page.selection(for: NSRange(location: i, length: 1))
            let sel = (one?.string ?? "nil").debugDescription + " " + String(describing: one?.bounds(for: page))
            print("IDX", i, u, sel, Int(b.minX), Int(b.minY), Int(b.width), Int(b.height))
        }
        for line in page.selection(for: page.bounds(for: .cropBox))?.selectionsByLine() ?? [] {
            let b = line.bounds(for: page)
            print("LINE", (line.string ?? "").debugDescription, Int(b.minX), Int(b.minY), Int(b.width), Int(b.height))
        }
        let lines = SlideLayout.lines(slide.words)
        print("LAYOUT", lines.map { "\($0.text)@\(Int($0.box.y))" })
        XCTAssertEqual(map.width, 800)
        XCTAssertEqual(map.title, "Reading the Graph")

        let item = try XCTUnwrap(map.regions.first { $0.text.contains("peak") })
        XCTAssertEqual(item.kind, .text)
        XCTAssertEqual(item.box.x, 56, accuracy: 4)
        XCTAssertEqual(item.box.y, 150, accuracy: 10)
        XCTAssertNotNil(map.regions.first { $0.text.contains("period") && $0.id != item.id })

        let formula = try XCTUnwrap(map.regions.first { $0.text.contains("1 / T") })
        XCTAssertEqual(formula.kind, .equation)
    }

    func testTheGraphIsFoundFromItsInk() throws {
        let slide = try PDFGrounder.ground(makeSlide(), page: 1)
        let figures = slide.map.regions.filter { $0.kind == .figure }
        XCTAssertEqual(figures.count, 1)
        let box = try XCTUnwrap(figures.first?.box)
        XCTAssertEqual(box.x, 350, accuracy: 8)
        XCTAssertEqual(box.y, 260, accuracy: 8)
        XCTAssertEqual(box.maxX, 760, accuracy: 8)
        XCTAssertEqual(box.maxY, 540, accuracy: 8)
    }

    func testTheMarkedUpImageIsTwiceTheSlide() throws {
        let slide = try PDFGrounder.ground(makeSlide(), page: 1)
        let image = try XCTUnwrap(SetOfMarks.draw(slide))
        XCTAssertEqual(image.width, 1600)
        XCTAssertEqual(image.height, 1200)
        XCTAssertNotNil(image.pngData())
    }

    func testAMissingPageIsAnError() throws {
        XCTAssertThrowsError(try PDFGrounder.ground(makeSlide(), page: 2))
    }

    func testTheRequestCarriesTheSlideAndCachesTheInstructions() throws {
        let tutor = ClaudeTutor(apiKey: "test-key", model: "claude-test")
        let request = tutor.makeRequest(system: "sys", image: Data([1, 2, 3]), text: "hello")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "claude-test")
        XCTAssertEqual(body["stream"] as? Bool, true)
        let system = try XCTUnwrap((body["system"] as? [[String: Any]])?.first)
        XCTAssertEqual((system["cache_control"] as? [String: String])?["type"], "ephemeral")
        let content = try XCTUnwrap(((body["messages"] as? [[String: Any]])?.first?["content"]) as? [[String: Any]])
        let source = try XCTUnwrap(content.first?["source"] as? [String: String])
        XCTAssertEqual(source["media_type"], "image/png")
        XCTAssertEqual(source["data"], Data([1, 2, 3]).base64EncodedString())
        XCTAssertEqual(content.last?["text"] as? String, "hello")
    }
}
