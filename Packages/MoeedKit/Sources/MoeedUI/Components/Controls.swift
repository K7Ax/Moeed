import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FilledButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color = .white
    var height: CGFloat = 48
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .frame(minHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(isSelected ? Theme.ink : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Theme.ink : Theme.line, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static func filled(_ background: Color = Theme.pen, foreground: Color = .white, height: CGFloat = 48) -> FilledButtonStyle {
        FilledButtonStyle(background: background, foreground: foreground, height: height)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static func outline(height: CGFloat = 48) -> OutlineButtonStyle { OutlineButtonStyle(height: height) }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static func chip(selected: Bool) -> ChipButtonStyle { ChipButtonStyle(isSelected: selected) }
}

/// A thin progress bar that fills from the reading start (right in Arabic).
struct ProgressTrack: View {
    var value: Double
    var tint: Color = Theme.pen
    var track: Color = Theme.ground
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(track, in: Capsule())
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value * 100))٪"))
    }
}

struct StatusPill: View {
    var text: String
    var foreground: Color
    var background: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }
}

/// Wraps children onto new lines; mirrors automatically in right-to-left.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The app mark. Loads the "Logo" image from the app's asset catalog; a plain tile stands in elsewhere (CLI snapshots).
struct LogoSlot: View {
    var size: CGFloat = 38

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let logo = UIImage(named: "Logo") {
                Image(uiImage: logo).resizable().scaledToFit()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(Theme.ink)
    }
}
