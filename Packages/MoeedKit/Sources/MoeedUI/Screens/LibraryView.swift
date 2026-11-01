import SwiftUI
import QuickLook
import MoeedCore

/// The library: Blackboard's terms and subjects as folders on the iPad. Linking happens once, on the
/// university's own sign-in page; after that each sync brings what the professors uploaded since the
/// last one, marked «جديد» until it's opened. A file removed from Blackboard stays, and says so.
struct LibraryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isSnapshot) private var isSnapshot
    @Bindable var model: LibraryModel
    @State private var sidebar = true
    @State private var term: String?
    @State private var preview: URL?

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 1000 {
                let side: CGFloat = sidebar ? HomeSidebar.width : 0
                HStack(alignment: .top, spacing: 0) {
                    if sidebar {
                        HomeSidebar(tab: .library, select: select, collapse: toggleSidebar)
                            .transition(.move(edge: .leading))
                    }
                    page(column: min(760, geo.size.width - side - 80))
                }
                .overlay(alignment: .topLeading) {
                    if !sidebar {
                        SidebarToggle(action: toggleSidebar)
                            .padding(18)
                            .transition(.opacity)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    page(column: min(680, geo.size.width - 48))
                    HomeTabBar(tab: .library, select: select)
                }
            }
        }
        .background(Palette.bg)
        .modifier(MotionPolicy())
        .sheet(isPresented: $model.showSignIn) {
            BlackboardSignIn(model: model)
        }
        .quickLookPreview($preview)
    }

    @ViewBuilder
    private func page(column: CGFloat) -> some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            header
                .rise(0)
            notice
                .padding(.top, 18)
                .rise(0.04)
            if model.shelf.terms.isEmpty {
                if model.isLinked {
                    waiting
                        .padding(.top, 40)
                        .rise(0.08)
                } else {
                    linkCard
                        .padding(.top, 36)
                        .rise(0.08)
                }
            } else {
                if model.shelf.terms.count > 1 {
                    termPicker
                        .padding(.top, 22)
                        .rise(0.08)
                }
                ForEach(Array(currentTerm.subjects.enumerated()), id: \.element.id) { index, subject in
                    section(subject)
                        .padding(.top, 34)
                        .rise(0.12 + Double(index) * 0.05)
                }
            }
        }
        .frame(width: column, alignment: .leading)
        .padding(.top, 56)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity)
        if isSnapshot {
            Color.clear
                .overlay(alignment: .top) { content }
                .clipped()
        } else {
            ScrollView { content }
                .refreshable { await model.sync() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("المكتبة")
                    .font(Typeface.plex(34, .semibold))
                    .foregroundStyle(Palette.text)
                Text(verbatim: status)
                    .font(Typeface.plex(14))
                    .foregroundStyle(Palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if model.isLinked {
                syncButton
            }
        }
    }

    private var status: String {
        switch model.phase {
        case .unlinked:
            return "ملفات موادك من بلاك بورد، مرتبة بالترم والمادة"
        case let .syncing(words):
            return words
        default:
            guard let last = model.lastSync else { return "مربوطة ببلاك بورد" }
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "ar@numbers=latn")
            formatter.unitsStyle = .full
            return "مربوطة ببلاك بورد · آخر مزامنة \(formatter.localizedString(for: last, relativeTo: model.now))"
        }
    }

    private var syncButton: some View {
        Button {
            if model.phase == .signedOut {
                model.showSignIn = true
            } else {
                Task { await model.sync() }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(.degrees(model.isSyncing ? 180 : 0))
                Text(model.isSyncing ? "يزامن…" : "زامن الآن")
                    .font(Typeface.plex(15, .medium))
            }
            .foregroundStyle(model.isSyncing ? Palette.text2 : Palette.text)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .overlay(Capsule().strokeBorder(Palette.sep, lineWidth: 0.5))
        }
        .buttonStyle(.press(0.95, hover: Palette.hover, radius: 19))
        .disabled(model.isSyncing)
    }

    // MARK: What's happening

    @ViewBuilder
    private var notice: some View {
        switch model.phase {
        case .syncing:
            ProgressLine(value: model.progress)
        case .signedOut:
            banner("انتهت جلستك في بلاك بورد. ادخل مرة ثانية ونكمل من حيث وقفنا.", action: "ادخل") {
                model.showSignIn = true
            }
        case let .failed(words):
            banner(words, action: "حاول مرة ثانية") {
                Task { await model.sync() }
            }
        default:
            EmptyView()
        }
    }

    private func banner(_ words: String, action: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: words)
                .font(Typeface.plex(15))
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: perform) {
                Text(action)
                    .font(Typeface.plex(15, .semibold))
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.press(0.95))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Not linked yet

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BrandLogo(size: 40)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text3)
                Image(systemName: "building.columns")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Palette.text)
                    .frame(width: 40, height: 40)
                    .background(Palette.raised2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Text("اربط حسابك في بلاك بورد")
                .font(Typeface.plex(26, .semibold))
                .foregroundStyle(Palette.text)
                .padding(.top, 20)
            Text("مُعيد يسوي لك مجلد لكل ترم، وداخله مجلد لكل مادة فيه ملفاتها، وكل أسبوع يجيب اللي نزّله الدكاترة.")
                .font(Typeface.plex(17))
                .foregroundStyle(Palette.text2)
                .lineSpacing(5)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 12) {
                point("تدخل بنفسك في صفحة الجامعة. مُعيد ما يشوف كلمة المرور ولا يحفظها.")
                point("يقرأ بس، ما يغيّر شي في بلاك بورد.")
                point("الملفات تنحفظ في الآيباد، وما ترتفع لأي مكان.")
            }
            .padding(.top, 22)
            Button { model.showSignIn = true } label: {
                Text("اربط بلاك بورد")
                    .font(Typeface.plex(17, .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 28)
                    .frame(height: 48)
                    .background(Palette.accent, in: Capsule())
            }
            .buttonStyle(.press(0.96, radius: 24))
            .padding(.top, 28)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func point(_ words: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
            Text(words)
                .font(Typeface.plex(15))
                .foregroundStyle(Palette.text)
        }
    }

    /// Linked, first sync not finished yet.
    private var waiting: some View {
        Text("أول مزامنة تجيب كل ملفات الترم، وتاخذ دقايق. تقدر تطلع من الشاشة وهي تكمل.")
            .font(Typeface.plex(16))
            .foregroundStyle(Palette.text2)
            .lineSpacing(4)
    }

    // MARK: Terms

    private var currentTerm: Shelf.Term {
        model.shelf.terms.first { $0.id == term } ?? model.shelf.terms[0]
    }

    private var termPicker: some View {
        HStack(spacing: 8) {
            ForEach(model.shelf.terms) { item in
                let on = item.id == currentTerm.id
                Button { withAnimation(.smooth(duration: 0.3)) { term = item.id } } label: {
                    Text(verbatim: Self.display(item.name))
                        .font(Typeface.plex(14, on ? .semibold : .regular))
                        .foregroundStyle(on ? Palette.accent : Palette.text)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(on ? Palette.accentSoft : Adaptive.fixed(.clear), in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Adaptive.fixed(.clear) : Palette.sep, lineWidth: 0.5))
                }
                .buttonStyle(.press(0.96, hover: on ? nil : Palette.hover, radius: 17))
            }
        }
    }

    /// Folder names can't hold "/", so «1448/1449» was saved as «1448-1449»; it reads back as it was.
    static func display(_ name: String) -> String {
        name == "Other" ? "أخرى" : name.replacingOccurrences(of: #"(\d{4})-(\d{4})"#, with: "$1/$2", options: .regularExpression)
    }

    // MARK: A subject

    private func section(_ subject: Shelf.Subject) -> some View {
        let fresh = subject.files.filter { model.unseen.contains($0.path) }.count
        let groups = Dictionary(grouping: subject.files) { $0.folders }
        let order = subject.files.map(\.folders).reduce(into: [[String]]()) { if !$0.contains($1) { $0.append($1) } }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: subject.name)
                    .font(Typeface.plex(21, .semibold))
                    .foregroundStyle(Palette.text)
                Text(verbatim: "\(subject.files.count.figures) ملف")
                    .font(Typeface.plex(13))
                    .foregroundStyle(Palette.text2)
                Spacer(minLength: 0)
                if fresh > 0 {
                    Text(verbatim: "\(fresh.figures) جديد")
                        .font(Typeface.plex(13, .medium))
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.bottom, 6)
            Rectangle().fill(Palette.sep).frame(height: 0.5)
            ForEach(order, id: \.self) { folders in
                if !folders.isEmpty {
                    Text(verbatim: folders.joined(separator: " · "))
                        .font(Typeface.plex(13, .medium))
                        .foregroundStyle(Palette.text2)
                        .padding(.top, 18)
                        .padding(.bottom, 2)
                }
                ForEach(groups[folders] ?? []) { file in
                    row(file)
                }
            }
        }
    }

    private func row(_ file: Shelf.File) -> some View {
        let isNew = model.unseen.contains(file.path)
        let ext = (file.name as NSString).pathExtension
        let title = ext.isEmpty ? file.name : String(file.name.dropLast(ext.count + 1))
        return VStack(spacing: 0) {
            Button { open(file) } label: {
                HStack(spacing: 14) {
                    FileGlyph(kind: ext)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: title)
                            .font(Typeface.plex(16, isNew ? .semibold : .regular))
                            .foregroundStyle(file.gone ? Palette.text2 : Palette.text)
                            .lineLimit(1)
                        if file.gone {
                            Text("انحذف من بلاك بورد · نسختك باقية")
                                .font(Typeface.plex(13))
                                .foregroundStyle(Palette.text2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if isNew {
                        Text("جديد")
                            .font(Typeface.plex(12, .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Palette.accentSoft, in: Capsule())
                    }
                }
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press(0.99, hover: Palette.hover, radius: 8))
            Rectangle().fill(Palette.sep).frame(height: 0.5)
                .padding(.leading, 48)
        }
    }

    // MARK: Actions

    private func open(_ file: Shelf.File) {
        guard model.live else { return }
        model.opened(file)
        preview = model.url(of: file)
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: 0.35)) { sidebar.toggle() }
    }

    private func select(_ next: HomeTab) {
        switch next {
        case .home: router.route = .home
        case .library: break
        case .review: router.route = .review
        case .importing: router.route = .importing
        }
    }
}

/// A file as a small page with its kind written at the foot.
private struct FileGlyph: View {
    let kind: String

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Palette.raised)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
            .overlay(alignment: .bottom) {
                Text(verbatim: kind.uppercased().prefix(4).description)
                    .font(Typeface.plex(8, .bold))
                    .foregroundStyle(Palette.text2)
                    .padding(.bottom, 5)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(width: 30, height: 38)
            .accessibilityHidden(true)
    }
}

/// How far the downloads have got; a quiet sweep while it's still reading Blackboard.
private struct ProgressLine: View {
    let value: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.fill)
                Capsule().fill(Palette.accent)
                    .frame(width: geo.size.width * (value ?? 0.12))
                    .animation(.smooth(duration: 0.4), value: value)
            }
        }
        .frame(height: 4)
    }
}
