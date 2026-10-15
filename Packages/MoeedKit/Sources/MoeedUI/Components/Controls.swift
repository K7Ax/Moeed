import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A solid printed key: toner black (or the tutor's red), paper-coloured letters, square corners.
/// Pressing it sinks it into the page instead of dimming it.
struct InkButtonStyle: ButtonStyle {
    var fill: Color = Theme.ink
    var foreground: Color = Theme.paper
    var height: CGFloat = 48
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(16, .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(minHeight: height)
            .background(fill, in: Rectangle())
            .background(
                Rectangle().fill(Theme.ink.opacity(0.85)).offset(x: 0, y: configuration.isPressed ? 0 : 3)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// A ruled box: a hairline of ink around the words, nothing behind them.
struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(15, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.08 : 0), in: Rectangle())
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// A tab in an index: the selected one is printed solid.
struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(14, isSelected ? .bold : .medium))
            .foregroundStyle(isSelected ? Theme.paper : Theme.inkSoft)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(isSelected ? Theme.ink : Color.clear, in: Rectangle())
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.ink : Theme.rule, lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .frame(minHeight: 44)
    }
}

/// Words with a pen underline, for quiet navigation like «← المكتبة».
struct UnderlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(15, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) { Hairline(weight: 1) }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static func ink(height: CGFloat = 48) -> InkButtonStyle { InkButtonStyle(height: height) }
    /// The tutor's own actions are in red pen.
    static func redPen(height: CGFloat = 48) -> InkButtonStyle { InkButtonStyle(fill: Theme.red, height: height) }
    static func stamped(height: CGFloat = 48) -> InkButtonStyle { InkButtonStyle(fill: Theme.stamp, height: height) }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static func outline(height: CGFloat = 48) -> OutlineButtonStyle { OutlineButtonStyle(height: height) }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static func chip(selected: Bool) -> ChipButtonStyle { ChipButtonStyle(isSelected: selected) }
}

extension ButtonStyle where Self == UnderlineButtonStyle {
    static var underlined: UnderlineButtonStyle { UnderlineButtonStyle() }
}

/// Progress as a highlighter run along a dotted rule, filling from the reading start (right in Arabic).
struct ProgressTrack: View {
    var value: Double
    var tint: Color = Theme.highlighter
    var height: CGFloat = 10

    init(value: Double, height: CGFloat = 10) {
        self.value = value
        self.height = height
    }

    init(value: Double, tint: Color, height: CGFloat = 10) {
        self.value = value
        self.tint = tint
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Leader()
                    .frame(maxHeight: .infinity)
                HighlighterSwipe(seed: 2)
                    .fill(tint.opacity(0.75))
                    .blendMode(.multiply)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value * 100))%"))
    }
}

/// A small rubber-stamp label: ink outline, slightly worn.
struct StatusPill: View {
    var text: String
    var foreground: Color
    var background: Color = .clear

    var body: some View {
        Text(text)
            .font(Theme.text(12, .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(background, in: Rectangle())
            .overlay(Rectangle().strokeBorder(foreground.opacity(0.8), lineWidth: 1))
    }
}

/// A rubber stamp, pressed a little crooked: double frame, heavy letters, uneven ink.
struct Stamp: View {
    var text: LocalizedStringKey
    var color: Color = Theme.stamp
    var size: CGFloat = 15
    var angle: Double = -7

    var body: some View {
        Text(text)
            .font(Theme.text(size, .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.3)
            .overlay(Rectangle().strokeBorder(color, lineWidth: size * 0.12).padding(size * 0.12))
            .overlay(Rectangle().strokeBorder(color, lineWidth: size * 0.07))
            .mask {
                // Worn ink: the stamp never prints perfectly.
                ZStack {
                    Rectangle()
                    Grain(density: 9).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .opacity(0.88)
            .rotationEffect(.degrees(angle))
            .accessibilityElement(children: .combine)
    }
}

/// The tutor's pen ring around a number or a word.
struct PenRing: View {
    var color: Color = Theme.red
    var lineWidth: CGFloat = 2

    var body: some View {
        InkEllipse()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .accessibilityHidden(true)
    }
}

/// A hand-drawn tick.
struct PenTick: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY),
                       control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY + rect.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.midY - rect.height * 0.1))
        return p
    }
}

/// A box you tick by hand, as on an exam sheet.
struct PenCheckbox: View {
    var isOn: Bool
    var color: Color = Theme.red

    var body: some View {
        ZStack {
            Rectangle().strokeBorder(Theme.ink, lineWidth: 1.2).frame(width: 16, height: 16)
            if isOn {
                PenTick()
                    .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 17, height: 14)
                    .offset(x: 2, y: -3)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
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

/// The app mark. Loads the "Logo" image from the app's asset catalog; elsewhere (CLI snapshots)
/// the arch is printed in toner, the way the paper inks every mark it carries.
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
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Theme.ink)
            ArchShape()
                .stroke(Theme.paper, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .square))
                .frame(width: size * 0.52, height: size * 0.62)
                .offset(y: size * 0.06)
            Circle()
                .fill(Theme.red)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(y: size * 0.14)
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
