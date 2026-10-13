import SwiftUI
import MoeedCore

/// The predictions you got wrong, each on an index card with its slide clipped to it.
struct ReviewView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var items = Samples.reviewItems
    @State private var lecture: Int?

    init() {}

    private var visible: [ReviewItem] {
        items.filter { lecture == nil || $0.lectureNumber == lecture }
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(reviewCount: items.count + 2)
            VStack(alignment: .leading, spacing: 0) {
                header
                filters
                    .padding(.top, 14)
                Group {
                    if visible.isEmpty {
                        empty
                    } else if isSnapshot {
                        list(Array(visible.prefix(4)))
                    } else {
                        ScrollView { list(visible) }
                    }
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 34)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperSheet()
        }
        .padding(16)
        .background(Desk())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("المراجعة")
                        .font(Theme.text(42, .black))
                        .foregroundStyle(Theme.ink)
                    Text("التوقّعات اللي غلطت فيها، كل وحدة مثبّتة على مكانها بالضبط في السلايد.")
                        .font(Theme.text(15))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Button { router.route = .player } label: {
                    Label("ابدأ المراجعة", systemImage: "play.fill")
                }
                .buttonStyle(.ink(height: 46))
                .disabled(items.isEmpty)
            }
            DoubleRule()
                .padding(.top, 14)
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            Button { lecture = nil } label: { Text("الكل \(String(items.count))") }
                .buttonStyle(.chip(selected: lecture == nil))
            ForEach([5, 4], id: \.self) { number in
                Button { lecture = number } label: { Text(verbatim: "Lecture \(number)") }
                    .buttonStyle(.chip(selected: lecture == number))
            }
        }
    }

    private func list(_ rows: [ReviewItem]) -> some View {
        VStack(spacing: 16) {
            ForEach(rows) { item in
                ReviewCard(item: item) {
                    router.route = .player
                } onUnderstood: {
                    withAnimation(.snappy(duration: 0.3)) {
                        items.removeAll { $0.id == item.id }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 24)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Stamp(text: "خلصت المراجعة", size: 26, angle: -8)
            Text("كل التوقّعات اللي غلطت فيها صارت واضحة.")
                .font(Theme.text(15))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A ruled index card: red header line, faint blue lines, and the slide clipped on.
private struct ReviewCard: View {
    var item: ReviewItem
    var onReplay: () -> Void
    var onUnderstood: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            SlideCrop(page: Samples.sinePage, focus: item.focus, size: CGSize(width: 120, height: 90))
                .slideFrame()
                .rotationEffect(.degrees(item.id.isMultiple(of: 2) ? 1.5 : -1.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("\(RichText.ltr("Lecture \(item.lectureNumber)")) · سلايد \(String(item.page))")
                    .font(Theme.text(12.5, .semibold))
                    .foregroundStyle(Theme.red)
                Text(RichText.attributed(item.question))
                    .font(Theme.text(18, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 18) {
                    HStack(spacing: 6) {
                        Text("جوابك")
                            .font(Theme.text(12.5))
                            .foregroundStyle(Theme.mark)
                        Text(verbatim: RichText.ltr(item.yourAnswer))
                            .font(Theme.serif(16, .semibold))
                            .strikethrough(true, color: Theme.blue.opacity(0.7))
                            .foregroundStyle(Theme.blue)
                    }
                    HStack(spacing: 6) {
                        Text("الصحيح")
                            .font(Theme.text(12.5))
                            .foregroundStyle(Theme.mark)
                        Text(verbatim: RichText.ltr(item.correctAnswer))
                            .font(Theme.serif(16, .bold))
                            .foregroundStyle(Theme.red)
                            .padding(.horizontal, 6)
                            .overlay { PenRing(lineWidth: 1.6).padding(.vertical, -4).padding(.horizontal, -2) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Button(action: onReplay) {
                    Label("أعد الخطوة", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outline(height: 44))
                Button(action: onUnderstood) {
                    Label("فهمتها", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stamped(height: 44))
            }
            .frame(width: 150)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .background {
            ZStack(alignment: .top) {
                Theme.card
                IndexCardLines()
                Grain(density: 0.5)
            }
            .shadow(color: Theme.ink.opacity(0.2), radius: 0.7, y: 0.7)
            .shadow(color: Theme.ink.opacity(0.1), radius: 8, y: 4)
        }
    }
}

/// The printing on an index card.
private struct IndexCardLines: View {
    var body: some View {
        Canvas { context, size in
            var header = Path()
            header.move(to: CGPoint(x: 0, y: 14))
            header.addLine(to: CGPoint(x: size.width, y: 14))
            context.stroke(header, with: .color(Theme.red.opacity(0.55)), lineWidth: 1)
            var y: CGFloat = 40
            while y < size.height - 4 {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Theme.blue.opacity(0.1)), lineWidth: 0.75)
                y += 24
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
