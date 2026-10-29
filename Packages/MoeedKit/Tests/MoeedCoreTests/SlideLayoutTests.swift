import XCTest
@testable import MoeedCore

final class SlideLayoutTests: XCTestCase {
    private var order = 0

    /// A line of words laid out left to right, half an em per letter.
    private func line(_ text: String, x: Double, y: Double, size: Double) -> [WordBox] {
        var cursor = x
        return text.split(separator: " ").map { part in
            let width = Double(part.count) * size * 0.5
            defer {
                cursor += width + size * 0.3
                order += 1
            }
            return WordBox(String(part), SlideRect(cursor, y, width, size), order: order)
        }
    }

    private func sineSlide() -> RegionMap {
        let words = line("Sine Wave Reading the Graph", x: 200, y: 30, size: 40)
            + line("Find:", x: 56, y: 115, size: 25)
            + line("a) the peak value Vp", x: 56, y: 153, size: 25)
            + line("b) v at 0.3 s and 0.6 s", x: 56, y: 187, size: 25)
            + line("c) the peak-to-peak value", x: 56, y: 221, size: 25)
            + line("Key relation", x: 56, y: 353, size: 25)
            + line("f = 1 / T", x: 56, y: 390, size: 31)
            + line("8 V", x: 300, y: 281, size: 18)
            + line("0.2", x: 390, y: 412, size: 16)
        return SlideLayout.regions(words: words, blobs: [SlideRect(330, 270, 448, 270)], width: 800, height: 600)
    }

    private func region(_ map: RegionMap, _ text: String) -> Region? {
        map.regions.first { $0.text == text }
    }

    func testTheBiggestTextNearTheTopIsTheTitle() {
        let map = sineSlide()
        XCTAssertEqual(map.title, "Sine Wave Reading the Graph")
        XCTAssertEqual(map.regions.filter(\.isTitle).count, 1)
    }

    func testListItemsStaySeparate() {
        let map = sineSlide()
        for item in ["Find:", "a) the peak value Vp", "b) v at 0.3 s and 0.6 s", "c) the peak-to-peak value", "Key relation"] {
            XCTAssertEqual(region(map, item)?.kind, .text, item)
        }
    }

    func testAFormulaIsAnEquation() {
        XCTAssertEqual(region(sineSlide(), "f = 1 / T")?.kind, .equation)
    }

    func testLabelsBesideAGraphBelongToIt() {
        let map = sineSlide()
        let figures = map.regions.filter { $0.kind == .figure }
        XCTAssertEqual(figures.count, 1)
        // The graph grows left to take in its "8 V" label.
        XCTAssertEqual(figures.first?.box.x, 300)
        XCTAssertEqual(region(map, "8 V")?.host, "F1")
        XCTAssertEqual(region(map, "0.2")?.host, "F1")
        XCTAssertEqual(region(map, "0.2")?.kind, .text)
    }

    func testIdsCountUpByKind() {
        let ids = sineSlide().regions.map(\.id)
        XCTAssertEqual(ids.filter { $0.hasPrefix("T") }, (1...8).map { "T\($0)" })
        XCTAssertEqual(ids.filter { $0.hasPrefix("E") }, ["E1"])
        XCTAssertEqual(ids.filter { $0.hasPrefix("F") }, ["F1"])
    }

    func testRightToLeftWordsJoinInReadingOrder() {
        // Stored in logical order, laid out right to left.
        let words = [
            WordBox("قانون", SlideRect(600, 100, 60, 30), order: 0),
            WordBox("أوم", SlideRect(530, 100, 50, 30), order: 1),
        ]
        let map = SlideLayout.regions(words: words, blobs: [], width: 800, height: 600)
        XCTAssertEqual(map.regions.map(\.text), ["قانون أوم"])
    }

    func testPageFurnitureIsNotAFigure() {
        let figures = SlideLayout.figures(from: [
            SlideRect(0, 0, 800, 60),       // header band
            SlideRect(60, 83, 680, 3),      // rule under the title
            SlideRect(10, 10, 60, 40),      // logo
            SlideRect(330, 270, 448, 270),  // the graph
        ], width: 800, height: 600)
        XCTAssertEqual(figures, [SlideRect(330, 270, 448, 270)])
    }

    func testInkBlobsJoinNearbyStrokes() {
        // 20 × 10 cells, 2 units each: two strokes two cells apart on row 2, and a speck far away.
        var ink = [Bool](repeating: false, count: 200)
        for col in 0..<5 { ink[2 * 20 + col] = true }
        for col in 7..<10 { ink[2 * 20 + col] = true }
        ink[8 * 20 + 18] = true
        let blobs = InkMask(columns: 20, rows: 10, cell: 2, ink: ink).blobs(reach: 1)
            .sorted { $0.x < $1.x }
        XCTAssertEqual(blobs, [SlideRect(0, 4, 20, 2), SlideRect(36, 16, 2, 2)])
    }
}
