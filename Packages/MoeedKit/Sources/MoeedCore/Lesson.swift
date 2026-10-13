import Foundation

/// One stroke of tutor ink, in slide space. Mirrors the TDP-L verbs from the prototype.
public enum InkMark: Hashable, Codable, Sendable {
    case circle(center: SlidePoint, rx: Double, ry: Double)
    case box(SlideRect)
    case underline(from: SlidePoint, to: SlidePoint)
    case highlight(SlideRect)
    case dot(SlidePoint)
    case arrow(from: SlidePoint, to: SlidePoint, bend: Double)
    case guide(from: SlidePoint, to: SlidePoint)
    case label(String, at: SlidePoint)
    case spot(SlideRect)
}

public extension InkMark {
    /// Spotlights belong to their own step only; everything else stays (faded) on later steps.
    var persistsAfterStep: Bool {
        if case .spot = self { return false }
        return true
    }

    /// Approximate extent, used to validate generated scripts.
    var bounds: SlideRect {
        switch self {
        case let .circle(c, rx, ry):
            return SlideRect(c.x - rx, c.y - ry, rx * 2, ry * 2)
        case let .box(r), let .highlight(r), let .spot(r):
            return r
        case let .underline(a, b), let .arrow(a, b, _), let .guide(a, b):
            return SlideRect(min(a.x, b.x), min(a.y, b.y), abs(a.x - b.x), abs(a.y - b.y))
        case let .dot(p):
            return SlideRect(p.x - 4, p.y - 4, 8, 8)
        case let .label(_, p):
            return SlideRect(p.x, p.y, 0, 0)
        }
    }
}

/// A caption phrase. Text between backticks is math/Latin and is rendered left-to-right and bold.
public struct Phrase: Hashable, Codable, Sendable {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }
}

public struct AskOption: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var label: String

    public init(_ id: String, _ label: String) {
        self.id = id
        self.label = label
    }
}

/// A predict-before-reveal question.
public struct Ask: Hashable, Codable, Sendable {
    public var question: String
    public var options: [AskOption]
    public var answerID: String
    public var hint: String
    public var why: String

    public init(question: String, options: [AskOption], answerID: String, hint: String, why: String) {
        self.question = question
        self.options = options
        self.answerID = answerID
        self.hint = hint
        self.why = why
    }
}

/// Where the caption card floats on the slide (wide layouts), and what its leader line points at.
public struct CaptionPlacement: Hashable, Codable, Sendable {
    public var card: SlideRect
    public var anchor: SlidePoint?

    public init(card: SlideRect, anchor: SlidePoint? = nil) {
        self.card = card
        self.anchor = anchor
    }
}

public struct Step: Identifiable, Hashable, Codable, Sendable {
    public var id: Int
    public var marks: [InkMark]
    public var caption: [Phrase]
    public var placement: CaptionPlacement?
    public var ask: Ask?

    public init(id: Int, marks: [InkMark], caption: [Phrase] = [], placement: CaptionPlacement? = nil, ask: Ask? = nil) {
        self.id = id
        self.marks = marks
        self.caption = caption
        self.placement = placement
        self.ask = ask
    }
}

/// One slide of a lecture with its scripted explanation.
public struct SlidePage: Identifiable, Hashable, Codable, Sendable {
    public var id: Int
    public var width: Double
    public var height: Double
    public var title: String
    public var deckTitle: String
    public var deckPageCount: Int
    public var steps: [Step]

    public init(id: Int, width: Double, height: Double, title: String, deckTitle: String, deckPageCount: Int, steps: [Step]) {
        self.id = id
        self.width = width
        self.height = height
        self.title = title
        self.deckTitle = deckTitle
        self.deckPageCount = deckPageCount
        self.steps = steps
    }

    public var bounds: SlideRect { SlideRect(0, 0, width, height) }
}

// MARK: - Library

public enum LectureStatus: Hashable, Sendable {
    case ready
    case preparing(progress: Double)
}

public struct Lecture: Identifiable, Hashable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var slideCount: Int
    public var explainedCount: Int
    public var status: LectureStatus
    public var progress: Double

    public init(id: String, number: Int, title: String, slideCount: Int, explainedCount: Int, status: LectureStatus, progress: Double) {
        self.id = id
        self.number = number
        self.title = title
        self.slideCount = slideCount
        self.explainedCount = explainedCount
        self.status = status
        self.progress = progress
    }
}

public struct Course: Identifiable, Hashable, Sendable {
    public var id: String { code }
    public var code: String
    public var name: String
    public var lectures: [Lecture]

    public init(code: String, name: String, lectures: [Lecture]) {
        self.code = code
        self.name = name
        self.lectures = lectures
    }
}

public struct ResumePoint: Hashable, Sendable {
    public var lecture: Lecture
    public var page: Int
    public var step: Int
    public var stepCount: Int
    public var stepTitle: String
    public var askCount: Int

    public init(lecture: Lecture, page: Int, step: Int, stepCount: Int, stepTitle: String, askCount: Int) {
        self.lecture = lecture
        self.page = page
        self.step = step
        self.stepCount = stepCount
        self.stepTitle = stepTitle
        self.askCount = askCount
    }
}

/// A prediction the student got wrong, queued for review.
public struct ReviewItem: Identifiable, Hashable, Sendable {
    public var id: Int
    public var lectureNumber: Int
    public var page: Int
    public var question: String
    public var yourAnswer: String
    public var correctAnswer: String
    public var focus: SlidePoint

    public init(id: Int, lectureNumber: Int, page: Int, question: String, yourAnswer: String, correctAnswer: String, focus: SlidePoint) {
        self.id = id
        self.lectureNumber = lectureNumber
        self.page = page
        self.question = question
        self.yourAnswer = yourAnswer
        self.correctAnswer = correctAnswer
        self.focus = focus
    }
}

// MARK: - Import pipeline

public enum ImportStage: Int, CaseIterable, Comparable, Sendable {
    case reading, regions, scripting, verifying

    public static func < (lhs: ImportStage, rhs: ImportStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum SlideJobState: Hashable, Sendable {
    case ready, writing, waiting
}

public struct ImportJob: Hashable, Sendable {
    public var fileName: String
    public var courseCode: String
    public var slideCount: Int
    public var stage: ImportStage
    public var scripted: Int

    public init(fileName: String, courseCode: String, slideCount: Int, stage: ImportStage, scripted: Int) {
        self.fileName = fileName
        self.courseCode = courseCode
        self.slideCount = slideCount
        self.stage = stage
        self.scripted = scripted
    }

    /// Slides are scripted in order; one is in progress while scripting.
    public func state(ofSlide number: Int) -> SlideJobState {
        if number <= scripted { return .ready }
        if number == scripted + 1 && stage == .scripting { return .writing }
        return .waiting
    }
}
