import SwiftUI
import MoeedCore

/// "Explain this": the student frames a region of the slide and asks about it.
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("اشرح هذا الجزء")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                StatusPill(text: "منطقة محدّدة", foreground: Theme.focus, background: Theme.focusTint)
            }

            RegionCrop(page: page, rect: selection)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Theme.focus, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                )

            FlowLayout(spacing: 8) {
                ForEach(prompts.indices, id: \.self) { index in
                    Button { chosen = index } label: { Text(prompts[index]) }
                        .buttonStyle(.chip(selected: chosen == index))
                }
            }

            answer

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Group {
                        if isSnapshot {
                            Text("اكتب سؤالك عن هالجزء…")
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TextField("اكتب سؤالك عن هالجزء…", text: $question)
                        }
                    }
                    .font(.system(size: 15))
                    Button {} label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.pen, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("أرسل"))
                }
                .padding(.leading, 16)
                .padding(.trailing, 6)
                .frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                Text("ينحفظ السؤال في «أسئلتي» مع مكانه على السلايد.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .card()
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.sampleAnswer, id: \.self) { line in
                    Text(RichText.attributed(line))
                        .font(.system(size: 16))
                        .lineSpacing(Theme.leading(for: 16) / 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Button(action: onDraw) {
                    Label("ارسمها على السلايد", systemImage: "pencil.tip")
                }
                .buttonStyle(.filled(Theme.pen, height: 44))
                Button {} label: { Text("ما زلت مو فاهم") }
                    .buttonStyle(.outline(height: 44))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
    var pad: Double = 14

    var body: some View {
        let w = rect.w + pad * 2
        let h = rect.h + pad * 2
        GeometryReader { geo in
            let scale = geo.size.width / CGFloat(w)
            SlideStage(page: page)
                .frame(width: CGFloat(page.width) * scale, height: CGFloat(page.height) * scale)
                .offset(x: -CGFloat(rect.x - pad) * scale, y: -CGFloat(rect.y - pad) * scale)
        }
        .aspectRatio(CGFloat(w / h), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}
