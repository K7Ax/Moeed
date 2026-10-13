import SwiftUI
import MoeedCore

/// The packet's index page, bound to the rest by a wire coil.
struct Sidebar: View {
    @Environment(AppRouter.self) private var router
    var reviewCount: Int

    init(reviewCount: Int = 7) {
        self.reviewCount = reviewCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                LogoSlot(size: 34)
                Text("مُعيد")
                    .font(Theme.text(30, .black))
                    .foregroundStyle(Theme.ink)
            }
            Text("ملزمة الشرح")
                .font(Theme.text(12.5, .medium))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 6)
            DoubleRule()
                .padding(.top, 14)

            Text("الفهرس")
                .font(Theme.text(12, .bold))
                .foregroundStyle(Theme.mark)
                .padding(.top, 22)
                .padding(.bottom, 6)

            IndexRow(title: "المكتبة", page: 1, isActive: router.route == .library) {
                router.route = .library
            }
            IndexRow(title: "المراجعة", page: 5, isActive: router.route == .review, count: reviewCount) {
                router.route = .review
            }
            IndexRow(title: "أسئلتي", page: 9, isActive: false, count: 3, quiet: true) {}

            Text("موادي")
                .font(Theme.text(12, .bold))
                .foregroundStyle(Theme.mark)
                .padding(.top, 26)
                .padding(.bottom, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: Samples.course.code)
                    .font(Theme.serif(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .environment(\.layoutDirection, .leftToRight)
                Text(verbatim: Samples.course.name)
                    .font(Theme.text(14.5, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(minHeight: 36)
            Hairline(color: Theme.rule)

            Button { router.route = .importing } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("أضف مادة")
                }
                .font(Theme.text(14.5, .medium))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Hairline(color: Theme.rule)
            Text("ملفاتك تبقى على جهازك. الشرح يتجهّز مرة وحدة لكل محاضرة.")
                .font(Theme.text(12, .regular))
                .lineSpacing(Theme.leading(for: 12) / 2)
                .foregroundStyle(Theme.mark)
                .padding(.top, 10)
        }
        .padding(.leading, 24)
        .padding(.trailing, 34)
        .padding(.vertical, 28)
        .frame(width: 260, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                Theme.paperShade
                Grain(density: 0.7)
            }
            .shadow(color: Theme.ink.opacity(0.14), radius: 6, x: 0, y: 0)
        }
        .overlay(alignment: .trailing) {
            Coil().frame(width: 26)
        }
        .zIndex(1)
    }
}

private struct IndexRow: View {
    var title: LocalizedStringKey
    var page: Int
    var isActive: Bool
    var count: Int?
    var quiet = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(Theme.text(16, isActive ? .heavy : .medium))
                    .foregroundStyle(isActive ? Theme.ink : Theme.inkSoft)
                    .highlighted(isActive, seed: page)
                if let count {
                    Text(verbatim: String(count))
                        .font(Theme.serif(13, .bold))
                        .foregroundStyle(quiet ? Theme.mark : Theme.red)
                        .frame(width: 22, height: 22)
                        .overlay { if !quiet { PenRing(lineWidth: 1.6).padding(-2) } }
                }
                Leader()
                Text(verbatim: "ص \(page)")
                    .font(Theme.serif(13, .regular))
                    .foregroundStyle(Theme.mark)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// The wire binding: punched holes down the edge, a coil loop through each.
struct Coil: View {
    var body: some View {
        Canvas { context, size in
            let pitch: CGFloat = 22
            var y: CGFloat = 18
            while y < size.height - 10 {
                // Canvas x runs from the sheet's outer edge (0) into the page.
                let hole = CGRect(x: size.width * 0.5, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: hole), with: .color(Theme.hole))
                context.stroke(Path(ellipseIn: hole), with: .color(Theme.ink.opacity(0.25)), lineWidth: 0.5)
                var loop = Path()
                loop.move(to: CGPoint(x: hole.midX, y: hole.midY))
                loop.addCurve(
                    to: CGPoint(x: hole.midX + 2, y: hole.midY + pitch * 0.42),
                    control1: CGPoint(x: -6, y: hole.midY - 4),
                    control2: CGPoint(x: -6, y: hole.midY + pitch * 0.5)
                )
                context.stroke(loop, with: .color(Color(hex: 0x3A3733)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                context.stroke(loop, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
                y += pitch
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
