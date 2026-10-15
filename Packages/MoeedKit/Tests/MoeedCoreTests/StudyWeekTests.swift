import XCTest
@testable import MoeedCore

final class StudyWeekTests: XCTestCase {
    private let week = StudyWeek(minutes: [34, 22, 0, 41, 28, 19, 26], goal: 30, firstTryRate: 0.72)

    func testDaysAfterTodayAreEmpty() {
        XCTAssertEqual(week.sofar(today: 2), [34, 22, 0, nil, nil, nil, nil])
        XCTAssertEqual(week.total(today: 2), 56)
    }

    func testStreakStopsAtADayOff() {
        XCTAssertEqual(week.streak(today: 5), 3)
        XCTAssertEqual(week.streak(today: 1), 2)
        XCTAssertEqual(week.streak(today: 2), 0)
    }

    func testShelfHasOneLectureInProgressAndOneBeingPrepared() {
        XCTAssertEqual(Samples.shelf.filter { $0.status == .ready && $0.progress > 0 && $0.progress < 1 }.count, 1)
        XCTAssertEqual(Samples.shelf.filter { if case .preparing = $0.status { return true } else { return false } }.count, 1)
    }
}
