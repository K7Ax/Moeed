import Observation
import SwiftUI
import MoeedCore

/// Drives one slide's explanation: which step is showing, how much ink is drawn,
/// how many caption phrases are revealed, and the predict-before-reveal answer.
@MainActor
@Observable
public final class PlayerModel {
    public let page: SlidePage
    public private(set) var stepIndex: Int
    public private(set) var drawn = false
    public private(set) var revealed = 0
    public var showInk = true
    public var showText = true
    public private(set) var isAuto = false
    public private(set) var speed: Double = 1
    public private(set) var picked: String?
    public private(set) var answerShown = false

    /// A settled model shows a step fully drawn and never starts playback (previews, snapshots).
    @ObservationIgnored public private(set) var isSettled = false
    @ObservationIgnored private var playback: Task<Void, Never>?

    public init(page: SlidePage, stepIndex: Int = 0) {
        self.page = page
        self.stepIndex = min(max(stepIndex, 0), page.steps.count - 1)
    }

    public static func settled(_ page: SlidePage, step: Int, revealed: Int? = nil, picked: String? = nil) -> PlayerModel {
        let model = PlayerModel(page: page, stepIndex: step)
        model.drawn = true
        model.revealed = revealed ?? model.step.caption.count
        model.picked = picked
        model.isSettled = true
        return model
    }

    public var step: Step { page.steps[stepIndex] }
    public var stepCount: Int { page.steps.count }
    public var isFirst: Bool { stepIndex == 0 }
    public var isLast: Bool { stepIndex == stepCount - 1 }

    /// Ink from earlier steps, shown faded. Ask steps and spotlights don't carry over.
    public var pastMarks: [InkMark] {
        page.steps.prefix(stepIndex)
            .filter { $0.ask == nil }
            .flatMap(\.marks)
            .filter(\.persistsAfterStep)
    }

    public var isAnswered: Bool { picked != nil || answerShown }
    public var pickedRight: Bool { picked != nil && picked == step.ask?.answerID }

    public var speedLabel: String {
        speed == 1 ? "1×" : String(format: "%g×", speed)
    }

    // MARK: Navigation

    public func go(to index: Int) {
        guard page.steps.indices.contains(index) else { return }
        stepIndex = index
        picked = nil
        answerShown = false
        play()
    }

    public func next() { go(to: stepIndex + 1) }
    public func previous() { go(to: stepIndex - 1) }

    public func pick(_ optionID: String) {
        guard !answerShown else { return }
        withAnimation(.snappy(duration: 0.25)) { picked = optionID }
    }

    public func showAnswer() {
        withAnimation(.snappy(duration: 0.25)) { answerShown = true }
    }

    public func toggleAuto() {
        isAuto.toggle()
        if isAuto, revealed >= step.caption.count, step.ask == nil, !isLast { next() }
    }

    public func cycleSpeed() {
        let speeds: [Double] = [1, 1.25, 1.5, 0.75]
        let index = speeds.firstIndex(of: speed) ?? 0
        speed = speeds[(index + 1) % speeds.count]
    }

    // MARK: Playback

    /// Restart the current step: erase its ink, redraw it stroke by stroke, then reveal phrases at reading pace.
    public func play() {
        playback?.cancel()
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            drawn = false
            revealed = 0
        }
        let phrases = step.caption
        let inkDuration = InkTiming.total(for: step.marks.count)
        playback = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.drawn = true
            // Start the caption when the ink is ~60% drawn, so words and strokes overlap.
            try? await Task.sleep(for: .milliseconds(Int(inkDuration * 1000 * 0.6)))
            for (index, phrase) in phrases.enumerated() {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { self.revealed = index + 1 }
                let wait = Double(ReadingTime.milliseconds(for: phrase.text)) / self.speed
                try? await Task.sleep(for: .milliseconds(Int(wait)))
            }
            guard !Task.isCancelled, self.isAuto, self.step.ask == nil, !self.isLast else { return }
            self.next()
        }
    }
}
