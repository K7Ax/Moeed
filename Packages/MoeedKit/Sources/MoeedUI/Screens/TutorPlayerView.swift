import MoeedCore
import SwiftUI

/// The player, «الأصلي»'s way: Apple Music's lyrics, with the slide as the artwork. The tutor's
/// pen draws on the slide while its words light up beside it one at a time; what was said earlier
/// stays above, dimmed, and a tap goes back to it. Questions come in the same column, and a right
/// answer is rung on the slide.
struct TutorPlayerView: View {
    @Environment(AppRouter.self) private var router
    private var model: PlayerModel

    init(model: PlayerModel) {
        self.model = model
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            VStack(spacing: 0) {
                topBar
                GeometryReader { area in
                    if wide {
                        wideBody(area.size)
                    } else {
                        compactBody(area.size)
                    }
                }
            }
        }
        .background {
            ZStack {
                Stage.deep
                Ambient()
            }
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .environment(\.inkColor, Stage.pen)
        .modifier(MotionPolicy())
        .onAppear {
            if !model.isSettled { model.play() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        let lecture = Samples.resume.lecture
        return HStack(spacing: 12) {
            RoundButton(symbol: "chevron.down", label: "رجوع") { router.route = .home }
            VStack(spacing: 1) {
                Text(verbatim: lecture.arabicTitle)
                    .font(Typeface.plex(15, .semibold))
                    .foregroundStyle(.white)
                Text(verbatim: "المحاضرة \(HomeDate.ordinal(lecture.number)) · صفحة \(model.page.id.figures) من \(model.page.deckPageCount.figures)")
                    .font(Typeface.plex(12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            RoundButton(symbol: "ellipsis", label: "المزيد") {}
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
    }

    // MARK: Layouts

    /// Landscape: the slide and its controls on one side, the words on the other.
    private func wideBody(_ size: CGSize) -> some View {
        let byWidth: CGFloat = size.width * 0.52
        let byHeight: CGFloat = (size.height - 280) * 4 / 3
        let column: CGFloat = min(byWidth, byHeight)
        let words: CGFloat = min(34, max(26, size.width / 34))
        return HStack(alignment: .center, spacing: 56) {
            VStack(alignment: .leading, spacing: 0) {
                slide(width: column, radius: 14)
                    .shadow(color: .black.opacity(0.5), radius: 34, y: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.page.title)
                        .font(Typeface.plex(20, .bold))
                        .foregroundStyle(.white)
                    Text(verbatim: model.page.deckTitle)
                        .font(Typeface.serif(15, .regular, italic: true))
                        .foregroundStyle(.white.opacity(0.6))
                        .environment(\.layoutDirection, .leftToRight)
                }
                .lineLimit(1)
                .padding(.top, 22)
                Transport(model: model, width: column)
                    .padding(.top, 4)
            }
            .frame(width: column)
            .rise(0, dy: 30)
            Lyrics(model: model, size: words, padTop: size.height * 0.12, padBottom: size.height * 0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 40)
        .frame(width: size.width, height: size.height)
    }

    /// Portrait: the slide on top, the words under it, the controls at the bottom.
    private func compactBody(_ size: CGSize) -> some View {
        let width: CGFloat = size.width - 32
        return VStack(spacing: 0) {
            slide(width: width, radius: 12)
                .rise(0, dy: 24)
            Lyrics(model: model, size: 24, padTop: 16, padBottom: size.height * 0.4)
                .frame(maxHeight: .infinity)
            Transport(model: model, width: width, big: 40)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 16)
        .frame(width: size.width, height: size.height)
    }

    // MARK: The slide

    private func slide(width: CGFloat, radius: CGFloat) -> some View {
        let height: CGFloat = width * CGFloat(model.page.height / model.page.width)
        return SlideStage(page: model.page, pastMarks: model.pastMarks, marks: model.step.marks, drawn: model.drawn)
            .frame(width: width, height: height)
            .overlay { answerRing(width: width) }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Once a question is answered, the tutor rings where the answer is on the slide.
    @ViewBuilder
    private func answerRing(width: CGFloat) -> some View {
        if model.isAnswered, let at = model.answerAnchor {
            let scale: CGFloat = width / CGFloat(model.page.width)
            ZStack(alignment: .topLeading) {
                InkOn(shape: InkEllipse(), color: .fixed(Stage.pen), lineWidth: 5 * scale, duration: 0.7, delay: 0.1)
                    .frame(width: 84 * scale, height: 74 * scale)
                    .position(x: CGFloat(at.x) * scale, y: CGFloat(at.y) * scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.layoutDirection, .leftToRight)
            .allowsHitTesting(false)
            .id(model.playCount)
        }
    }
}

// MARK: - Lyrics

/// Every step said so far: the current one lit word by word, the earlier ones dimmed above it.
private struct Lyrics: View {
    var model: PlayerModel
    var size: CGFloat
    var padTop: CGFloat
    var padBottom: CGFloat
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            // No ScrollView in a render: show a step or two above the current one (one if it's a question).
            Color.clear
                .overlay(alignment: .top) {
                    column(from: max(0, model.stepIndex - (model.step.ask == nil ? 2 : 1)))
                        .padding(.top, padTop)
                }
                .clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    column(from: 0)
                        .padding(.top, padTop)
                        .padding(.bottom, padBottom)
                }
                .onChange(of: model.stepIndex, initial: true) { _, index in
                    withAnimation(.smooth(duration: 0.5)) {
                        proxy.scrollTo(index, anchor: UnitPoint(x: 0.5, y: 0.1))
                    }
                }
            }
        }
    }

    private func column(from first: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(first...model.stepIndex), id: \.self) { k in
                Group {
                    if k == model.stepIndex {
                        current
                    } else {
                        past(k)
                    }
                }
                .id(k)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func past(_ k: Int) -> some View {
        let step = model.page.steps[k]
        let lines = step.ask.map { [$0.question] } ?? step.caption.map(\.text)
        return Button { model.go(to: k) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines.indices, id: \.self) { j in
                    LyricLine(text: lines[j], size: size, lit: 1)
                }
            }
            .opacity(0.36)
            .blur(radius: 0.8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press(0.985, radius: 8))
        .padding(.bottom, size * 0.9)
    }

    private var current: some View {
        Group {
            if let ask = model.step.ask {
                AskLines(model: model, ask: ask, size: size)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.step.caption.indices, id: \.self) { j in
                        let text = model.step.caption[j].text
                        if j == model.revealed - 1 {
                            let seconds: Double = Double(ReadingTime.milliseconds(for: text)) / 1000 / model.speed * 0.8
                            SpokenLine(text: text, size: size, duration: seconds)
                        } else {
                            LyricLine(text: text, size: size, lit: j < model.revealed - 1 ? 1 : 0)
                        }
                    }
                }
            }
        }
        .padding(.bottom, size)
        .rise(0, dy: 26)
        .id("\(model.stepIndex)-\(model.playCount)")
    }
}

/// Words, and the math between backticks kept whole, so a line can light up one word at a time.
enum Lyric {
    struct Token {
        let text: String
        let term: Bool
        let space: Bool
    }

    static func tokens(_ text: String) -> [Token] {
        var out: [Token] = []
        for (k, part) in text.figures.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
            if k % 2 == 1 {
                // Held left to right, and never broken across lines.
                let math = "\u{2066}" + part.replacingOccurrences(of: " ", with: "\u{00A0}") + "\u{2069}"
                out.append(Token(text: math, term: true, space: false))
                continue
            }
            var word = ""
            for ch in part {
                if ch.isWhitespace {
                    if !word.isEmpty { out.append(Token(text: word, term: false, space: false)) }
                    word = ""
                    out.append(Token(text: String(ch), term: false, space: true))
                } else {
                    word.append(ch)
                }
            }
            if !word.isEmpty { out.append(Token(text: word, term: false, space: false)) }
        }
        return out
    }
}

/// One line of the tutor's words. `lit` runs 0 → 1 across it, and each word fades up as the light
/// reaches it rather than snapping on. Math is mint.
struct LyricLine: View, Animatable {
    var text: String
    var size: CGFloat
    var lit: Double

    var animatableData: Double {
        get { lit }
        set { lit = newValue }
    }

    var body: some View {
        Text(composed())
            .font(Typeface.plex(size, .bold))
            .lineSpacing(size * 0.12)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func composed() -> AttributedString {
        let tokens = Lyric.tokens(text)
        let count = Double(tokens.filter { !$0.space }.count)
        let reach = lit * count
        var index = -1.0
        var line = AttributedString("\u{200F}")
        for token in tokens {
            var part = AttributedString(token.text)
            if !token.space {
                index += 1
                let a = 0.3 + 0.7 * min(1, max(0, (reach - index) * 1.6))
                part.foregroundColor = token.term ? Stage.mint.opacity(a) : Color.white.opacity(a)
            }
            line.append(part)
        }
        return line
    }
}

/// The line being said: lights across its words over the time it takes to say them.
/// Frozen part-way in a render, so the screenshot shows the light moving.
struct SpokenLine: View {
    let text: String
    let size: CGFloat
    let duration: Double
    var frozen: Double = 0.6
    @Environment(\.motionOff) private var motionOff
    @State private var lit = 0.0

    init(text: String, size: CGFloat, duration: Double, frozen: Double = 0.6) {
        self.text = text
        self.size = size
        self.duration = duration
        self.frozen = frozen
    }

    var body: some View {
        LyricLine(text: text, size: size, lit: motionOff ? frozen : lit)
            .onAppear {
                guard !motionOff else { return }
                withAnimation(.linear(duration: duration)) { lit = 1 }
            }
    }
}

// MARK: - Questions

private struct AskLines: View {
    var model: PlayerModel
    let ask: Ask
    let size: CGFloat
    @State private var hint = false

    init(model: PlayerModel, ask: Ask, size: CGFloat) {
        self.model = model
        self.ask = ask
        self.size = size
    }

    private static let letters = ["أ", "ب", "ج", "د"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Stage.askDot).frame(width: 6, height: 6)
                Text("قبل ما أكمل، جاوب")
                    .font(Typeface.plex(13, .semibold))
                    .foregroundStyle(Stage.askText)
            }
            .padding(.bottom, 8)
            SpokenLine(text: ask.question, size: size, duration: seconds(ask.question, 0.6), frozen: 1)
            VStack(spacing: 10) {
                ForEach(Array(ask.options.enumerated()), id: \.element.id) { k, option in
                    AnswerOption(
                        letter: Self.letters[k % Self.letters.count],
                        label: option.label,
                        look: look(option),
                        index: k
                    ) { model.pick(option.id) }
                }
            }
            .frame(maxWidth: 520)
            .padding(.top, 18)
            if model.isAnswered {
                verdict
                    .padding(.top, 22)
                    .rise(0.2)
            } else {
                HStack(spacing: 10) {
                    Chip(label: "تلميح", symbol: "questionmark.circle") {
                        withAnimation(.smooth(duration: 0.3)) { hint = true }
                    }
                    Chip(label: "ما أدري، وريني", symbol: "eye") { model.showAnswer() }
                }
                .padding(.top, 16)
                .rise(0.56)
                if hint {
                    SpokenLine(text: ask.hint, size: size * 0.62, duration: seconds(ask.hint, 0.7))
                        .padding(.top, 14)
                        .rise(0)
                }
            }
        }
    }

    private var verdict: some View {
        let right = model.pickedRight
        let title = right ? "صح، أحسنت." : (model.picked != nil ? "مو هذا. شوف ليش:" : "هذا الجواب، وليش:")
        return VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: title)
                .font(Typeface.plex(17, .bold))
                .foregroundStyle(right ? Stage.rightBG : Stage.wrongBG)
            SpokenLine(text: ask.why, size: size * 0.72, duration: seconds(ask.why, 0.7), frozen: 1)
                .padding(.top, 6)
            Button { model.next() } label: {
                Text("متابعة")
                    .font(Typeface.plex(17, .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 30)
                    .frame(height: 50)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.press(0.95, radius: 25))
            .padding(.top, 20)
            .rise(0.9)
        }
    }

    private func look(_ option: AskOption) -> AnswerOption.Look {
        guard model.isAnswered else { return .idle }
        if option.id == ask.answerID { return .right }
        return option.id == model.picked ? .wrong : .dim
    }

    private func seconds(_ text: String, _ factor: Double) -> Double {
        Double(ReadingTime.milliseconds(for: text)) / 1000 * factor
    }
}

/// One answer: it shakes if it was your wrong pick (amber, never red), and the right one fills mint and bursts.
private struct AnswerOption: View {
    enum Look { case idle, right, wrong, dim }

    let letter: String
    let label: String
    let look: Look
    let index: Int
    let pick: () -> Void
    @State private var shakes = 0.0

    var body: some View {
        let marked = look == .right || look == .wrong
        let fg: Color = look == .right ? Stage.rightFG : (look == .wrong ? Stage.wrongFG : .white)
        let bg: Color = look == .right ? Stage.rightBG : (look == .wrong ? Stage.wrongBG : .white.opacity(0.1))
        let border: Color = marked ? bg : .white.opacity(0.16)
        return Button(action: pick) {
            HStack(spacing: 14) {
                Text(verbatim: letter)
                    .font(Typeface.plex(14, .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 30, height: 30)
                    .background(marked ? Color.black.opacity(0.12) : Color.white.opacity(0.12), in: Circle())
                Text(verbatim: "\u{2066}\(label.figures)\u{2069}")
                    .font(Typeface.plex(20, .semibold))
                    .foregroundStyle(fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if marked {
                    ZStack {
                        if look == .right { Burst() }
                        Image(systemName: look == .right ? "checkmark" : "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(fg)
                    }
                    .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.press(0.97, radius: 18))
        .disabled(look != .idle)
        .opacity(look == .dim ? 0.35 : 1)
        .modifier(Shake(animatableData: shakes))
        .onChange(of: look) { _, now in
            guard now == .wrong else { return }
            withAnimation(.linear(duration: 0.36)) { shakes += 1 }
        }
        .rise(0.26 + Double(index) * 0.09, dy: 12)
    }
}

/// Side to side, dying away, once per whole step of `animatableData`.
private struct Shake: GeometryEffect {
    var animatableData: Double

    func effectValue(size: CGSize) -> ProjectionTransform {
        let f: Double = animatableData - animatableData.rounded(.down)
        let x: Double = 10 * sin(f * .pi * 6) * (1 - f)
        return ProjectionTransform(CGAffineTransform(translationX: CGFloat(x), y: 0))
    }
}

/// A small burst of light from a right answer.
private struct Burst: View {
    @Environment(\.motionOff) private var motionOff
    @State private var p = 0.0

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { k in
                let angle: Double = Double(k) / 12 * 2 * .pi + Double(k % 2) * 0.2
                let reach: Double = (26 + Double(k % 3) * 9) * p
                let dot: CGFloat = CGFloat(6 + 2 * (k % 3))
                Circle()
                    .fill(k % 3 == 0 ? Color.white : Stage.mint)
                    .frame(width: dot, height: dot)
                    .scaleEffect(1 - 0.7 * p)
                    .offset(x: CGFloat(cos(angle) * reach), y: CGFloat(sin(angle) * reach))
            }
        }
        .opacity(motionOff ? 0 : 1 - p)
        .allowsHitTesting(false)
        .onAppear {
            guard !motionOff else { return }
            withAnimation(.easeOut(duration: 0.72)) { p = 1 }
        }
    }
}

private struct Chip: View {
    let label: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(verbatim: label)
                    .font(Typeface.plex(14, .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.press(0.95, radius: 17))
    }
}

// MARK: - Transport

/// The scrubber, the three transport glyphs, and speed and replay under them.
private struct Transport: View {
    var model: PlayerModel
    var width: CGFloat
    var big: CGFloat = 46

    var body: some View {
        VStack(spacing: 0) {
            Scrubber(model: model, width: width)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                // In Arabic the slide moves right to left: "back" points right, "on" points left.
                glyph("forward.fill", size: big * 0.72, box: big * 1.5, label: "الخطوة السابقة") { model.previous() }
                    .disabled(model.isFirst)
                    .opacity(model.isFirst ? 0.3 : 1)
                Spacer(minLength: 0)
                Button { model.toggleAuto() } label: {
                    Image(systemName: model.isAuto ? "pause.fill" : "play.fill")
                        .font(.system(size: big))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: big * 1.7, height: big * 1.7)
                }
                .buttonStyle(.press(0.85, hover: .fixed(.white.opacity(0.1)), radius: big * 0.85))
                .accessibilityLabel(model.isAuto ? "إيقاف" : "تشغيل")
                Spacer(minLength: 0)
                glyph("backward.fill", size: big * 0.72, box: big * 1.5, label: "الخطوة التالية") { model.next() }
                    .disabled(model.isLast)
                    .opacity(model.isLast ? 0.3 : 1)
                Spacer(minLength: 0)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.top, 4)
            HStack {
                Button { model.cycleSpeed() } label: {
                    Text(verbatim: model.speedLabel)
                        .font(Typeface.plex(13, .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.press(0.92, radius: 14))
                .accessibilityLabel("السرعة")
                Spacer(minLength: 0)
                Button { model.play() } label: {
                    NibIcon(.review, size: 22, weight: 2.3)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.press(0.85, hover: .fixed(.white.opacity(0.12)), radius: 17))
                .accessibilityLabel("أعد الخطوة")
            }
            .padding(.top, 10)
        }
        .frame(width: width)
    }

    private func glyph(_ symbol: String, size: CGFloat, box: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .environment(\.layoutDirection, .leftToRight)
                .frame(width: box, height: box)
        }
        .buttonStyle(.press(0.85, hover: .fixed(.white.opacity(0.1)), radius: box / 2))
        .accessibilityLabel(label)
    }
}

/// Steps as a track, filling from the right: drag across it to move. It thickens under the finger,
/// as the system's does, and the questions sit on it as dots (amber ahead, mint once answered).
private struct Scrubber: View {
    var model: PlayerModel
    var width: CGFloat
    @State private var touching = false

    var body: some View {
        let n = model.stepCount
        let i = model.stepIndex
        let slot: CGFloat = width / CGFloat(n)
        let asks = model.page.steps.indices.filter { model.page.steps[$0].ask != nil }
        let left = model.minutesLeft
        VStack(spacing: 0) {
            // Laid out left to right by hand, with the start on the right.
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ForEach(asks, id: \.self) { k in
                        let done = k < i || (k == i && model.isAnswered)
                        Circle()
                            .fill(done ? Stage.mint : Stage.askText)
                            .frame(width: 6, height: 6)
                            .padding(.trailing, slot * (CGFloat(k) + 0.5) - 3)
                    }
                }
                .frame(width: width, height: 8, alignment: .topTrailing)
                ZStack(alignment: .trailing) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white.opacity(0.92))
                        .frame(width: width * CGFloat(progress))
                }
                .frame(width: width, height: touching ? 10 : 5)
                .frame(height: 10)
                .animation(.smooth(duration: 0.5), value: progress)
                .animation(.spring(duration: 0.3, bounce: 0.3), value: touching)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        touching = true
                        let k = Int((width - drag.location.x) / slot)
                        let target = min(max(k, 0), n - 1)
                        if target != model.stepIndex { model.go(to: target) }
                    }
                    .onEnded { _ in touching = false }
            )
            .environment(\.layoutDirection, .leftToRight)
            .sensoryFeedback(.selection, trigger: i)
            HStack {
                Text(verbatim: "الخطوة \((i + 1).figures) من \(n.figures)")
                Spacer(minLength: 0)
                Text(verbatim: left == 1 ? "باقي أقل من دقيقة" : "باقي \(left.figures) دقايق")
            }
            .font(Typeface.plex(12, .medium))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, -4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("الخطوات")
        .accessibilityValue(Text(verbatim: "الخطوة \((i + 1).figures) من \(n.figures)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.next()
            case .decrement: model.previous()
            @unknown default: break
            }
        }
    }

    /// How far through the slide: whole steps done, plus how much of this one has been said.
    private var progress: Double {
        let step = model.step
        let within: Double
        if step.ask != nil {
            within = model.isAnswered ? 1 : 0.5
        } else if step.caption.isEmpty {
            within = 1
        } else {
            within = Double(model.revealed) / Double(step.caption.count)
        }
        return (Double(model.stepIndex) + within) / Double(model.stepCount)
    }
}

private struct RoundButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.press(0.88, radius: 18))
        .accessibilityLabel(label)
    }
}
