import XCTest
@testable import MoeedCore

final class FiguresTests: XCTestCase {
    func testDigitsBecomeEastern() {
        XCTAssertEqual("الشريحة 16 من 48".eastern, "الشريحة ١٦ من ٤٨")
        XCTAssertEqual(207.eastern, "٢٠٧")
    }

    func testDecimalPointBecomesArabicSeparator() {
        XCTAssertEqual("t = 0.3 s".eastern, "t = ٠٫٣ s")
    }

    func testOtherDotsStay() {
        XCTAssertEqual("انتهى. 3 أسئلة".eastern, "انتهى. ٣ أسئلة")
        XCTAssertEqual("v.1".eastern, "v.١")
    }
}
