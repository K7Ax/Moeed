import SwiftUI
import MoeedCore

/// One slide, explained step by step: red pen on the printed page, words on a slip beside it,
/// a question before each reveal.
struct PlayerView: View {
    @Environment(AppRouter.self) private var router
    @Bindable private var model: PlayerModel
    @State private var explaining: Bool

    init(model: PlayerModel, explaining: Bool = false) {
        _model = Bindable(model)
        _explaining = State(initialValue: explaining)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            PlayerControls(model: model)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
        }
        .background(Desk())
        .onAppear {
            if !model.isSettled { model.play() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button { router.route = .library } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 12, weight: .bold))
                        Text("المكتبة")
                    }
                }
                .buttonStyle(.underlined)
                .fixedSize()

                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: model.page.title)
                        .font(Theme.text(20, .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(verbatim: model.page.deckTitle)
                            .font(Theme.serif(13.5))
                            .italic()
                        Text("· سلايد \(String(model.page.id)) من \(String(model.page.deckPageCount))")
                            .font(Theme.text(13))
                    }
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                }

                Spacer(minLength: 12)

                HStack(spacing: 14) {
                    LayerToggle(title: "الحبر", isOn: $model.showInk)
                    LayerToggle(title: "النص", isOn: $model.showText)
                }

                Button {
                    withAnimation(.snappy(duration: 0.3)) { explaining.toggle() }
                } label: {
                    Label(explaining ? "رجوع للشرح" : "اشرح هذا", systemImage: explaining ? "xmark" : "viewfinder")
                }
                .buttonStyle(explaining ? AnyButtonStyle(InkButtonStyle.ink(height: 44)) : AnyButtonStyle(OutlineButtonStyle.outline(height: 44)))
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 12)
            Hairline(color: Theme.ink.opacity(0.35))
                .padding(.horizontal, 28)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if explaining {
            HStack(alignment: .top, spacing: 26) {
                stage(selection: Samples.explainSelection)
                ExplainPanel(page: model.page, selection: Samples.explainSelection) {
                    withAnimation(.snappy(duration: 0.3)) { explaining = false }
                }
                .frame(width: 420)
            }
        } else if let ask = model.step.ask {
            HStack(alignment: .top, spacing: 26) {
                stage()
                AskPanel(model: model, ask: ask)
                    .frame(width: 410)
            }
        } else {
            watching
        }
    }

    /// While watching, the caption floats on the slide when there's room beside the ink,
    /// and docks under the slide when there's spare height (portrait) or the slide is small.
    private var watching: some View {
        GeometryReader { geo in
            let aspect = CGFloat(model.page.width / model.page.height)
            let fitWidth = min(geo.size.width, geo.size.height * aspect)
            let spareBelow = geo.size.height - fitWidth / aspect
            let placement = model.step.placement
            let floating = placement != nil && fitWidth >= 600 && spareBelow < 200

            Group {
                if floating, let placement {
                    stage(caption: model.showText ? StageCaption(
                        number: model.step.id,
                        phrases: model.step.caption,
                        revealed: model.revealed,
                        placement: placement
                    ) : nil)
                } else {
                    VStack(spacing: 22) {
                        stage()
                            .frame(width: fitWidth, height: min(fitWidth / aspect, geo.size.height - 170))
                        if model.showText {
                            CaptionCard(number: model.step.id, phrases: model.step.caption, revealed: model.revealed)
                                .frame(maxWidth: min(fitWidth, 680))
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func stage(selection: SlideRect? = nil, caption: StageCaption? = nil) -> some View {
        SlideStage(
            page: model.page,
            pastMarks: model.pastMarks,
            marks: model.step.marks,
            drawn: model.drawn,
            showInk: model.showInk,
            selection: selection,
            caption: caption
        )
        .slideFrame()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lets the top bar swap between two button styles without a type mismatch.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - Controls

/// A box ticked in red pen, as on an exam sheet.
private struct LayerToggle: View {
    var title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { isOn.toggle() }
        } label: {
            HStack(spacing: 7) {
                PenCheckbox(isOn: isOn)
                Text(title)
                    .font(Theme.text(14.5, .semibold))
                    .foregroundStyle(isOn ? Theme.ink : Theme.mark)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The step controls, printed on a strip of card along the bottom of the desk.
struct PlayerControls: View {
    var model: PlayerModel

    var body: some View {
        HStack(spacing: 14) {
            SquareIconButton(symbol: "chevron.backward", label: "الخطوة السابقة") { model.previous() }
                .disabled(model.isFirst)

            StepRuler(
                count: model.stepCount,
                current: model.stepIndex,
                askSteps: Set(model.page.steps.indices.filter { model.page.steps[$0].ask != nil })
            ) { model.go(to: $0) }

            Text("\(String(model.stepIndex + 1)) من \(String(model.stepCount))")
                .font(Theme.serif(15, .semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 52)

            Button { model.next() } label: {
                HStack(spacing: 6) {
                    Text("التالي")
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(.ink(height: 44))
            .disabled(model.isLast || (model.step.ask != nil && !model.isAnswered))

            Rectangle().fill(Theme.rule).frame(width: 0.75, height: 30)

            SquareIconButton(symbol: "arrow.counterclockwise", label: "أعد الخطوة") { model.play() }

            Button { model.toggleAuto() } label: {
                Label("تلقائي", systemImage: model.isAuto ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.chip(selected: model.isAuto))

            Button { model.cycleSpeed() } label: {
                Text(verbatim: model.speedLabel)
                    .font(Theme.serif(14, .bold).monospacedDigit())
                    .frame(minWidth: 26)
            }
            .buttonStyle(.chip(selected: false))
            .accessibilityLabel(Text("السرعة"))
            .accessibilityValue(Text(verbatim: model.speedLabel))
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .paperSheet(Theme.card, lift: 0.8)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SquareIconButton: View {
    var symbol: String
    var label: LocalizedStringKey
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(Text(label))
    }
}

/// The steps as marks on a ruler. Done steps are inked; the current one carries the red pen;
/// question steps are ringed so you can see where the predictions are.
struct StepRuler: View {
    var count: Int
    var current: Int
    var askSteps: Set<Int>
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                Button { onSelect(index) } label: {
                    tick(index)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 270)
        .background(alignment: .bottom) {
            Hairline(color: Theme.ink, weight: 1).padding(.bottom, 9)
        }
        .sensoryFeedback(.selection, trigger: current)
        .accessibilityElement()
        .accessibilityLabel(Text("الخطوات"))
        .accessibilityValue(Text("الخطوة \(String(current + 1)) من \(String(count))"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if current + 1 < count { onSelect(current + 1) }
            case .decrement: if current > 0 { onSelect(current - 1) }
            @unknown default: break
            }
        }
    }

    private func tick(_ index: Int) -> some View {
        let done = index <= current
        let isAsk = askSteps.contains(index)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(index == current ? Theme.red : (done ? Theme.ink : Theme.mark.opacity(0.6)))
                    .frame(width: index == current ? 3 : 1.5, height: index == current ? 24 : (isAsk ? 16 : 11))
                if isAsk {
                    InkEllipse()
                        .stroke(done ? Theme.red : Theme.mark, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: 16, height: 12)
                        .offset(y: -18)
                }
            }
            .padding(.bottom, 9)
        }
    }
}
