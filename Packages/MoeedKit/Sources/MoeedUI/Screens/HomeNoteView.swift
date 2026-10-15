import MoeedCore
import SwiftUI

/// Home, take two: the tutor's note instead of a dashboard. One sentence says what's left today,
/// the tutor's ink underlines the one thing to do, the slide is the hero, and everything else is
/// type and hairlines. No cards, one progress figure, three motions (the page settling in, the
/// ink writing, the press under the finger).
public struct HomeNoteView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var tab: HomeTab = .home
    private let now: Date

    public init(now: Date = Date()) {
        self.now = now
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            if wide {
                HStack(alignment: .top, spacing: 0) {
                    HomeSidebar(tab: tab, select: select)
                    page(column: min(900, geo.size.width - HomeSidebar.width - 80), wide: true)
                }
            } else {
                VStack(spacing: 0) {
                    page(column: geo.size.width - 48, wide: false)
                    HomeTabBar(tab: tab, select: select)
                }
            }
        }
        .background(Palette.bg)
        .environment(\.inkColor, Stage.pen)
        .modifier(MotionPolicy())
    }

    @ViewBuilder
    private func page(column: CGFloat, wide: Bool) -> some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            note(wide: wide).rise(0)
            resume(column: column, wide: wide)
                .padding(.top, wide ? 36 : 28)
                .rise(0.08)
            review
                .padding(.top, 52)
                .rise(0.16)
            shelf(column: column)
                .padding(.top, 52)
                .rise(0.22)
        }
        .frame(width: column, alignment: .leading)
        .padding(.top, wide ? 34 : 18)
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity)
        if isSnapshot {
            Color.clear
                .overlay(alignment: .top) { content }
                .clipped()
        } else {
            ScrollView { content }
        }
    }

    // MARK: The note

    /// «باقي لك ٢٥ دقيقة على الموجات الجيبية، وعندك ٧ أسئلة غلطت فيها.» with the lecture underlined in ink.
    private func note(wide: Bool) -> some View {
        let size: CGFloat = wide ? 36 : 30
        let lecture = Samples.resume.lecture
        let due = Samples.reviewItems.count + 2
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(verbatim: HomeDate.line(now))
                Spacer(minLength: 0)
                if !wide { BrandLogo(size: 28) }
            }
            .font(Typeface.plex(13, .medium))
            .foregroundStyle(Palette.text2)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("باقي لك ٢٥ دقيقة على ")
                    .foregroundStyle(Palette.text2)
                Text(verbatim: lecture.arabicTitle)
                    .font(Typeface.plex(size, .semibold))
                    .foregroundStyle(Palette.text)
                    .overlay(alignment: .bottom) {
                        InkOn(shape: InkUnderline(), color: Palette.ink, lineWidth: 3, duration: 0.7, delay: 0.55)
                            .frame(height: 10)
                            .padding(.horizontal, -4)
                            .offset(y: 8)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                Text("،")
                    .foregroundStyle(Palette.text2)
            }
            .font(Typeface.plex(size, .regular))
            .padding(.top, 14)
            Text(verbatim: "وعندك \(due.eastern) أسئلة غلطت فيها.")
                .font(Typeface.plex(size, .regular))
                .foregroundStyle(Palette.text2)
                .padding(.top, 2)
        }
    }

    // MARK: Where you stopped

    private func resume(column: CGFloat, wide: Bool) -> some View {
        let slide: CGFloat = wide ? (column * 0.56).rounded() : column
        let layout = wide ? AnyLayout(HStackLayout(alignment: .bottom, spacing: 36)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        return layout {
            if !wide { artwork(width: slide) }
            meta.frame(maxWidth: .infinity, alignment: .leading)
            if wide { artwork(width: slide) }
        }
    }

    private func artwork(width: CGFloat) -> some View {
        Button(action: play) {
            LiveArtwork()
                .frame(width: width, height: (width * 0.75).rounded())
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
        }
        .buttonStyle(.press(0.985, radius: 10))
        .accessibilityLabel("أكمل الشرح")
    }

    private var meta: some View {
        let resume = Samples.resume
        let lecture = resume.lecture
        return VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "المحاضرة \(HomeDate.ordinal(lecture.number)) · صفحة \(resume.page.eastern) من \(lecture.slideCount.eastern)")
                .font(Typeface.plex(13, .medium))
                .foregroundStyle(Palette.text2)
            Text(verbatim: resume.stepTitle)
                .font(Typeface.plex(22, .semibold))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Text(verbatim: "الخطوة \(resume.step.eastern) من \(resume.stepCount.eastern)")
                .font(Typeface.plex(15))
                .foregroundStyle(Palette.text2)
                .padding(.top, 4)
            Button(action: play) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                    Text("أكمل").font(Typeface.plex(16, .semibold))
                }
                .foregroundStyle(Palette.bg)
                .padding(.horizontal, 22)
                .frame(height: 44)
                .background(Palette.text, in: Capsule())
            }
            .buttonStyle(.press(0.95, radius: 22))
            .padding(.top, 22)
        }
    }

    // MARK: Review

    private static let due = ["اليوم", "اليوم", "بكرة", "بعد ٣ أيام", "بعد أسبوع"]

    private var review: some View {
        let items = Array(Samples.reviewItems.prefix(3))
        return VStack(alignment: .leading, spacing: 0) {
            NoteHead(title: "للمراجعة", detail: (Samples.reviewItems.count + 2).eastern, action: "ابدأ") { select(.review) }
            ForEach(Array(items.enumerated()), id: \.element.id) { k, item in
                if k > 0 { Rectangle().fill(Palette.sep).frame(height: 0.5) }
                Button { select(.review) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(verbatim: NoteText.isolate(item.question))
                            .font(Typeface.plex(17))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(verbatim: Self.due[k])
                            .font(Typeface.plex(13, k < 2 ? .semibold : .regular))
                            .foregroundStyle(k < 2 ? Palette.accent : Palette.text2)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press(0.99, radius: 0))
            }
        }
    }

    // MARK: The course

    private func shelf(column: CGFloat) -> some View {
        let done = Samples.shelf.filter { CoverState($0) == .done }.count
        let row = HStack(alignment: .top, spacing: 16) {
            ForEach(Samples.shelf) { lecture in
                NoteCover(lecture: lecture)
            }
        }
        return VStack(alignment: .leading, spacing: 0) {
            NoteHead(title: Samples.course.name, detail: "\(done.eastern) من ١٢", action: "المكتبة") { select(.library) }
                .padding(.bottom, 16)
            Group {
                if isSnapshot {
                    row.fixedSize().frame(width: column, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { row }
                        .scrollClipDisabled()
                }
            }
            // The covers sit still here; the shelf is for finding, not for watching.
            .environment(\.motionOff, true)
        }
    }

    private func play() {
        router.route = .player
    }

    private func select(_ next: HomeTab) {
        tab = next
        switch next {
        case .home: break
        case .library: router.route = .library
        case .review: router.route = .review
        case .importing: router.route = .importing
        }
    }
}

/// A section's name set like a newspaper's: title, a quiet count, one link, and a full rule.
private struct NoteHead: View {
    let title: String
    let detail: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: title)
                    .font(Typeface.plex(20, .bold))
                    .foregroundStyle(Palette.text)
                Text(verbatim: detail)
                    .font(Typeface.plex(15))
                    .foregroundStyle(Palette.text3)
                Spacer(minLength: 0)
                Button(action: onAction) {
                    Text(verbatim: action)
                        .font(Typeface.plex(15, .medium))
                        .foregroundStyle(Palette.accent)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.press(0.94))
            }
            .padding(.bottom, 10)
            Rectangle().fill(Palette.text).frame(height: 1)
        }
    }
}

private struct NoteCover: View {
    let lecture: Lecture

    var body: some View {
        let state = CoverState(lecture)
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(Cover.samples[lecture.number - 1], size: 124, state: state)
            Text(verbatim: lecture.arabicTitle)
                .font(Typeface.plex(14, .medium))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .padding(.top, 9)
            Text(verbatim: caption(state))
                .font(Typeface.plex(12))
                .foregroundStyle(Palette.text2)
                .lineLimit(1)
        }
        .frame(width: 124, alignment: .leading)
    }

    private func caption(_ state: CoverState) -> String {
        switch state {
        case let .preparing(progress): "يتجهّز · \(Int((progress * 100).rounded()).eastern)٪"
        case .current: "وصلت صفحة \(Samples.resume.page.eastern)"
        default: "\(lecture.slideCount.eastern) صفحة"
        }
    }
}

private enum NoteText {
    /// Math between backticks, held left-to-right inside the Arabic line.
    static func isolate(_ text: String) -> String {
        let parts = text.eastern.split(separator: "`", omittingEmptySubsequences: false)
        var joined = ""
        for (k, part) in parts.enumerated() {
            let piece = String(part)
            joined += k % 2 == 1 ? "\u{2066}" + piece + "\u{2069}" : piece
        }
        return "\u{200F}" + joined
    }
}

/// The tutor's pen under a word: laid down right to left, as Arabic is written, dipping a little
/// in the middle and lifting at the end.
struct InkUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        let w: Double = Double(rect.width)
        let h: Double = Double(rect.height)
        let x0: Double = Double(rect.minX)
        let y0: Double = Double(rect.minY)
        var path = Path()
        path.move(to: CGPoint(x: x0 + w, y: y0 + h * 0.35))
        path.addQuadCurve(to: CGPoint(x: x0 + w * 0.45, y: y0 + h * 0.62), control: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.62))
        path.addQuadCurve(to: CGPoint(x: x0, y: y0 + h * 0.3), control: CGPoint(x: x0 + w * 0.15, y: y0 + h * 0.6))
        return path
    }
}
