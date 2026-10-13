import SwiftUI
import MoeedCore

struct Sidebar: View {
    @Environment(AppRouter.self) private var router
    var reviewCount: Int

    init(reviewCount: Int = 7) {
        self.reviewCount = reviewCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 12) {
                LogoSlot()
                Text("مُعيد")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.white, Theme.mint], startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 4) {
                NavRow(title: "المكتبة", symbol: "books.vertical", isActive: router.route == .library) {
                    router.route = .library
                }
                NavRow(title: "المراجعة", symbol: "arrow.counterclockwise", isActive: router.route == .review) {
                    router.route = .review
                } trailing: {
                    Text(verbatim: String(reviewCount))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 22)
                        .background(Theme.sunset, in: Capsule())
                        .glow(Theme.pen, radius: 8, opacity: 0.7)
                }
                NavRow(title: "أسئلتي", symbol: "questionmark.circle", isActive: false) {
                } trailing: {
                    Text(verbatim: "3")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("موادي")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 14)
                HStack(spacing: 10) {
                    Text(verbatim: Samples.course.code)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.onBright)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(verbatim: Samples.course.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                Button { router.route = .importing } label: {
                    Label("أضف مادة", systemImage: "plus")
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Text("ملفاتك تبقى على جهازك. الشرح يتجهّز مرة وحدة لكل محاضرة.")
                .font(.system(size: 12.5))
                .lineSpacing(Theme.leading(for: 12.5) / 2)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(width: 248, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sidebar.opacity(0.72))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(LinearGradient(colors: [Theme.mint.opacity(0.25), Theme.line, .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 1)
        }
    }
}

private struct NavRow<Trailing: View>: View {
    var title: LocalizedStringKey
    var symbol: String
    var isActive: Bool
    var action: () -> Void
    let trailing: Trailing

    init(title: LocalizedStringKey, symbol: String, isActive: Bool, action: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.symbol = symbol
        self.isActive = isActive
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                Spacer(minLength: 0)
                trailing
            }
            .foregroundStyle(isActive ? Theme.mint : Theme.secondary)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background {
                if isActive {
                    let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    shape
                        .fill(LinearGradient(colors: [Theme.teal.opacity(0.24), Theme.teal.opacity(0.06)], startPoint: .leading, endPoint: .trailing))
                        .overlay(shape.strokeBorder(Theme.mint.opacity(0.28), lineWidth: 1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.mint).frame(width: 3, height: 22).glow(Theme.mint, radius: 6, opacity: 0.9)
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
