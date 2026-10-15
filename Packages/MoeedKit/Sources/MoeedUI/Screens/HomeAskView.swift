import MoeedCore
import SwiftUI

/// Home, take three: it opens on a question, the way an AI app does. «وش تبي تتعلم اليوم؟» over a
/// composer that knows your course, suggestions taken from where you actually are, and one quiet
/// line for the lecture you stopped in. The tutor's ink underlines «اليوم»; nothing else moves.
public struct HomeAskView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var tab: HomeTab = .home
    @State private var draft = ""
    @State private var sidebar: Bool
    private let now: Date

    /// `sidebar: false` opens with the sidebar folded away and the page full screen.
    public init(now: Date = Date(), sidebar: Bool = true) {
        self.now = now
        _sidebar = State(initialValue: sidebar)
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            if wide {
                let side: CGFloat = sidebar ? HomeSidebar.width : 0
                HStack(alignment: .top, spacing: 0) {
                    if sidebar {
                        HomeSidebar(tab: tab, select: select, collapse: toggleSidebar)
                            .transition(.move(edge: .leading))
                    }
                    page(column: min(720, geo.size.width - side - 80), height: geo.size.height, wide: true)
                }
                .overlay(alignment: .topLeading) {
                    if !sidebar {
                        SidebarToggle(action: toggleSidebar)
                            .padding(.top, 18)
                            .padding(.horizontal, 18)
                            .transition(.opacity)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    page(column: min(680, geo.size.width - 48), height: geo.size.height, wide: false)
                    HomeTabBar(tab: tab, select: select)
                }
            }
        }
        .background(Palette.bg)
        .environment(\.inkColor, Stage.pen)
        .modifier(MotionPolicy())
    }

    @ViewBuilder
    private func page(column: CGFloat, height: CGFloat, wide: Bool) -> some View {
        let content = VStack(spacing: 0) {
            Text(verbatim: HomeDate.line(now))
                .font(Typeface.plex(13, .medium))
                .foregroundStyle(Palette.text2)
                .rise(0)
            question(wide: wide)
                .padding(.top, 10)
                .rise(0.04)
            composer
                .padding(.top, 30)
                .rise(0.1)
            suggestions(column: column)
                .padding(.top, 18)
                .rise(0.16)
            lastPlace
                .padding(.top, 56)
                .rise(0.24)
        }
        .frame(width: column)
        .padding(.top, wide ? max(60, height * 0.16) : 70)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity)
        if isSnapshot {
            Color.clear
                .overlay(alignment: .top) { content }
                .clipped()
        } else {
            ScrollView { content }
                .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: The question

    private func question(wide: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("وش تبي تتعلم ")
            Text("اليوم")
                .overlay(alignment: .bottom) {
                    InkOn(shape: InkUnderline(), color: Palette.ink, lineWidth: 3, duration: 0.6, delay: 0.45)
                        .frame(height: 10)
                        .padding(.horizontal, -4)
                        .offset(y: 8)
                        .environment(\.layoutDirection, .leftToRight)
                }
            Text("؟")
        }
        .font(Typeface.plex(wide ? 40 : 34, .semibold))
        .foregroundStyle(Palette.text)
    }

    // MARK: The composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 0) {
            field
                .frame(minHeight: 56, alignment: .topLeading)
            HStack(spacing: 8) {
                Button { select(.importing) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.text2)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Palette.sep, lineWidth: 0.5))
                }
                .buttonStyle(.press(0.9, hover: Palette.hover, radius: 18))
                .accessibilityLabel("ارفع محاضرة")
                Button {} label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Cover.samples[4].color)
                            .frame(width: 12, height: 12)
                        Text(verbatim: Samples.course.name)
                            .font(Typeface.plex(14, .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Palette.text2)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(Capsule().strokeBorder(Palette.sep, lineWidth: 0.5))
                }
                .buttonStyle(.press(0.95, hover: Palette.hover, radius: 18))
                Spacer(minLength: 0)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.bg)
                        .frame(width: 36, height: 36)
                        .background(draft.isEmpty ? Palette.text3 : Palette.text, in: Circle())
                }
                .buttonStyle(.press(0.9, radius: 18))
                .disabled(draft.isEmpty)
                .accessibilityLabel("أرسل")
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
    }

    private static let placeholder = "اسأل عن أي شي في محاضراتك، أو ارفع محاضرة جديدة…"

    @ViewBuilder
    private var field: some View {
        if isSnapshot {
            HStack(spacing: 2) {
                Capsule().fill(Palette.ink).frame(width: 2, height: 22)
                Text(verbatim: Self.placeholder)
                    .font(Typeface.plex(17))
                    .foregroundStyle(Palette.text3)
            }
            .padding(.horizontal, 4)
        } else {
            TextField(text: $draft, prompt: Text(verbatim: Self.placeholder).foregroundStyle(Palette.text3), axis: .vertical) {
                Text("سؤالك")
            }
            .font(Typeface.plex(17))
            .foregroundStyle(Palette.text)
            .tint(Palette.ink)
            .lineLimit(1...6)
            .padding(.horizontal, 4)
            .onSubmit(send)
        }
    }

    // MARK: Suggestions

    private struct Suggestion: Identifiable {
        let id: Int
        let label: String
        let action: HomeTab?
    }

    /// Taken from where you are, not generic prompts: the lecture you're in, the questions you got
    /// wrong, the lecture you finished last, and the one being prepared.
    private static let suggestions: [[Suggestion]] = [
        [
            Suggestion(id: 0, label: "أكمل الموجات الجيبية", action: nil),
            Suggestion(id: 1, label: "راجع أخطائي · 7", action: .review),
            Suggestion(id: 2, label: "اختبرني على كيرشوف", action: .review),
        ],
        [
            Suggestion(id: 3, label: "لخّص لي المكثّفات والملفّات", action: .library),
            Suggestion(id: 4, label: "وش الطور قبل المحاضرة؟", action: .library),
        ],
    ]

    private func suggestions(column: CGFloat) -> some View {
        VStack(spacing: 10) {
            ForEach(Self.suggestions.indices, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(Self.suggestions[r]) { s in
                        Button { if let target = s.action { select(target) } else { play() } } label: {
                            Text(verbatim: s.label)
                                .font(Typeface.plex(15))
                                .foregroundStyle(Palette.text)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .overlay(Capsule().strokeBorder(Palette.sep, lineWidth: 0.5))
                        }
                        .buttonStyle(.press(0.95, hover: Palette.hover, radius: 19))
                    }
                }
            }
        }
        .frame(width: column)
    }

    // MARK: Where you stopped

    private var lastPlace: some View {
        let resume = Samples.resume
        return VStack(alignment: .leading, spacing: 0) {
            Text("آخر شي كنت فيه")
                .font(Typeface.plex(13, .medium))
                .foregroundStyle(Palette.text2)
                .padding(.bottom, 10)
            Rectangle().fill(Palette.sep).frame(height: 0.5)
            Button(action: play) {
                HStack(spacing: 14) {
                    SlideStage(page: Samples.sinePage, pastMarks: LiveArtwork.pastInk)
                        .frame(width: 88, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: resume.stepTitle)
                            .font(Typeface.plex(16, .semibold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                        Text(verbatim: "\(resume.lecture.arabicTitle) · الخطوة \(resume.step.figures) من \(resume.stepCount.figures)")
                            .font(Typeface.plex(13))
                            .foregroundStyle(Palette.text2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("أكمل")
                        .font(Typeface.plex(15, .medium))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press(0.99, radius: 0))
            Rectangle().fill(Palette.sep).frame(height: 0.5)
        }
    }

    // MARK: Actions

    private func send() {
        guard !draft.isEmpty else { return }
        draft = ""
        play()
    }

    private func play() {
        router.route = .player
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: 0.35)) { sidebar.toggle() }
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
