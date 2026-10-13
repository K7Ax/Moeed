import SwiftUI
import MoeedCore

/// One slide, explained step by step: ink on the slide, words beside it, a question before each reveal.
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
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            PlayerControls(model: model)
                .padding(.bottom, 18)
        }
        .background(Theme.ground)
        .onAppear {
            if !model.isSettled { model.play() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { router.route = .library } label: {
                Label("المكتبة", systemImage: "chevron.backward")
            }
            .buttonStyle(.outline(height: 44))

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.page.title)
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(1)
                Text("\(model.page.deckTitle) · سلايد \(String(model.page.id)) من \(String(model.page.deckPageCount))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                LayerToggle(title: "الحبر", symbol: "pencil.tip", isOn: $model.showInk)
                LayerToggle(title: "النص", symbol: "text.alignright", isOn: $model.showText)
            }
            .padding(4)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))

            Button {
                withAnimation(.snappy(duration: 0.3)) { explaining.toggle() }
            } label: {
                Label(explaining ? "رجوع للشرح" : "اشرح هذا", systemImage: explaining ? "xmark" : "viewfinder")
            }
            .buttonStyle(.filled(explaining ? Theme.focus : Theme.ink, height: 44))
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if explaining {
            HStack(alignment: .top, spacing: 20) {
                stage(selection: Samples.explainSelection)
                ExplainPanel(page: model.page, selection: Samples.explainSelection) {
                    withAnimation(.snappy(duration: 0.3)) { explaining = false }
                }
                .frame(width: 430)
            }
        } else if let ask = model.step.ask {
            HStack(alignment: .top, spacing: 20) {
                stage()
                AskPanel(model: model, ask: ask)
                    .frame(width: 420)
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
                    VStack(spacing: 18) {
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

// MARK: - Controls

private struct LayerToggle: View {
    var title: LocalizedStringKey
    var symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { isOn.toggle() }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Theme.secondary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isOn ? Theme.ink : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PlayerControls: View {
    var model: PlayerModel

    var body: some View {
        HStack(spacing: 12) {
            RoundIconButton(symbol: "chevron.backward", label: "الخطوة السابقة") { model.previous() }
                .disabled(model.isFirst)

            StepScrubber(
                count: model.stepCount,
                current: model.stepIndex,
                askSteps: Set(model.page.steps.indices.filter { model.page.steps[$0].ask != nil })
            ) { model.go(to: $0) }

            Text("\(String(model.stepIndex + 1)) من \(String(model.stepCount))")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .frame(minWidth: 52)

            Button { model.next() } label: {
                HStack(spacing: 6) {
                    Text("التالي")
                    Image(systemName: "chevron.forward")
                }
            }
            .buttonStyle(.filled(Theme.pen, height: 44))
            .disabled(model.isLast || (model.step.ask != nil && !model.isAnswered))

            Rectangle().fill(Theme.line).frame(width: 1, height: 28)

            RoundIconButton(symbol: "arrow.counterclockwise", label: "أعد الخطوة") { model.play() }

            Button { model.toggleAuto() } label: {
                Label("تلقائي", systemImage: model.isAuto ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.chip(selected: model.isAuto))

            Button { model.cycleSpeed() } label: {
                Text(verbatim: model.speedLabel)
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .frame(minWidth: 26)
            }
            .buttonStyle(.chip(selected: false))
            .accessibilityLabel(Text("السرعة"))
            .accessibilityValue(Text(verbatim: model.speedLabel))
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.08), radius: 14, y: 6)
    }
}

private struct RoundIconButton: View {
    var symbol: String
    var label: LocalizedStringKey
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.ground, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
    }
}

/// One segment per step; question steps are rings so you can see where the predictions are.
struct StepScrubber: View {
    var count: Int
    var current: Int
    var askSteps: Set<Int>
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Button { onSelect(index) } label: {
                    segment(index)
                        .frame(maxWidth: askSteps.contains(index) ? 14 : .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 250)
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

    @ViewBuilder
    private func segment(_ index: Int) -> some View {
        let color = index <= current ? Theme.pen : Theme.faint.opacity(0.6)
        if askSteps.contains(index) {
            Circle()
                .strokeBorder(color, lineWidth: 2.5)
                .frame(width: 12, height: 12)
        } else {
            Capsule()
                .fill(color)
                .frame(height: index == current ? 8 : 5)
        }
    }
}
