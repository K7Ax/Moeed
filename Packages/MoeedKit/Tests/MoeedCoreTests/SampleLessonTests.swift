import XCTest
@testable import MoeedCore

final class SampleLessonTests: XCTestCase {
    private let page = Samples.sinePage

    func testEveryMarkStaysOnTheSlide() {
        for step in page.steps {
            for mark in step.marks {
                XCTAssertTrue(page.bounds.contains(mark.bounds), "step \(step.id): \(mark) leaves the slide")
            }
        }
    }

    func testCaptionCardsStayOnTheSlide() {
        for step in page.steps {
            guard let placement = step.placement else { continue }
            XCTAssertTrue(page.bounds.contains(placement.card), "step \(step.id): caption card leaves the slide")
        }
    }

    func testAskStepsOfferTheirAnswer() {
        for step in page.steps {
            guard let ask = step.ask else { continue }
            XCTAssertTrue(ask.options.contains { $0.id == ask.answerID }, "step \(step.id): answer is not an option")
            XCTAssertTrue(step.caption.isEmpty, "step \(step.id): an ask step must not reveal the answer in its caption")
        }
    }

    func testStepIDsAreSequential() {
        XCTAssertEqual(page.steps.map(\.id), Array(1...page.steps.count))
    }

    func testReadingTimeCountsArabicWordsAndMath() {
        // 4 Arabic words + 1 math span + base.
        XCTAssertEqual(ReadingTime.milliseconds(for: "عند `0.3 s` احنا في القاع"), 400 * 4 + 600 + 300)
        // Latin words count separately.
        XCTAssertEqual(ReadingTime.milliseconds(for: "peak value"), 450 * 2 + 300)
    }

    func testImportJobStates() {
        let job = Samples.importJob
        XCTAssertEqual(job.state(ofSlide: 21), .ready)
        XCTAssertEqual(job.state(ofSlide: 22), .writing)
        XCTAssertEqual(job.state(ofSlide: 23), .waiting)
    }
}
