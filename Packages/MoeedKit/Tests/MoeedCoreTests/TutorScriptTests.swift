import XCTest
@testable import MoeedCore

final class TutorScriptTests: XCTestCase {
    private let map = Samples.sineRegions

    private func parse(_ source: String) -> (TDPScript, TDPReport) {
        TDP.parse(source, regions: map.ids)
    }

    // MARK: The sample lesson, end to end

    func testSampleScriptParsesClean() {
        let (script, report) = parse(Samples.sineScript)
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(report.warnings, [])
        XCTAssertEqual(script.version, "1.2")
        XCTAssertEqual(script.header["title"], "قراءة القيمة اللحظية من الرسم")
        XCTAssertEqual(script.steps.map(\.number), Array(1...9))
    }

    func testSampleScriptCompilesToTheHandWrittenLesson() {
        let compiled = LessonCompiler.compile(source: Samples.sineScript, map: map, page: 16, deckTitle: "Lecture 5", deckPageCount: 51)
        let lesson = compiled.page
        let reference = Samples.sinePage
        XCTAssertEqual(compiled.report.errors, [])
        XCTAssertEqual(lesson.steps.count, reference.steps.count)
        XCTAssertEqual(lesson.title, reference.title)
        XCTAssertEqual(lesson.steps.map { $0.ask != nil }, reference.steps.map { $0.ask != nil })
        XCTAssertEqual(lesson.steps.map(\.caption), reference.steps.map(\.caption))
        XCTAssertEqual(lesson.steps.map(\.id), Array(1...9))

        let ask = lesson.steps[3].ask
        XCTAssertEqual(ask?.options.map(\.label), ["8 V", "0 V", "−8 V"])
        XCTAssertEqual(ask?.answerID, "c")
        XCTAssertEqual(ask?.hint, reference.steps[3].ask?.hint)
    }

    func testCompiledInkStaysOnTheSlide() {
        let lesson = LessonCompiler.compile(source: Samples.sineScript, map: map, page: 16, deckTitle: "", deckPageCount: 0).page
        for step in lesson.steps {
            for mark in step.marks {
                XCTAssertTrue(lesson.bounds.contains(mark.bounds), "step \(step.id): \(mark) leaves the slide")
            }
            if let card = step.placement?.card {
                XCTAssertTrue(lesson.bounds.contains(card), "step \(step.id): caption card leaves the slide")
            }
        }
    }

    func testTheStepAfterAQuestionPointsAtTheAnswer() {
        let lesson = LessonCompiler.compile(source: Samples.sineScript, map: map, page: 16, deckTitle: "", deckPageCount: 0).page
        let anchor = lesson.steps[4].placement?.anchor
        // The arrow's tip, just short of the trough at (430, 510).
        XCTAssertEqual(anchor?.x ?? 0, 420, accuracy: 0.01)
        XCTAssertEqual(anchor?.y ?? 0, 493, accuracy: 0.01)
    }

    // MARK: Anchors and geometry

    func testWholeNumbersNameACellAndDecimalsAPoint() {
        var report = TDPReport()
        let cell = TDP.parseAnchor("F1@2,5", step: 1, report: &report, regions: map.ids)
        let point = TDP.parseAnchor("F1@2.0,5.0", step: 1, report: &report, regions: map.ids)
        let resolver = Resolver(map: map)
        XCTAssertEqual(cell.map(resolver.point), SlidePoint(425, 415))
        XCTAssertEqual(point.map(resolver.point), SlidePoint(400, 400))
    }

    func testLowercaseIdsAreRepairedAndGridIsClamped() {
        let (script, report) = parse("@1 circle f1@12,3 | cap \"x\"")
        XCTAssertEqual(script.steps.first?.marks, [.circle(Anchor("F1", col: 9.99, row: 3, isCell: true))])
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(report.repairs.count, 2)
    }

    func testAnArrowFromARegionLeavesFromItsEdge() {
        let resolver = Resolver(map: map)
        let start = resolver.end(Anchor("T4"), toward: SlidePoint(430, 510), gap: 6)
        let box = map["T4"]!.box.outset(6)
        XCTAssertEqual(start.y, box.maxY, accuracy: 0.01)
        XCTAssertTrue(start.x > box.midX && start.x < box.maxX)
    }

    // MARK: Validation

    func testAnUnknownRegionDropsTheMarkNotTheStep() {
        let (script, report) = parse("@1 circle T99 ; box T3 | cap \"هذي\"")
        XCTAssertEqual(script.steps.first?.marks, [.box(Anchor("T3"))])
        XCTAssertEqual(report.errors, ["step 1: unknown region T99 (mark dropped)"])
    }

    func testAQuestionNeedsExactlyOneRightOption() {
        let (none, noneReport) = parse("@1 box T3 | ask \"كم؟\" | opts \"1\" / \"2\"")
        XCTAssertNil(none.steps.first?.ask)
        XCTAssertEqual(noneReport.errors.count, 1)

        let (two, twoReport) = parse("@1 box T3 | ask \"كم؟\" | opts *\"1\" / *\"2\"")
        XCTAssertNil(two.steps.first?.ask)
        XCTAssertEqual(twoReport.errors.count, 1)
    }

    func testAStarAfterAnOptionMarksIt() {
        let (script, _) = parse("@1 box T3 | ask \"كم؟\" | opts \"1\" / \"2\"* / \"3\" | hint \"h\" | why \"w\"")
        XCTAssertEqual(script.steps.first?.ask?.answer, 1)
    }

    func testAQuestionStepDropsItsCaptionSoItCantGiveTheAnswerAway() {
        let (script, report) = parse("@1 box T3 | cap \"الجواب 3\" | ask \"كم؟\" | opts \"1\" / *\"3\" | hint \"h\" | why \"w\"")
        XCTAssertEqual(script.steps.first?.caption, [])
        XCTAssertNotNil(script.steps.first?.ask)
        XCTAssertEqual(report.repairs, ["step 1: caption on an ask step dropped"])
    }

    func testWrappedLinesJoinTheirStep() {
        let (script, _) = parse("@1 box T3\n| cap \"أول\" / \"ثاني\"\n@2 underline T4 | cap \"ثالث\"")
        XCTAssertEqual(script.steps.count, 2)
        XCTAssertEqual(script.steps[0].caption, ["أول", "ثاني"])
    }

    func testDollarMathBecomesBackticks() {
        let (script, report) = parse("@1 box E1 | cap \"التردد $f = 2.5\\,Hz$\"")
        XCTAssertEqual(script.steps.first?.caption, ["التردد `f = 2.5 Hz`"])
        XCTAssertEqual(report.repairs.count, 1)
    }

    func testOldVerbsStillWork() {
        let (script, report) = parse("@1 hl T3 ; tex E1 \"f = 1/T\" below | cap \"x\"\n@2 box T4 | say \"y\"")
        XCTAssertEqual(script.steps[0].marks.count, 2)
        XCTAssertEqual(script.steps[1].caption, ["y"])
        XCTAssertTrue(report.repairs.contains("step 2: say -> cap"))
    }

    func testCodeFencesAndChatterAreIgnored() {
        let (script, report) = parse("```\n@v1.2 title=\"x\"\n@1 box T3 | cap \"a\"\n```")
        XCTAssertEqual(script.steps.count, 1)
        XCTAssertEqual(report.errors, [])
    }

    func testTooManyStepsAreCut() {
        let source = (1...15).map { "@\($0) box T3 | cap \"x\"" }.joined(separator: "\n")
        let (script, report) = parse(source)
        XCTAssertEqual(script.steps.count, TDP.limits.steps)
        XCTAssertEqual(report.warnings.count, 1)
    }

    // MARK: Prompt

    func testTheRequestListsEveryRegion() {
        let request = TutorPrompt.request(map: map, page: 16, deckTitle: "Lecture 5", deckPageCount: 51)
        XCTAssertTrue(request.contains("T1 [title] \"Sine Wave · Reading the Graph\""))
        XCTAssertTrue(request.contains("T9 [text, in F1] \"8 V\""))
        XCTAssertTrue(request.contains("F1 [figure, 10×10 grid]"))
        XCTAssertTrue(TutorPrompt.system.contains("@v1.2"))
    }

    func testThePromptsOwnExampleIsValidTDP() {
        let example = TutorPrompt.system.components(separatedBy: "EXAMPLE (for a different slide):").last ?? ""
        let regions: Set<String> = ["T2", "E1", "F1"]
        let (script, report) = TDP.parse(example, regions: regions)
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(script.steps.count, 5)
        XCTAssertNotNil(script.steps[2].ask)
    }
}
