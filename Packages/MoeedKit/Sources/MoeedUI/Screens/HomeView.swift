import MoeedCore
import SwiftUI

/// «الأصلي»'s home: the lecture you're in, playing in the player's own light; this week as rings;
/// the course as a shelf of covers; the next lecture being prepared, live; and the questions
/// waiting for review. A sidebar on a wide iPad, a tab bar on a narrow one, and a mini player
/// over both.
public struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var tab: HomeTab = .home
    @State private var offset: CGFloat = 0
    private let now: Date

    public init(now: Date = Date()) {
        self.now = now
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            Group {
                if wide {
                    HStack(alignment: .top, spacing: 0) {
                        HomeSidebar(tab: tab, select: select)
                        main(width: min(1040, geo.size.width - HomeSidebar.width) - 80, wide: true)
                    }
                } else {
                    VStack(spacing: 0) {
                        main(width: geo.size.width - 32, wide: false)
                        HomeTabBar(tab: tab, select: select)
                    }
                }
            }
        }
        .background(Palette.bg)
        .environment(\.inkColor, Stage.pen)
        .modifier(MotionPolicy())
    }

    private func main(width: CGFloat, wide: Bool) -> some View {
        ZStack(alignment: .bottom) {
            scroller(width: width, wide: wide)
            compactBar
            MiniPlayer(open: play)
                .padding(.horizontal, wide ? 40 : 8)
                .padding(.bottom, wide ? 18 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func scroller(width: CGFloat, wide: Bool) -> some View {
        let content = sections(width: width, wide: wide)
            .padding(.horizontal, wide ? 40 : 16)
            .padding(.top, wide ? 26 : 10)
            .padding(.bottom, wide ? 130 : 110)
            .frame(maxWidth: wide ? 1040 : .infinity)
            .frame(maxWidth: .infinity)
        if isSnapshot {
            // A screenshot shows the top of the page; the rest hangs below the frame and is cut.
            Color.clear
                .overlay(alignment: .top) { content }
                .clipped()
        } else {
            ScrollView {
                content.background {
                    GeometryReader { g in
                        Color.clear.preference(key: HomeScrollKey.self, value: -g.frame(in: .named("home")).minY)
                    }
                }
            }
            .coordinateSpace(name: "home")
            .onPreferenceChange(HomeScrollKey.self) { offset = $0 }
        }
    }

    private func sections(width: CGFloat, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(wide: wide).rise(0)
            NowCard(width: width, wide: wide, play: play)
                .padding(.top, 12)
                .rise(0.09)
            VStack(alignment: .leading, spacing: 0) {
                SectionHead("هالأسبوع", action: "التفاصيل") {}
                WeekCard(week: Samples.week, today: weekday, width: width, wide: wide)
            }
            .rise(0.18)
            VStack(alignment: .leading, spacing: 0) {
                SectionHead(Samples.course.name, action: "عرض الكل") { select(.library) }
                Shelf(size: wide ? 164 : 136, width: width, open: play)
            }
            .rise(0.26)
            VStack(alignment: .leading, spacing: 0) {
                SectionHead("الجاية", top: 26)
                Preparing(wide: wide)
            }
            .rise(0.33)
            VStack(alignment: .leading, spacing: 0) {
                SectionHead("للمراجعة · \((Samples.reviewItems.count + 2).figures)", action: "ابدأ المراجعة") { select(.review) }
                ReviewList(limit: wide ? 4 : 3) { select(.review) }
                Text("الأسئلة اللي غلطت فيها ترجع لك هنا، كل وحدة مع مكانها في السلايد.")
                    .font(Typeface.plex(13))
                    .foregroundStyle(Palette.text2)
                    .padding(.top, 8)
                    .padding(.horizontal, 4)
            }
            .rise(0.4)
        }
    }

    private func header(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: HomeDate.line(now))
                .font(Typeface.plex(13, .semibold))
                .foregroundStyle(Palette.text2)
            HStack {
                Text("الرئيسية")
                    .font(Typeface.plex(36, .bold))
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                if !wide { BrandLogo(size: 32) }
            }
        }
    }

    /// The small title that settles in once the large one scrolls away.
    private var compactBar: some View {
        let shown = min(1, max(0, (offset - 40) / 30))
        return VStack(spacing: 0) {
            Text("الرئيسية")
                .font(Typeface.plex(17, .semibold))
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Palette.bar)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.sep).frame(height: 0.5) }
            Spacer(minLength: 0)
        }
        .opacity(shown)
        .allowsHitTesting(false)
    }

    private var weekday: Int {
        Calendar(identifier: .gregorian).component(.weekday, from: now) - 1
    }

    private func play() {
        router.route = .player
    }

    private func select(_ next: HomeTab) {
        tab = next
        switch next {
        case .home: break
        case .library: router.route = .library
        case .review: router.route = .review
        case .importing: router.route = .importing
        }
    }
}

private struct HomeScrollKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Words

enum HomeDate {
    static let days = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    static let letters = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
    static let months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    static let ordinals = ["الأولى", "الثانية", "الثالثة", "الرابعة", "الخامسة", "السادسة", "السابعة", "الثامنة", "التاسعة", "العاشرة", "الحادية عشرة", "الثانية عشرة"]

    /// Today, Gregorian and Umm al-Qura: «الجمعة، 16 أكتوبر · 4 جمادى الأولى».
    static func line(_ date: Date) -> String {
        let gregorian = Calendar(identifier: .gregorian)
        let parts = gregorian.dateComponents([.weekday, .day, .month], from: date)
        var line = "\(days[(parts.weekday ?? 1) - 1])، \((parts.day ?? 1).figures) \(months[(parts.month ?? 1) - 1])"
        let hijri = DateFormatter()
        hijri.calendar = Calendar(identifier: .islamicUmmAlQura)
        hijri.locale = Locale(identifier: "ar@numbers=latn")
        hijri.dateFormat = "d MMMM"
        let h = hijri.string(from: date).replacingOccurrences(of: "هـ", with: "").trimmingCharacters(in: .whitespaces)
        if !h.isEmpty { line += " · " + h.figures }
        return line
    }

    static func ordinal(_ n: Int) -> String {
        n >= 1 && n <= ordinals.count ? ordinals[n - 1] : n.figures
    }
}

// MARK: - Section head

private struct SectionHead: View {
    let title: String
    var action: String?
    var top: CGFloat
    var onAction: () -> Void

    init(_ title: String, action: String? = nil, top: CGFloat = 38, onAction: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
        self.top = top
        self.onAction = onAction
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
                .font(Typeface.plex(22, .bold))
                .foregroundStyle(Palette.text)
            Spacer(minLength: 8)
            if let action {
                Button(action: onAction) {
                    HStack(spacing: 2) {
                        Text(verbatim: action).font(Typeface.plex(16))
                        Image(systemName: "chevron.forward").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Palette.accent)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.press(0.94))
            }
        }
        .padding(.top, top)
        .padding(.bottom, 12)
    }
}

// MARK: - Now playing

/// The lecture you're in, in the player's own light, its slide still being inked.
private struct NowCard: View {
    let width: CGFloat
    let wide: Bool
    let play: () -> Void

    private var art: CGFloat {
        wide ? (min(440, (width - 52 - 30) * 0.52)).rounded() : width - 36
    }

    var body: some View {
        let layout = wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 30)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
        layout {
            Button(action: play) {
                LiveArtwork()
                    .frame(width: art)
                    .clipShape(RoundedRectangle(cornerRadius: wide ? 14 : 12, style: .continuous))
            }
            .buttonStyle(.press(0.98))
            .tilt(radius: wide ? 14 : 12)
            .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
            meta
        }
        .padding(wide ? 26 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Ambient(dim: 0.9) }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private var meta: some View {
        let resume = Samples.resume
        let lecture = resume.lecture
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Pulse(color: Stage.mint, size: 7)
                Text("أكمل من حيث وقفت")
                    .font(Typeface.plex(13, .semibold))
                    .foregroundStyle(Stage.mint)
            }
            Text(verbatim: lecture.arabicTitle)
                .font(Typeface.plex(wide ? 32 : 26, .bold))
                .foregroundStyle(.white)
                .padding(.top, 6)
            Text(verbatim: "المحاضرة \(HomeDate.ordinal(lecture.number)) · صفحة \(resume.page.figures) من \(lecture.slideCount.figures)")
                .font(Typeface.plex(15))
                .foregroundStyle(.white.opacity(0.62))
            Pips(count: resume.stepCount, at: resume.step - 1)
                .padding(.top, 16)
            Text(verbatim: "الخطوة \(resume.step.figures) من \(resume.stepCount.figures): \(resume.stepTitle)")
                .font(Typeface.plex(15))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.top, 10)
            HStack(spacing: 10) {
                Tween(target: lecture.progress, duration: 1.2, delay: 0.5) { v in
                    Ring(value: v, stroke: 3, color: .fixed(Stage.mint), track: .fixed(.white.opacity(0.18)))
                }
                .frame(width: 22, height: 22)
                HStack(spacing: 0) {
                    Count(to: Int((lecture.progress * 100).rounded()), delay: 0.5, suffix: "%")
                        .font(Typeface.plex(13, .semibold))
                        .foregroundStyle(.white)
                    Text(" من المحاضرة · باقي تقريبًا 25 دقيقة")
                        .font(Typeface.plex(13))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(.top, 8)
            HStack(spacing: 10) {
                PillButton(label: "أكمل", glyph: "play.fill", background: .white, foreground: .black, action: play)
                PillButton(label: "من أولها", background: .white.opacity(0.14), foreground: .white, action: play)
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The slide with its earlier ink kept, and the current step's ink writing itself again and again.
struct LiveArtwork: View {
    @Environment(\.motionOff) private var motionOff
    @State private var drawn = false

    init() {}

    private static let page = Samples.sinePage
    static let pastInk: [InkMark] = page.steps.prefix(4).filter { $0.ask == nil }.flatMap(\.marks)
    private static let liveInk: [InkMark] = page.steps[4].marks.filter(\.persistsAfterStep)

    var body: some View {
        SlideStage(page: Self.page, pastMarks: Self.pastInk, marks: Self.liveInk, drawn: drawn || motionOff)
            .task {
                guard !motionOff else { return }
                while !Task.isCancelled {
                    drawn = false
                    try? await Task.sleep(for: .milliseconds(80))
                    drawn = true
                    try? await Task.sleep(for: .seconds(5.6))
                }
            }
    }
}

/// The lecture's steps as segments: the done ones full, the one you're on breathing.
private struct Pips: View {
    let count: Int
    let at: Int
    @Environment(\.motionOff) private var motionOff

    var body: some View {
        TimelineView(.animation(paused: motionOff)) { timeline in
            let f = motionOff ? 0.5 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
            let breath = 0.35 + 0.65 * (1 - abs(2 * f - 1))
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { k in
                    Capsule()
                        .fill(.white.opacity(k < at ? 0.9 : 0.18))
                        .overlay { if k == at { Capsule().fill(Stage.mint).opacity(breath) } }
                        .frame(height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PillButton: View {
    let label: String
    var glyph: String?
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let glyph { Image(systemName: glyph).font(.system(size: 15, weight: .bold)) }
                Text(verbatim: label).font(Typeface.plex(17, .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background(background, in: Capsule())
        }
        .buttonStyle(.press(0.95, radius: 23))
    }
}

// MARK: - This week

/// This week as rings, one a day, the way Fitness shows a week; today ringed in the tutor's ink.
private struct WeekCard: View {
    let week: StudyWeek
    let today: Int
    let width: CGFloat
    let wide: Bool

    var body: some View {
        let sofar = week.sofar(today: today)
        let streak = week.streak(today: today)
        let inner = width - 36 - 56 - 0.5
        Group {
            if wide {
                HStack(spacing: 28) {
                    days(sofar).frame(width: inner * 1.3 / 2.3)
                    Rectangle().fill(Palette.sep).frame(width: 0.5)
                    stats(sofar: sofar, streak: streak)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 20) {
                    days(sofar)
                    stats(sofar: sofar, streak: streak)
                }
            }
        }
        .padding(18)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func days(_ sofar: [Int?]) -> some View {
        HStack(spacing: 0) {
            ForEach(sofar.indices, id: \.self) { k in
                if k > 0 { Spacer(minLength: 0) }
                Day(index: k, minutes: sofar[k], goal: week.goal, today: k == today)
            }
        }
    }

    private func stats(sofar: [Int?], streak: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            stat(week.total(today: today), "دقيقة هالأسبوع", delay: 0.3)
            stat(streak, streak > 2 ? "أيام ورا بعض" : "يوم ورا بعض", delay: 0.45)
            stat(Int((week.firstTryRate * 100).rounded()), "صح من أول مرة", delay: 0.6, suffix: "%")
        }
    }

    private func stat(_ value: Int, _ label: String, delay: Double, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Count(to: value, delay: delay, suffix: suffix)
                .font(Typeface.plex(28, .semibold))
                .foregroundStyle(Palette.text)
            Text(verbatim: label)
                .font(Typeface.plex(13))
                .foregroundStyle(Palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Day: View {
    let index: Int
    let minutes: Int?
    let goal: Int
    let today: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(verbatim: HomeDate.letters[index])
                    .font(Typeface.plex(13, today ? .bold : .medium))
                    .foregroundStyle(today ? Palette.ink : Palette.text2)
                if today {
                    InkOn(shape: InkEllipse(), color: Palette.ink, lineWidth: 1.8, duration: 0.65, delay: 1.1)
                        .frame(width: 22, height: 20)
                }
            }
            .frame(width: 22, height: 22)
            ZStack {
                Tween(target: Double(minutes ?? 0) / Double(goal), duration: 0.9, delay: 0.2 + Double(index) * 0.07) { v in
                    Ring(value: v, stroke: 4, color: Palette.accent, track: Palette.fill, dashed: minutes == nil)
                }
                if let minutes, minutes >= goal {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(width: 34, height: 34)
            .padding(.top, 8)
            Text(verbatim: minutes.map { $0.figures } ?? "—")
                .font(Typeface.plex(11))
                .foregroundStyle(minutes == nil ? Palette.text3 : Palette.text2)
                .padding(.top, 4)
        }
        .frame(width: 40)
    }
}

// MARK: - The shelf

private struct Shelf: View {
    let size: CGFloat
    let width: CGFloat
    let open: () -> Void
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            // The covers run on past the edge, as they would in the scrolling shelf.
            row
                .fixedSize()
                .frame(width: width, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) { row }
                .scrollClipDisabled()
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(Samples.shelf.enumerated()), id: \.element.id) { k, lecture in
                ShelfItem(lecture: lecture, size: size, delay: Double(k) * 0.12, open: open)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ShelfItem: View {
    let lecture: Lecture
    let size: CGFloat
    let delay: Double
    let open: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let state = CoverState(lecture)
        Button {
            if case .current = state { open() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                CoverArt(Cover.samples[lecture.number - 1], size: size, state: state, delay: delay)
                    .tilt(radius: size * 0.07)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.16), radius: 14, y: 8)
                Text(verbatim: lecture.arabicTitle)
                    .font(Typeface.plex(15, .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .padding(.top, 10)
                Text(verbatim: subtitle(state))
                    .font(Typeface.plex(13))
                    .foregroundStyle(isCurrent(state) ? Palette.accent : Palette.text2)
                    .lineLimit(1)
            }
            .frame(width: size, alignment: .leading)
        }
        .buttonStyle(.press(0.97, radius: size * 0.07))
    }

    private func subtitle(_ state: CoverState) -> String {
        switch state {
        case let .preparing(progress): "يتجهّز · \(Int((progress * 100).rounded()).figures)%"
        case .current: "وصلت صفحة \(Samples.resume.page.figures) من \(lecture.slideCount.figures)"
        default: "خلصتها · \(lecture.slideCount.figures) صفحة"
        }
    }

    private func isCurrent(_ state: CoverState) -> Bool {
        if case .current = state { return true }
        return false
    }
}

// MARK: - Being prepared

/// The next lecture while it's being prepared, as a live activity: which stage it's at, slides
/// turning ready one by one, and roughly how long is left (Flighty's way of showing a flight).
private struct Preparing: View {
    let wide: Bool
    @Environment(\.motionOff) private var motionOff
    @Environment(\.colorScheme) private var scheme
    @State private var ready = Samples.importJob.scripted

    private static let stages = ["قراءة الملف", "تحديد المناطق", "كتابة الشرح", "المراجعة"]
    private let at = 2

    var body: some View {
        let job = Samples.importJob
        let lecture = Samples.lecture6
        let total = job.slideCount
        let left = max(1, Int((Double(total - ready) * 0.18).rounded()))
        let thumbs = wide ? 14 : 8
        let first = max(1, min(total - thumbs + 1, ready - thumbs / 2 + 1))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                CoverArt(Cover.samples[lecture.number - 1], size: wide ? 76 : 64, state: CoverState(lecture))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        Pulse(color: Palette.accent.color(scheme), size: 6)
                        Text("يتجهّز الحين")
                            .font(Typeface.plex(12, .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    Text(verbatim: "المحاضرة \(HomeDate.ordinal(lecture.number)): \(lecture.arabicTitle)")
                        .font(Typeface.plex(17, .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Text(verbatim: "\(ready.figures) من \(total.figures) شريحة جاهزة · باقي تقريبًا \(left.figures) \(left > 2 && left < 11 ? "دقايق" : "دقيقة")")
                        .font(Typeface.plex(13))
                        .foregroundStyle(Palette.text2)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            stepper.padding(.top, 18)
            bar(Double(ready) / Double(total)).padding(.top, 16)
            HStack(spacing: 6) {
                ForEach(0..<thumbs, id: \.self) { j in
                    let n = first + j
                    Thumb(number: n, state: n <= ready ? .ready : n == ready + 1 ? .writing : .waiting)
                }
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task {
            guard !motionOff else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.settle(0.5)) {
                    ready = ready >= total - 1 ? job.scripted : ready + 1
                }
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            ForEach(Self.stages.indices, id: \.self) { k in
                if k > 0 {
                    Capsule()
                        .fill(k <= at ? Palette.accent : Palette.fill)
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
                HStack(spacing: 6) {
                    marker(k)
                    if wide || k == at {
                        Text(verbatim: Self.stages[k])
                            .font(Typeface.plex(13, k == at ? .semibold : .regular))
                            .foregroundStyle(k <= at ? Palette.text : Palette.text2)
                            .fixedSize()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func marker(_ k: Int) -> some View {
        if k < at {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 18, height: 18)
                .background(Palette.accent, in: Circle())
        } else if k == at {
            Pulse(color: Palette.accent.color(scheme), size: 8)
        } else {
            Circle().strokeBorder(Palette.fill, lineWidth: 2).frame(width: 18, height: 18)
        }
    }

    private func bar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    Capsule().fill(Palette.accent).frame(width: geo.size.width * fraction)
                    Spacer(minLength: 0)
                }
                Shimmer(opacity: scheme == .dark ? 0.35 : 0.6)
            }
        }
        .frame(height: 6)
        .background(Palette.fill)
        .clipShape(Capsule())
    }
}

private struct Thumb: View {
    let number: Int
    let state: SlideJobState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if state == .waiting {
                    Rectangle().fill(Palette.fill)
                } else {
                    Color.white
                    sketch
                }
                if state == .writing { Shimmer(color: Stage.pen, opacity: 0.25) }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
            Text(verbatim: number.figures)
                .font(Typeface.plex(10))
                .foregroundStyle(state == .writing ? Palette.accent : Palette.text3)
        }
        .frame(maxWidth: .infinity)
    }

    /// A miniature slide: a title bar, two lines, and once it's ready the tutor's squiggle.
    private var sketch: some View {
        let n = Double(number)
        let ready = state == .ready
        return Canvas { context, size in
            let s: Double = Double(size.width) / 40
            func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
                let rect = CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
                let radius: Double = h * s / 2
                return Path(roundedRect: rect, cornerRadius: radius)
            }
            context.fill(r(5, 5, 18, 2.4), with: .color(Color(hex: 0xC9CDD2)))
            context.fill(r(5, 10, 26, 1.6), with: .color(Color(hex: 0xE1E4E8)))
            context.fill(r(5, 14, 22, 1.6), with: .color(Color(hex: 0xE1E4E8)))
            guard ready else { return }
            let y0: Double = 22 + n.truncatingRemainder(dividingBy: 3)
            let cy: Double = 17 + n.truncatingRemainder(dividingBy: 4)
            let y1: Double = 22 - n.truncatingRemainder(dividingBy: 2)
            let y2: Double = 20 + n.truncatingRemainder(dividingBy: 3)
            let cy2: Double = 2 * y1 - cy
            let lw: Double = 1.6 * s
            var pen = Path()
            pen.move(to: CGPoint(x: 6 * s, y: y0 * s))
            pen.addQuadCurve(to: CGPoint(x: 20 * s, y: y1 * s), control: CGPoint(x: 14 * s, y: cy * s))
            pen.addQuadCurve(to: CGPoint(x: 34 * s, y: y2 * s), control: CGPoint(x: 26 * s, y: cy2 * s))
            context.stroke(pen, with: .color(Stage.pen), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Review

private struct ReviewList: View {
    let limit: Int
    let open: () -> Void

    private static let due = ["اليوم", "اليوم", "بكرة", "بعد 3 أيام", "بعد أسبوع"]

    var body: some View {
        let items = Array(Samples.reviewItems.prefix(limit))
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { k, item in
                Button(action: open) {
                    row(item, due: Self.due[min(k, Self.due.count - 1)], soon: k < 2)
                }
                .buttonStyle(.press(0.99, hover: Palette.hover, radius: 0))
                if k < items.count - 1 {
                    Rectangle().fill(Palette.sep).frame(height: 0.5).padding(.leading, 92)
                }
            }
        }
        .background(Palette.raised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ item: ReviewItem, due: String, soon: Bool) -> some View {
        HStack(spacing: 14) {
            SlideCrop(page: Samples.sinePage, focus: item.focus, size: CGSize(width: 64, height: 48), zoom: 2.6)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: Self.isolate(item.question))
                    .font(Typeface.plex(16, .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(verbatim: "جاوبت \(Self.ltr(item.yourAnswer.figures)) · المحاضرة \(item.lectureNumber.figures)، صفحة \(item.page.figures)")
                    .font(Typeface.plex(13))
                    .foregroundStyle(Palette.text2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: due)
                .font(Typeface.plex(12, .semibold))
                .foregroundStyle(soon ? Palette.accent : Palette.text2)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(soon ? Palette.accentSoft : Palette.fill, in: Capsule())
            Image(systemName: "chevron.forward")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.text3)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    /// Math between backticks, held left-to-right inside the Arabic line.
    static func isolate(_ text: String) -> String {
        let parts = text.figures.split(separator: "`", omittingEmptySubsequences: false)
        return "\u{200F}" + parts.enumerated().map { k, s in k % 2 == 1 ? ltr(String(s)) : String(s) }.joined()
    }

    static func ltr(_ s: String) -> String { "\u{2066}" + s + "\u{2069}" }
}

// MARK: - Mini player

private struct MiniPlayer: View {
    let open: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let resume = Samples.resume
        Button(action: open) {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let played: Double = (Double(resume.step) - 0.5) / Double(resume.stepCount)
                    HStack(spacing: 0) {
                        Rectangle().fill(Palette.accent)
                            .frame(width: geo.size.width * played)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 2)
                .background(Palette.fill)
                HStack(spacing: 12) {
                    SlideStage(page: Samples.sinePage, pastMarks: LiveArtwork.pastInk)
                        .frame(width: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: Samples.sinePage.title)
                            .font(Typeface.plex(15, .semibold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                        Text(verbatim: "\(resume.lecture.arabicTitle) · الخطوة \(resume.step.figures) من \(resume.stepCount.figures)")
                            .font(Typeface.plex(13))
                            .foregroundStyle(Palette.text2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    control("play.fill")
                    control("forward.fill").scaleEffect(x: -1)
                }
                .padding(.horizontal, 10)
                .frame(height: 64)
            }
            .background(Palette.bar)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.14), radius: 24, y: 8)
        }
        .buttonStyle(.press(0.985, radius: 18))
    }

    private func control(_ symbol: String) -> some View {
        Button(action: open) {
            Image(systemName: symbol)
                .font(.system(size: 21))
                .foregroundStyle(Palette.text)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.press(0.9, hover: Palette.fill, radius: 20))
    }
}

// MARK: - Navigation

enum HomeTab: CaseIterable {
    case home, library, review, importing

    var label: String {
        switch self {
        case .home: "الرئيسية"
        case .library: "المكتبة"
        case .review: "المراجعة"
        case .importing: "محاضرة جديدة"
        }
    }

    var icon: NibIcon.Name {
        switch self {
        case .home: .home
        case .library: .library
        case .review: .review
        case .importing: .plus
        }
    }

    var badge: Int? { self == .review ? Samples.reviewItems.count + 2 : nil }
}

struct HomeSidebar: View {
    let tab: HomeTab
    let select: (HomeTab) -> Void
    /// When set, a button beside the name folds the sidebar away and the page goes full screen.
    var collapse: (() -> Void)?

    /// Narrow on purpose: a list of five words doesn't need a third of the screen.
    static let width: CGFloat = 220

    private static let courses: [(code: String, name: String, color: Color, done: Int, all: Int)] = [
        ("207", "الدوائر الكهربائية", Cover.samples[4].color, 4, 12),
        ("211", "الإلكترونيات", Cover.samples[0].color, 0, 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandLogo(size: 28)
                Text("مُعيد")
                    .font(Typeface.plex(20, .bold))
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                if let collapse {
                    SidebarToggle(action: collapse)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 18)
            ForEach(HomeTab.allCases, id: \.self) { item in
                navRow(item)
            }
            Text("المقررات")
                .font(Typeface.plex(12, .semibold))
                .foregroundStyle(Palette.text2)
                .padding(.top, 22)
                .padding(.bottom, 4)
                .padding(.horizontal, 8)
            ForEach(Self.courses.indices, id: \.self) { i in
                let course = Self.courses[i]
                Button {} label: {
                    HStack(spacing: 10) {
                        Text(verbatim: course.code)
                            .font(Typeface.plex(8, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(course.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(verbatim: course.name)
                            .font(Typeface.plex(15))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: "\(course.done.figures)/\(course.all.figures)")
                            .font(Typeface.plex(12))
                            .foregroundStyle(Palette.text3)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 38)
                }
                .buttonStyle(.press(0.98, hover: Palette.hover, radius: 9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.sep).frame(width: 0.5) }
    }

    private func navRow(_ item: HomeTab) -> some View {
        let on = item == tab
        return Button { select(item) } label: {
            HStack(spacing: 10) {
                NibIcon(item.icon, size: 20, weight: on ? 2.6 : 2.1, active: on)
                    .foregroundStyle(Palette.accent)
                Text(verbatim: item.label)
                    .font(Typeface.plex(16, on ? .semibold : .regular))
                    .foregroundStyle(on ? Palette.accent : Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let badge = item.badge {
                    Text(verbatim: badge.figures)
                        .font(Typeface.plex(13, .medium))
                        .foregroundStyle(Palette.text2)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(on ? Palette.accentSoft : Adaptive.fixed(.clear), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.press(0.98, hover: on ? nil : Palette.hover, radius: 9))
    }
}

/// The sidebar's own button, as iPadOS puts it: folds it away, and brings it back from the page's corner.
struct SidebarToggle: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Palette.text2)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.press(0.9, hover: Palette.hover, radius: 9))
        .accessibilityLabel("القائمة الجانبية")
    }
}

struct HomeTabBar: View {
    let tab: HomeTab
    let select: (HomeTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { item in
                let on = item == tab
                Button { select(item) } label: {
                    VStack(spacing: 2) {
                        NibIcon(item.icon, size: 25, weight: on ? 2.6 : 2.1, active: on)
                        Text(verbatim: item.label)
                            .font(Typeface.plex(10, .medium))
                    }
                    .foregroundStyle(on ? Palette.accent : Palette.text2)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.press(0.9))
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(Palette.bar)
        .overlay(alignment: .top) { Rectangle().fill(Palette.sep).frame(height: 0.5) }
    }
}
