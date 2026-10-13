import SwiftUI
import MoeedCore

/// The tutor's words for one step. Phrases come into focus one at a time;
/// earlier ones step back, later ones wait unseen (space is reserved so nothing jumps).
struct CaptionCard: View {
    var number: Int
    var phrases: [Phrase]
    var revealed: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: String(number))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Theme.sunset, in: Circle())
                .glow(Theme.pen, radius: 8, opacity: 0.7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                    Text(RichText.attributed(phrase.text))
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(Theme.leading(for: 18) / 2)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(opacity(for: index))
                        .blur(radius: index < revealed ? 0 : 4)
                        .offset(y: index < revealed ? 0 : 6)
                        .accessibilityHidden(index >= revealed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            // Dark like film subtitles, so it reads the same over the white slide and over the night stage.
            let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            shape.fill(Theme.surface.opacity(0.95))
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center)))
                .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("الخطوة \(String(number))"))
    }

    private func opacity(for index: Int) -> Double {
        if index >= revealed { return 0 }
        return index == revealed - 1 ? 1 : 0.55
    }
}
