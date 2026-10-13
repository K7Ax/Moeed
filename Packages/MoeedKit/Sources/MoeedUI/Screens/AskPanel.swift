import SwiftUI
import MoeedCore

/// Predict before the reveal, on a question slip torn from a quiz pad.
/// Your pick is ringed in your own blue pen. A wrong guess is never red: the option shakes once,
/// and the tutor's red pen rings the right answer, the way a tutor would on paper.
struct AskPanel: View {
    var model: PlayerModel
    var ask: Ask
    @State private var showHint = false
    @State private var shakes = 0

    private static let letters = ["أ", "ب", "ج", "د", "هـ"]

    init(model: PlayerModel, ask: Ask) {
        self.model = model
        self.ask = ask
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("سؤال توقّع")
                    .font(Theme.text(13, .heavy))
                    .foregroundStyle(Theme.red)
                Spacer()
                Text("قبل لا تكمل")
                    .font(Theme.text(12.5))
                    .foregroundStyle(Theme.mark)
            }
            Hairline()
                .padding(.top, 8)

            Text(RichText.attributed(ask.question))
                .font(Theme.text(25, .heavy))
                .foregroundStyle(Theme.ink)
                .lineSpacing(Theme.leading(for: 25) / 2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
            Text("اختر جوابك، بعدها نكمل الرسم ونشوف.")
                .font(Theme.text(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(Array(ask.options.enumerated()), id: \.element.id) { index, option in
                    OptionRow(
                        letter: Self.letters[index % Self.letters.count],
                        option: option,
                        state: state(of: option),
                        shakes: option.id == model.picked ? shakes : 0
                    ) {
                        model.pick(option.id)
                    }
                    .allowsHitTesting(!model.isAnswered)
                }
            }
            .padding(.top, 14)

            feedback
                .padding(.top, 14)

            Spacer(minLength: 12)

            actions
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) { Perforation().offset(y: -1) }
        .paperSheet(Theme.card)
        .onChange(of: model.picked) { _, picked in
            guard let picked, picked != ask.answerID else { return }
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
        .sensoryFeedback(trigger: model.picked) { _, picked in
            guard let picked else { return nil }
            return picked == ask.answerID ? .success : .error
        }
    }

    private func state(of option: AskOption) -> OptionRow.Look {
        guard model.isAnswered else { return .open }
        if option.id == ask.answerID {
            return model.pickedRight ? .right : .revealed
        }
        return option.id == model.picked ? .yourPick : .other
    }

    /// The tutor's note in the margin, in red pen; a hint is in pencil.
    @ViewBuilder
    private var feedback: some View {
        if model.isAnswered {
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Theme.red).frame(width: 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.pickedRight ? "صح، بالضبط." : "مو بالضبط، شوف وين انرسمت الدائرة.")
                        .font(Theme.text(15.5, .bold))
                        .foregroundStyle(Theme.red)
                    Text(RichText.attributed(ask.why))
                        .font(Theme.text(15))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(Theme.leading(for: 15) / 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .offset(y: 6)))
        } else if showHint {
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Theme.mark).frame(width: 2)
                Text(RichText.attributed(ask.hint))
                    .font(Theme.text(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(Theme.leading(for: 15) / 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if model.isAnswered {
            Button { model.next() } label: {
                HStack(spacing: 8) {
                    Text("كمّل الشرح")
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ink())
        } else {
            HStack(spacing: 10) {
                Button { model.showAnswer() } label: {
                    Text("اكشف الجواب").frame(maxWidth: .infinity)
                }
                .buttonStyle(.outline())
                Button {
                    withAnimation(.snappy(duration: 0.25)) { showHint.toggle() }
                } label: {
                    Label("تلميح", systemImage: "lightbulb")
                }
                .buttonStyle(.outline())
            }
        }
    }
}

private struct OptionRow: View {
    enum Look {
        case open, right, revealed, yourPick, other
    }

    var letter: String
    var option: AskOption
    var state: Look
    var shakes: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(verbatim: letter)
                    .font(Theme.text(17, .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 30, height: 30)
                    .overlay {
                        // Your own pen rings the letter you chose.
                        if state == .yourPick || state == .right {
                            InkEllipse()
                                .stroke(Theme.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .padding(-2)
                        }
                    }
                Text(verbatim: RichText.ltr(option.label))
                    .font(Theme.serif(22, .bold))
                    .foregroundStyle(state == .other ? Theme.mark : Theme.ink)
                    .padding(.horizontal, 10)
                    .overlay {
                        // The tutor's pen rings the right answer.
                        InkEllipse()
                            .trim(from: 0, to: circled ? 1 : 0)
                            .stroke(Theme.red, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                            .padding(.horizontal, -8)
                            .padding(.vertical, -7)
                            .animation(.easeInOut(duration: InkTiming.stroke).delay(0.25), value: circled)
                    }
                Spacer(minLength: 0)
                tag
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) { Hairline(color: Theme.rule) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(Shake(travel: CGFloat(shakes)))
        .accessibilityAddTraits(state == .right || state == .revealed ? .isSelected : [])
    }

    private var circled: Bool { state == .right || state == .revealed }

    @ViewBuilder
    private var tag: some View {
        switch state {
        case .right:
            PenTick()
                .stroke(Theme.red, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 18)
        case .revealed:
            Text("الصحيح")
                .font(Theme.text(13, .bold))
                .foregroundStyle(Theme.red)
        case .yourPick:
            Text("اختيارك")
                .font(Theme.text(13, .semibold))
                .foregroundStyle(Theme.blue)
        case .open, .other:
            EmptyView()
        }
    }
}

/// The torn top of a slip pulled off a pad: a row of punched holes.
private struct Perforation: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 6
            while x < size.width {
                context.fill(Path(ellipseIn: CGRect(x: x, y: 6, width: 3.5, height: 3.5)), with: .color(Theme.desk))
                x += 9
            }
        }
        .frame(height: 14)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A hand-drawn loop that fits its frame, with a small overshoot where the pen lifts.
struct InkEllipse: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let samples = 48
        for i in 0...samples {
            let f = Double(i) / Double(samples)
            let angle = -2.3 + f * (2 * Double.pi + 0.45)
            let wobble = 1 + 0.04 * sin(f * 9) + 0.07 * f
            let point = CGPoint(
                x: rect.midX + rect.width / 2 * CGFloat(wobble * cos(angle)),
                y: rect.midY + rect.height / 2 * CGFloat(wobble * sin(angle))
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A short horizontal shake; animate `travel` by 1 to shake once.
private struct Shake: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(travel * .pi * 4), y: 0))
    }
}
