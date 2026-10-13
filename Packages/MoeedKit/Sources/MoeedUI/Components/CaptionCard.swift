import SwiftUI
import MoeedCore

/// The tutor's words for one step, on a slip of card stock with the step number ringed in red pen.
/// Phrases come into focus one at a time; earlier ones step back, later ones wait unseen
/// (space is reserved so nothing jumps).
struct CaptionCard: View {
    var number: Int
    var phrases: [Phrase]
    var revealed: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: String(number))
                .font(Theme.serif(16, .bold))
                .foregroundStyle(Theme.red)
                .frame(width: 28, height: 28)
                .overlay { PenRing(lineWidth: 1.8).padding(-1) }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                    Text(RichText.attributed(phrase.text))
                        .font(Theme.text(18, index == revealed - 1 ? .semibold : .regular))
                        .lineSpacing(Theme.leading(for: 18) / 2)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(opacity(for: index))
                        .offset(y: index < revealed ? 0 : 6)
                        .accessibilityHidden(index >= revealed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            ZStack {
                Theme.card
                Grain(density: 0.5)
            }
            .overlay(alignment: .leading) {
                // The red margin line of a ruled card, on the reading side.
                Rectangle().fill(Theme.red.opacity(0.55)).frame(width: 1).padding(.leading, 50)
            }
            .overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 0.5))
            .shadow(color: Theme.ink.opacity(0.22), radius: 0.8, y: 0.8)
            .shadow(color: Theme.ink.opacity(0.14), radius: 10, y: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("الخطوة \(String(number))"))
    }

    private func opacity(for index: Int) -> Double {
        if index >= revealed { return 0 }
        return index == revealed - 1 ? 1 : 0.5
    }
}
