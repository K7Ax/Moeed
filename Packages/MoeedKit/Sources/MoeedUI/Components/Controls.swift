import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FilledButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle
    var foreground: Color = .white
    var glow: Color?
    var height: CGFloat = 48
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(minHeight: height)
            .background {
                shape.fill(fill)
                    // A sheen on the top half and a lit rim make it read as a raised, glossy key.
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .top, endPoint: .center)))
                    .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: (glow ?? .clear).opacity(isEnabled ? 0.5 : 0), radius: 18, y: 8)
            }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0.055), in: shape)
            .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1))
            .contentShape(shape)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? Theme.mint : Theme.secondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(isSelected ? Theme.teal.opacity(0.18) : .white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Theme.mint.opacity(0.7) : Theme.line, lineWidth: 1))
            .shadow(color: Theme.teal.opacity(isSelected ? 0.35 : 0), radius: 10)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static func filled(_ background: Color = Theme.pen, foreground: Color = .white, height: CGFloat = 48) -> FilledButtonStyle {
        FilledButtonStyle(fill: AnyShapeStyle(background), foreground: foreground, glow: background, height: height)
    }

    /// The main action: lit with the logo's mint-to-ocean light.
    static func primary(height: CGFloat = 48) -> FilledButtonStyle {
        FilledButtonStyle(fill: AnyShapeStyle(Theme.brand), foreground: Theme.onBright, glow: Theme.teal, height: height)
    }

    /// The tutor's actions: the pen's pink running into coral.
    static func pen(height: CGFloat = 48) -> FilledButtonStyle {
        FilledButtonStyle(fill: AnyShapeStyle(Theme.sunset), foreground: .white, glow: Theme.pen, height: height)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static func outline(height: CGFloat = 48) -> OutlineButtonStyle { OutlineButtonStyle(height: height) }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static func chip(selected: Bool) -> ChipButtonStyle { ChipButtonStyle(isSelected: selected) }
}

/// A thin, glowing progress bar that fills from the reading start (right in Arabic).
struct ProgressTrack: View {
    var value: Double
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.brandFlat)
    var glow: Color = Theme.teal
    var height: CGFloat = 8

    init(value: Double, height: CGFloat = 8) {
        self.value = value
        self.height = height
    }

    init(value: Double, tint: Color, height: CGFloat = 8) {
        self.value = value
        self.fill = AnyShapeStyle(tint)
        self.glow = tint
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                    .shadow(color: glow.opacity(0.6), radius: 6)
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(.white.opacity(0.08), in: Capsule())
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
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Theme.navy, Theme.ocean.opacity(0.9)], startPoint: .bottomLeading, endPoint: .topTrailing))
            ArchShape()
                .stroke(Theme.mint, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .frame(width: size * 0.56, height: size * 0.66)
                .offset(y: size * 0.05)
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.24, weight: .bold))
                .foregroundStyle(Theme.mint)
                .offset(x: size * 0.02, y: size * 0.1)
        }
    }
}

/// An open arch: two legs and a round top.
struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
