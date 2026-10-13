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
                .background(Theme.pen, in: Circle())
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.12), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("الخطوة \(String(number))"))
    }

    private func opacity(for index: Int) -> Double {
        if index >= revealed { return 0 }
        return index == revealed - 1 ? 1 : 0.55
    }
}
