import SwiftUI
import MoeedCore

/// Predict before the reveal. A wrong guess is never red: the option shakes once,
/// and the pen circles the right answer, the way a tutor would on paper.
struct AskPanel: View {
    var model: PlayerModel
    var ask: Ask
    @State private var showHint = false
    @State private var shakes = 0

    init(model: PlayerModel, ask: Ask) {
        self.model = model
        self.ask = ask
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("توقّع قبل لا تكمل")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.pen)
                Text(RichText.attributed(ask.question))
                    .font(.system(size: 24, weight: .bold))
                    .lineSpacing(Theme.leading(for: 24) / 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("اختر جوابك، بعدها نكمل الرسم ونشوف.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
            }

            VStack(spacing: 10) {
                ForEach(ask.options) { option in
                    OptionRow(
                        option: option,
                        state: state(of: option),
                        shakes: option.id == model.picked ? shakes : 0
                    ) {
                        model.pick(option.id)
                    }
                    .disabled(model.isAnswered)
                }
            }

            feedback

            Spacer(minLength: 0)

            actions
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .card()
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

    @ViewBuilder
    private var feedback: some View {
        if model.isAnswered {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: model.pickedRight ? "checkmark.circle.fill" : "pencil.tip")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(model.pickedRight ? Theme.correct : Theme.pen)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.pickedRight ? "صح، بالضبط." : "مو بالضبط، شوف وين انرسمت الدائرة.")
                        .font(.system(size: 15, weight: .semibold))
                    Text(RichText.attributed(ask.why))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .lineSpacing(Theme.leading(for: 15) / 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(model.pickedRight ? Theme.correctTint : Theme.ground,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .transition(.opacity.combined(with: .offset(y: 6)))
        } else if showHint {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Text(RichText.attributed(ask.hint))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(Theme.leading(for: 15) / 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.filled(Theme.pen))
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

    var option: AskOption
    var state: Look
    var shakes: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(verbatim: RichText.ltr(option.label))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(state == .right ? Theme.correctText : Theme.ink)
                    .padding(.horizontal, 10)
                    .overlay {
                        // The tutor's pen circles the right answer.
                        InkEllipse()
                            .trim(from: 0, to: circled ? 1 : 0)
                            .stroke(Theme.pen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .padding(.horizontal, -8)
                            .padding(.vertical, -6)
                            .animation(.easeInOut(duration: InkTiming.stroke).delay(0.25), value: circled)
                    }
                Spacer(minLength: 0)
                tag
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .right ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(state == .other ? 0.5 : 1)
        .scaleEffect(state == .right ? 1.03 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: state == .right)
        .modifier(Shake(travel: CGFloat(shakes)))
        .accessibilityAddTraits(state == .right || state == .revealed ? .isSelected : [])
    }

    private var circled: Bool { state == .right || state == .revealed }

    private var background: Color {
        state == .right ? Theme.correctTint : Theme.surface
    }

    private var border: Color {
        switch state {
        case .right: return Theme.correct
        case .yourPick: return Theme.faint
        default: return Theme.line
        }
    }

    @ViewBuilder
    private var tag: some View {
        switch state {
        case .right:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.correct)
        case .revealed:
            StatusPill(text: "الصحيح", foreground: Theme.pen, background: Theme.penTint)
        case .yourPick:
            StatusPill(text: "اختيارك", foreground: Theme.secondary, background: Theme.ground)
        case .open, .other:
            EmptyView()
        }
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
