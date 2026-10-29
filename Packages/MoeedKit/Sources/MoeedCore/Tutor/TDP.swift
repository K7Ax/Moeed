import Foundation

// TDP-L v1.2, the Tutor Drawing Protocol in its line form. One step per line:
//
//     @v1.2 title="قراءة القيمة اللحظية" lang=ar
//     @1 circle F1@1.4,1.3 ; box T3 | cap "هذي القمة" / "قيمتها `Vp = 8 V`"
//     @2 guide F1@2.6,5 -> F1@2.6,9.9 | ask "كم قيمتها عند `0.3 s`؟" | opts "8 V" / "0 V" / *"−8 V" | hint "…" | why "…"
//
// The model only picks region ids, words and a few parameters; the compiler turns them into geometry.
// Anchors are T#, E#, F#, or ID@col,row on the region's 10 × 10 grid: whole numbers name a cell
// (its centre), decimals an exact point. A line without `@n` continues the step before it.

/// A place on the slide, named by region.
public struct Anchor: Hashable, Sendable {
    public var region: String
    public var col: Double?
    public var row: Double?
    /// Whole-number grid coordinates name a cell, so the point is the cell's centre.
    public var isCell: Bool

    public init(_ region: String, col: Double? = nil, row: Double? = nil, isCell: Bool = false) {
        self.region = region
        self.col = col
        self.row = row
        self.isCell = isCell
    }

    public var hasPoint: Bool { col != nil && row != nil }
}

public enum LabelSide: String, Hashable, Sendable {
    case above, below, left, right, at
}

public enum TDPMark: Hashable, Sendable {
    case spot(Anchor)
    case highlight(Anchor)
    case box(Anchor)
    case circle(Anchor)
    case underline(Anchor)
    case dot(Anchor)
    case arrow(Anchor, Anchor)
    case guide(Anchor, Anchor)
    case label(String, Anchor, LabelSide)
}

public struct TDPAsk: Hashable, Sendable {
    public var question: String
    public var options: [String]
    public var answer: Int
    public var hint: String
    public var why: String
}

public struct TDPStep: Hashable, Sendable {
    public var number: Int
    public var marks: [TDPMark] = []
    public var caption: [String] = []
    public var ask: TDPAsk?
    /// Ask clauses collected while parsing, checked once the whole step is read.
    var draft = AskDraft()

    public init(number: Int, marks: [TDPMark] = [], caption: [String] = [], ask: TDPAsk? = nil) {
        self.number = number
        self.marks = marks
        self.caption = caption
        self.ask = ask
    }

    public static func == (a: TDPStep, b: TDPStep) -> Bool {
        a.number == b.number && a.marks == b.marks && a.caption == b.caption && a.ask == b.ask
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(marks)
        hasher.combine(caption)
        hasher.combine(ask)
    }
}

struct AskDraft: Hashable, Sendable {
    var question: String?
    var options: [String] = []
    var answers: [Int] = []
    var hint: String?
    var why: String?
}

public struct TDPScript: Hashable, Sendable {
    public var version: String = ""
    public var header: [String: String] = [:]
    public var steps: [TDPStep] = []

    public init(version: String = "", header: [String: String] = [:], steps: [TDPStep] = []) {
        self.version = version
        self.header = header
        self.steps = steps
    }
}

/// What the validator found. Errors drop the broken part (never guess a region: a wrong highlight
/// costs more trust than a missing one); warnings are style limits; repairs are fixes it made.
public struct TDPReport: Hashable, Sendable {
    public var errors: [String] = []
    public var warnings: [String] = []
    public var repairs: [String] = []

    public init() {}

    public var isClean: Bool { errors.isEmpty }
}

public enum TDP {
    public static let version = "1.2"
    public static let limits = (steps: 12, marks: 3, phrases: 3, words: 16)

    enum Token: Equatable {
        case string(String)
        case arrow, semicolon, bar, slash, equals, star
        case word(String)
    }

    /// Parses a script, keeping every mark whose regions exist in `regions`.
    public static func parse(_ source: String, regions: Set<String>) -> (TDPScript, TDPReport) {
        var report = TDPReport()
        var script = TDPScript()

        for (lineNumber, raw) in source.components(separatedBy: .newlines).enumerated() {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("@v") {
                parseHeader(line, into: &script)
                continue
            }

            var number: Int
            if line.hasPrefix("@") {
                let digits = line.dropFirst().prefix(while: \.isNumber)
                guard let n = Int(digits) else {
                    report.errors.append("line \(lineNumber + 1): not a step")
                    continue
                }
                number = n
                line = String(line.dropFirst(1 + digits.count))
            } else if let last = script.steps.last {
                // Models often wrap long steps onto a second line.
                number = last.number
            } else {
                report.errors.append("line \(lineNumber + 1): not a step")
                continue
            }

            var step = script.steps.last?.number == number ? script.steps.removeLast() : TDPStep(number: number)
            let toks = tokens(line, report: &report)
            parseBody(toks, into: &step, report: &report, regions: regions)
            script.steps.append(step)
        }

        for index in script.steps.indices {
            finish(&script.steps[index], report: &report)
        }
        if script.steps.count > limits.steps {
            report.warnings.append("\(script.steps.count) steps > \(limits.steps) (extra steps dropped)")
            script.steps = Array(script.steps.prefix(limits.steps))
        }
        return (script, report)
    }

    // MARK: Lines

    private static func parseHeader(_ line: String, into script: inout TDPScript) {
        var dummy = TDPReport()
        let toks = tokens(line, report: &dummy)
        if case let .word(first)? = toks.first { script.version = String(first.dropFirst(2)) }
        var i = 1
        while i < toks.count {
            if case let .word(key) = toks[i], i + 2 < toks.count, toks[i + 1] == .equals {
                switch toks[i + 2] {
                case let .string(value), let .word(value): script.header[key] = value
                default: break
                }
                i += 3
            } else {
                i += 1
            }
        }
    }

    private static func parseBody(_ toks: [Token], into step: inout TDPStep, report: inout TDPReport, regions: Set<String>) {
        let n = step.number
        let clauses = toks.split(separator: .bar, omittingEmptySubsequences: true).map(Array.init)
        for (index, clause) in clauses.enumerated() {
            let keyword = word(clause.first)?.lowercased()
            switch keyword {
            case "cap", "say", "caption":
                if keyword != "cap" { report.repairs.append("step \(step.number): \(keyword ?? "") -> cap") }
                step.caption += strings(clause.dropFirst()).map { mathMarks($0, step: n, report: &report) }
            case "ask":
                step.draft.question = strings(clause.dropFirst()).first.map { mathMarks($0, step: n, report: &report) }
            case "opts", "options", "choices":
                let body = Array(clause.dropFirst())
                for (i, token) in body.enumerated() {
                    switch token {
                    case let .string(text):
                        step.draft.options.append(mathMarks(text, step: n, report: &report))
                    case .star:
                        // A star marks the option right after it, or the one just before when none follows.
                        if i + 1 < body.count, case .string = body[i + 1] {
                            step.draft.answers.append(step.draft.options.count)
                        } else if !step.draft.options.isEmpty {
                            step.draft.answers.append(step.draft.options.count - 1)
                        }
                    default:
                        break
                    }
                }
            case "hint":
                step.draft.hint = strings(clause.dropFirst()).first.map { mathMarks($0, step: n, report: &report) }
            case "why":
                step.draft.why = strings(clause.dropFirst()).first.map { mathMarks($0, step: n, report: &report) }
            default:
                if index > 0 && clause.first != nil {
                    report.errors.append("step \(step.number): unknown clause after '|'")
                    continue
                }
                for mark in clause.split(separator: .semicolon, omittingEmptySubsequences: true) {
                    if let parsed = parseMark(Array(mark), step: n, report: &report, regions: regions) {
                        step.marks.append(parsed)
                    }
                }
            }
        }
    }

    private static func finish(_ step: inout TDPStep, report: inout TDPReport) {
        let where_ = "step \(step.number)"
        let draft = step.draft
        if let question = draft.question {
            if draft.options.count < 2 || draft.options.count > 4 {
                report.errors.append("\(where_): ask needs 2–4 options (ask dropped)")
            } else if draft.answers.count != 1 {
                report.errors.append("\(where_): ask needs exactly one option marked * (ask dropped)")
            } else {
                if draft.hint == nil { report.warnings.append("\(where_): ask has no hint") }
                if draft.why == nil { report.warnings.append("\(where_): ask has no why") }
                step.ask = TDPAsk(question: question, options: draft.options, answer: draft.answers[0], hint: draft.hint ?? "", why: draft.why ?? "")
                if !step.caption.isEmpty {
                    // A caption would say the answer before the student guesses.
                    report.repairs.append("\(where_): caption on an ask step dropped")
                    step.caption = []
                }
            }
        } else if !draft.options.isEmpty {
            report.errors.append("\(where_): options without a question (dropped)")
        }

        if step.marks.count > limits.marks {
            report.warnings.append("\(where_): \(step.marks.count) marks > \(limits.marks)")
        }
        if step.caption.count > limits.phrases {
            report.warnings.append("\(where_): \(step.caption.count) phrases > \(limits.phrases)")
        }
        let words = step.caption.map(wordCount).reduce(0, +)
        if words > limits.words {
            report.warnings.append("\(where_): \(words) words > \(limits.words)")
        }
        if step.ask == nil {
            if step.caption.isEmpty { report.warnings.append("\(where_): no caption") }
            if step.marks.isEmpty { report.warnings.append("\(where_): no ink") }
        }
    }

    // MARK: Marks

    private static func parseMark(_ toks: [Token], step: Int, report: inout TDPReport, regions: Set<String>) -> TDPMark? {
        let where_ = "step \(step)"
        guard case let .word(rawVerb)? = toks.first else {
            report.errors.append("\(where_): mark without a verb")
            return nil
        }
        var verb = rawVerb.lowercased()
        let aliases = ["hl": "highlight", "tex": "label", "line": "guide", "ellipse": "circle", "ring": "circle", "point": "dot"]
        if let canonical = aliases[verb] {
            if verb != "hl" { report.repairs.append("\(where_): \(verb) -> \(canonical)") }
            verb = canonical
        }
        let rest = Array(toks.dropFirst())
        let words = rest.compactMap { word($0) }
        let texts = strings(rest[...])

        func anchor(_ raw: String) -> Anchor? {
            parseAnchor(raw, step: step, report: &report, regions: regions)
        }

        switch verb {
        case "clear":
            // Earlier ink already fades on its own; nothing to do.
            return nil
        case "ask":
            report.errors.append("\(where_): ask goes after '|' (| ask \"…\" | opts …)")
            return nil
        case "arrow", "guide":
            guard rest.contains(.arrow), words.count >= 2 else {
                report.errors.append("\(where_): \(verb) needs A -> B")
                return nil
            }
            guard let a = anchor(words[0]), let b = anchor(words[1]) else { return nil }
            return verb == "arrow" ? .arrow(a, b) : .guide(a, b)
        case "spot", "highlight", "box", "circle", "underline", "dot", "label":
            guard let target = words.first else {
                report.errors.append("\(where_): \(verb) needs a target")
                return nil
            }
            guard let a = anchor(target) else { return nil }
            switch verb {
            case "spot": return .spot(a)
            case "highlight": return .highlight(a)
            case "box": return .box(a)
            case "circle": return .circle(a)
            case "underline": return .underline(a)
            case "dot": return .dot(a)
            default:
                guard let text = texts.first else {
                    report.errors.append("\(where_): label needs a quoted text")
                    return nil
                }
                let side = words.dropFirst().compactMap { LabelSide(rawValue: $0.lowercased()) }.first ?? .at
                return .label(text.replacingOccurrences(of: "`", with: ""), a, side)
            }
        default:
            report.errors.append("\(where_): unknown verb '\(rawVerb)' (mark dropped)")
            return nil
        }
    }

    static func parseAnchor(_ raw: String, step: Int, report: inout TDPReport, regions: Set<String>) -> Anchor? {
        let where_ = "step \(step)"
        let parts = raw.split(separator: "@", maxSplits: 1).map(String.init)
        let name = parts[0]
        guard let letter = name.first, "TEFtef".contains(letter), let number = Int(name.dropFirst()) else {
            report.errors.append("\(where_): bad anchor '\(raw)'")
            return nil
        }
        let id = "\(letter.uppercased())\(number)"
        guard regions.contains(id) else {
            report.errors.append("\(where_): unknown region \(id) (mark dropped)")
            return nil
        }
        if name != id { report.repairs.append("\(where_): '\(name)' -> \(id)") }
        guard parts.count == 2 else { return Anchor(id) }

        let grid = parts[1].split(separator: ",").map(String.init)
        guard grid.count == 2, var col = Double(grid[0]), var row = Double(grid[1]) else {
            report.errors.append("\(where_): bad grid point '\(raw)'")
            return nil
        }
        if !(0..<RegionMap.grid).contains(col) || !(0..<RegionMap.grid).contains(row) {
            report.repairs.append("\(where_): grid \(parts[1]) clamped")
            col = min(max(col, 0), 9.99)
            row = min(max(row, 0), 9.99)
        }
        return Anchor(id, col: col, row: row, isCell: !grid[0].contains(".") && !grid[1].contains("."))
    }

    // MARK: Tokens

    static func word(_ token: Token?) -> String? {
        if case let .word(w)? = token { return w }
        return nil
    }

    /// Words in a phrase, counting each math span as one.
    static func wordCount(_ phrase: String) -> Int {
        var count = 0
        for (index, part) in phrase.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
            count += index % 2 == 1 ? 1 : part.split(separator: " ").count
        }
        return count
    }

    static func strings(_ toks: ArraySlice<Token>) -> [String] {
        toks.compactMap { token in
            if case let .string(s) = token {
                let trimmed = s.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }
    }

    /// Math goes between backticks. Models often reach for `$…$` and LaTeX spacing instead.
    static func mathMarks(_ text: String, step: Int, report: inout TDPReport) -> String {
        guard text.contains("$") || text.contains("\\,") else { return text }
        report.repairs.append("step \(step): $…$ -> `…`")
        return text
            .replacingOccurrences(of: "$", with: "`")
            .replacingOccurrences(of: "\\,", with: " ")
    }

    static func tokens(_ line: String, report: inout TDPReport) -> [Token] {
        let closing: [Character: Character] = ["\"": "\"", "“": "”", "«": "»", "”": "”"]
        let specials: Set<Character> = [";", "|", "/", "=", "*", "\"", "“", "«", "”", "→"]
        let chars = Array(line)
        var out: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace {
                i += 1
            } else if let close = closing[c] {
                var text = ""
                i += 1
                while i < chars.count, chars[i] != close {
                    if chars[i] == "\\", i + 1 < chars.count, chars[i + 1] == close {
                        text.append(close)
                        i += 2
                    } else {
                        text.append(chars[i])
                        i += 1
                    }
                }
                i += 1
                out.append(.string(text))
            } else if c == "→" || (c == "-" && i + 1 < chars.count && chars[i + 1] == ">") {
                out.append(.arrow)
                i += c == "→" ? 1 : 2
            } else if c == ";" { out.append(.semicolon); i += 1 }
            else if c == "|" { out.append(.bar); i += 1 }
            else if c == "/" { out.append(.slash); i += 1 }
            else if c == "=" { out.append(.equals); i += 1 }
            else if c == "*" { out.append(.star); i += 1 }
            else {
                var word = ""
                while i < chars.count, !chars[i].isWhitespace, !specials.contains(chars[i]),
                      !(chars[i] == "-" && i + 1 < chars.count && chars[i + 1] == ">") {
                    word.append(chars[i])
                    i += 1
                }
                out.append(.word(word))
            }
        }
        return out
    }
}
