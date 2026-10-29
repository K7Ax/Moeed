import Foundation

/// Turns a parsed TDP script into a lesson the player can run: region ids become geometry,
/// options get ids, captions get a free corner of the slide, and every stroke is kept on the page.
public enum LessonCompiler {
    public static func compile(
        _ script: TDPScript,
        map: RegionMap,
        page number: Int,
        deckTitle: String,
        deckPageCount: Int,
        report: inout TDPReport
    ) -> SlidePage {
        let resolver = Resolver(map: map)
        var steps: [Step] = []
        for source in script.steps {
            let marks = source.marks.map { resolver.keep(resolver.mark($0), report: &report, step: source.number) }
            let ask = source.ask.map(makeAsk)
            let caption = ask == nil ? source.caption.map(Phrase.init) : []
            guard !marks.isEmpty || !caption.isEmpty || ask != nil else {
                report.warnings.append("step \(source.number): empty after checking (dropped)")
                continue
            }
            let placement = CaptionPlacement(card: resolver.freeCorner(avoiding: marks), anchor: marks.first.flatMap(focus))
            steps.append(Step(id: steps.count + 1, marks: marks, caption: caption, placement: placement, ask: ask))
        }
        return SlidePage(
            id: number,
            width: map.width,
            height: map.height,
            title: script.header["title"] ?? map.title ?? "",
            deckTitle: deckTitle,
            deckPageCount: deckPageCount,
            steps: steps
        )
    }

    /// Parses and compiles in one go: what the streaming tutor calls after each finished line.
    public static func compile(
        source: String,
        map: RegionMap,
        page number: Int,
        deckTitle: String,
        deckPageCount: Int
    ) -> (page: SlidePage, report: TDPReport) {
        let parsed = TDP.parse(source, regions: map.ids)
        var report = parsed.1
        let lesson = compile(parsed.0, map: map, page: number, deckTitle: deckTitle, deckPageCount: deckPageCount, report: &report)
        return (lesson, report)
    }

    static let optionIDs = ["a", "b", "c", "d"]

    static func makeAsk(_ source: TDPAsk) -> Ask {
        let options = source.options.enumerated().map { AskOption(optionIDs[$0.offset], $0.element) }
        return Ask(question: source.question, options: options, answerID: optionIDs[source.answer], hint: source.hint, why: source.why)
    }

    /// The point a mark draws the eye to, which is where the answer ring goes after a question.
    static func focus(_ mark: InkMark) -> SlidePoint? {
        switch mark {
        case let .circle(center, _, _): center
        case let .box(r), let .highlight(r): r.center
        case let .underline(a, b): SlidePoint((a.x + b.x) / 2, (a.y + b.y) / 2)
        case let .dot(p), let .label(_, p): p
        case let .arrow(_, b, _), let .guide(_, b): b
        case .spot: nil
        }
    }
}

/// Region ids to slide geometry. Sizes are tuned on an 800-wide slide and scale with the page.
struct Resolver {
    let map: RegionMap
    var unit: Double { map.width / 800 }

    func rect(_ a: Anchor) -> SlideRect {
        map[a.region]?.box ?? map.bounds
    }

    func point(_ a: Anchor) -> SlidePoint {
        let box = rect(a)
        guard let col = a.col, let row = a.row else { return box.center }
        let offset = a.isCell ? 0.5 : 0
        return SlidePoint(box.x + box.w * (col + offset) / RegionMap.grid, box.y + box.h * (row + offset) / RegionMap.grid)
    }

    /// What an outline goes around: the region, or a small area around a grid point.
    func area(_ a: Anchor) -> SlideRect {
        guard a.hasPoint else { return rect(a) }
        let p = point(a)
        let r = 22 * unit
        return SlideRect(p.x - r, p.y - r * 0.8, 2 * r, 1.6 * r)
    }

    /// Where a line to or from `a` should stop: the grid point itself, or just off the region's edge facing `target`.
    func end(_ a: Anchor, toward target: SlidePoint, gap: Double) -> SlidePoint {
        if a.hasPoint { return point(a) }
        let box = rect(a).outset(gap)
        let c = box.center
        let dx = target.x - c.x
        let dy = target.y - c.y
        if box.contains(target) { return c }
        let tx = dx == 0 ? Double.infinity : (box.w / 2) / abs(dx)
        let ty = dy == 0 ? Double.infinity : (box.h / 2) / abs(dy)
        let t = min(tx, ty)
        return SlidePoint(c.x + dx * t, c.y + dy * t)
    }

    func mark(_ mark: TDPMark) -> InkMark {
        let u = unit
        switch mark {
        case let .spot(a):
            return .spot(area(a))
        case let .highlight(a):
            return .highlight(area(a))
        case let .box(a):
            return .box(area(a).outset(5 * u))
        case let .circle(a):
            if a.hasPoint { return .circle(center: point(a), rx: 26 * u, ry: 22 * u) }
            let r = rect(a)
            return .circle(center: r.center, rx: r.w / 2 + 14 * u, ry: r.h / 2 + 10 * u)
        case let .underline(a):
            let r = area(a)
            let y = r.maxY + 4 * u
            return .underline(from: SlidePoint(r.x, y), to: SlidePoint(r.maxX, y))
        case let .dot(a):
            return .dot(point(a))
        case let .arrow(a, b):
            let start = end(a, toward: point(b), gap: 6 * u)
            let finish = end(b, toward: point(a), gap: 8 * u)
            // Measuring arrows between two exact points run straight; pointers curve a little.
            return .arrow(from: start, to: finish, bend: a.hasPoint && b.hasPoint ? 0 : -0.18)
        case let .guide(a, b):
            return .guide(from: point(a), to: point(b))
        case let .label(text, a, side):
            let box = a.hasPoint ? SlideRect(point(a).x, point(a).y, 0, 0) : rect(a)
            let half = Double(text.count) * 6.5 * u + 4 * u
            let at: SlidePoint = switch side {
            case .above: SlidePoint(box.midX, box.y - 20 * u)
            case .below: SlidePoint(box.midX, box.maxY + 20 * u)
            case .left: SlidePoint(box.x - half - 8 * u, box.midY)
            case .right: SlidePoint(box.maxX + half + 8 * u, box.midY)
            case .at: a.hasPoint ? box.center : SlidePoint(box.midX, box.y - 20 * u)
            }
            let x = min(max(at.x, half), map.width - half)
            let y = min(max(at.y, 16 * u), map.height - 16 * u)
            return .label(text, at: SlidePoint(x, y))
        }
    }

    /// The mark moved onto the page if any of it fell off.
    func keep(_ mark: InkMark, report: inout TDPReport, step: Int) -> InkMark {
        let page = map.bounds
        func p(_ point: SlidePoint) -> SlidePoint { page.clamped(point) }
        let kept: InkMark = switch mark {
        case let .circle(c, rx, ry):
            .circle(center: SlidePoint(min(max(c.x, rx), page.maxX - rx), min(max(c.y, ry), page.maxY - ry)), rx: min(rx, page.w / 2), ry: min(ry, page.h / 2))
        case let .box(r): .box(r.kept(in: page))
        case let .highlight(r): .highlight(r.kept(in: page))
        case let .spot(r): .spot(r.kept(in: page))
        case let .underline(a, b): .underline(from: p(a), to: p(b))
        case let .dot(c): .dot(p(c))
        case let .arrow(a, b, bend): .arrow(from: p(a), to: p(b), bend: bend)
        case let .guide(a, b): .guide(from: p(a), to: p(b))
        case let .label(text, at): .label(text, at: p(at))
        }
        if kept != mark { report.repairs.append("step \(step): ink moved onto the slide") }
        return kept
    }

    /// The corner where a caption card covers the least of the slide's content and this step's ink.
    func freeCorner(avoiding marks: [InkMark]) -> SlideRect {
        let w = map.width * 0.39
        let h = map.height * 0.17
        let m = map.width * 0.05
        let corners = [
            SlideRect(map.width - w - m, m * 1.4, w, h),
            SlideRect(m, map.height - h - m, w, h),
            SlideRect(map.width - w - m, map.height - h - m, w, h),
            SlideRect(m, m * 1.4, w, h),
        ]
        let busy = map.regions.filter { $0.kind != .figure }.map(\.box) + marks.map(\.bounds)
        let figures = map.regions.filter { $0.kind == .figure }.map(\.box)
        func cost(_ card: SlideRect) -> Double {
            busy.reduce(0) { $0 + card.overlap($1) } + figures.reduce(0) { $0 + card.overlap($1) * 0.6 }
        }
        return corners.min { cost($0) < cost($1) } ?? corners[0]
    }
}
