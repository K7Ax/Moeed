import SwiftUI
import MoeedCore

/// "Explain this": the student frames a region of the slide in blue pen and asks about it.
/// The region comes back as a taped clipping, and the answer as the tutor's numbered margin notes.
struct ExplainPanel: View {
    var page: SlidePage
    var selection: SlideRect
    var onDraw: () -> Void
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var chosen = 0
    @State private var question = ""

    private let prompts: [LocalizedStringKey] = ["وش معنى هذا الرمز؟", "من وين جات؟", "مثال ثاني", "أبسط"]

    init(page: SlidePage, selection: SlideRect, onDraw: @escaping () -> Void) {
        self.page = page
        self.selection = selection
        self.onDraw = onDraw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("اشرح هذا الجزء")
                    .font(Theme.text(21, .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("منطقة محدّدة")
                    .font(Theme.text(12.5, .semibold))
                    .foregroundStyle(Theme.blue)
            }
            Hairline()
                .padding(.top, 8)

            RegionCrop(page: page, rect: selection, width: 300)
                .slideFrame()
                .taped(.top, angle: 4)
                .rotationEffect(.degrees(-1.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            FlowLayout(spacing: 8) {
                ForEach(prompts.indices, id: \.self) { index in
                    Button { chosen = index } label: { Text(prompts[index]) }
                        .buttonStyle(.chip(selected: chosen == index))
                }
            }
            .padding(.top, 18)

            answer
                .padding(.top, 16)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Group {
                        if isSnapshot {
                            Text("اكتب سؤالك عن هالجزء…")
                                .foregroundStyle(Theme.mark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TextField("اكتب سؤالك عن هالجزء…", text: $question)
                                .foregroundStyle(Theme.blue)
                        }
                    }
                    .font(Theme.text(15.5))
                    Button {} label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 36, height: 36)
                            .background(Theme.ink, in: Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text("أرسل"))
                }
                .overlay(alignment: .bottom) { Hairline(color: Theme.ink, weight: 1).offset(y: -4) }
                Text("ينحفظ السؤال في «أسئلتي» مع مكانه على السلايد.")
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.mark)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .paperSheet(Theme.card)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.sampleAnswer.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: String(index + 1))
                        .font(Theme.serif(14, .bold))
                        .foregroundStyle(Theme.red)
                        .frame(width: 20)
                    Text(RichText.attributed(line))
                        .font(Theme.text(16))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(Theme.leading(for: 16) / 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Button(action: onDraw) {
                    Label("ارسمها على السلايد", systemImage: "pencil.tip")
                }
                .buttonStyle(.redPen(height: 44))
                Button {} label: { Text("ما زلت مو فاهم") }
                    .buttonStyle(.outline(height: 44))
            }
            .padding(.top, 4)
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.red.opacity(0.55)).frame(width: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let sampleAnswer = [
        "`f` هو التردد: كم دورة كاملة تتكرر في الثانية الوحدة.",
        "و`T` زمن الدورة الوحدة. لو الدورة تاخذ `0.4 s` فهي تتكرر `2.5` مرة كل ثانية.",
        "وحدته الهيرتز `Hz`.",
    ]
}

/// The selected part of the slide, scaled up to fill the width.
struct RegionCrop: View {
    var page: SlidePage
    var rect: SlideRect
    var width: CGFloat
    var pad: Double = 6

    var body: some View {
        let scale = width / CGFloat(rect.w + pad * 2)
        SlideStage(page: page)
            .frame(width: CGFloat(page.width) * scale, height: CGFloat(page.height) * scale)
            .offset(x: -CGFloat(rect.x - pad) * scale, y: -CGFloat(rect.y - pad) * scale)
            .frame(width: width, height: CGFloat(rect.h + pad * 2) * scale, alignment: .topLeading)
            .clipped()
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}
