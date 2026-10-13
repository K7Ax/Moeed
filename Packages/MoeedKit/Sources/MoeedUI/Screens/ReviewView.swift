import SwiftUI
import MoeedCore

/// The predictions you got wrong, each pinned to the exact spot on its slide.
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
            VStack(alignment: .leading, spacing: 22) {
                header
                filters
                if visible.isEmpty {
                    empty
                } else if isSnapshot {
                    list(Array(visible.prefix(4)))
                } else {
                    ScrollView { list(visible) }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Aurora(intensity: 0.8))
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("المراجعة")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFB3CE)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.pen.opacity(0.4), radius: 16)
                Text("التوقّعات اللي غلطت فيها، مع مكانها بالضبط على السلايد.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button { router.route = .player } label: {
                Label("ابدأ المراجعة", systemImage: "play.fill")
            }
            .buttonStyle(.pen(height: 46))
            .disabled(items.isEmpty)
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
        VStack(spacing: 12) {
            ForEach(rows) { item in
                ReviewRow(item: item) {
                    router.route = .player
                } onUnderstood: {
                    withAnimation(.snappy(duration: 0.3)) {
                        items.removeAll { $0.id == item.id }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 24)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            LogoSculpture()
                .frame(width: 320, height: 260)
            Text("خلصت المراجعة")
                .font(.system(size: 20, weight: .bold))
            Text("كل التوقّعات اللي غلطت فيها صارت واضحة.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReviewRow: View {
    var item: ReviewItem
    var onReplay: () -> Void
    var onUnderstood: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            SlideCrop(page: Samples.sinePage, focus: item.focus)
                .slideFrame()

            VStack(alignment: .leading, spacing: 7) {
                Text("\(RichText.ltr("Lecture \(item.lectureNumber)")) · سلايد \(String(item.page))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Text(RichText.attributed(item.question))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    StatusPill(text: "جوابك: " + RichText.ltr(item.yourAnswer), foreground: Theme.secondary, background: .white.opacity(0.07))
                    StatusPill(text: "الصحيح: " + RichText.ltr(item.correctAnswer), foreground: Theme.correctText, background: Theme.correctTint)
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
                .buttonStyle(.filled(Theme.teal.opacity(0.2), foreground: Theme.mint, height: 44))
            }
            .frame(width: 150)
        }
        .padding(16)
        .card(radius: Radius.card)
    }
}
