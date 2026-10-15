import XCTest
@testable import MoeedCore

final class FiguresTests: XCTestCase {
    func testLatinDigitsStay() {
        XCTAssertEqual("الشريحة 16 من 48".figures, "الشريحة 16 من 48")
        XCTAssertEqual(207.figures, "207")
    }

    func testEasternDigitsBecomeLatin() {
        XCTAssertEqual("\u{0661}\u{0666} جمادى الأولى".figures, "16 جمادى الأولى")
        XCTAssertEqual("\u{0660}\u{066B}\u{0663}".figures, "0.3")
        XCTAssertEqual("\u{0664}\u{0660}\u{066A}".figures, "40%")
    }

    func testOtherTextStays() {
        XCTAssertEqual("انتهى. v.1".figures, "انتهى. v.1")
    }
}
