import Observation
import SwiftUI
import MoeedCore

@MainActor
@Observable
public final class AppRouter {
    public enum Route: Hashable {
        case home, library, review, player, importing
    }

    public var route: Route

    public init(route: Route = .home) {
        self.route = route
    }
}

public struct RootView: View {
    @State private var router: AppRouter
    @State private var player: PlayerModel
    private let startExplaining: Bool
    private let now: Date?

    @MainActor
    public init(route: AppRouter.Route = .home, player: PlayerModel? = nil, startExplaining: Bool = false, now: Date? = nil) {
        _router = State(initialValue: AppRouter(route: route))
        _player = State(initialValue: player ?? PlayerModel(page: Samples.sinePage))
        self.startExplaining = startExplaining
        self.now = now
    }

    public var body: some View {
        Group {
            switch router.route {
            case .home:
                // «الأصلي» follows the system's light and dark.
                HomeView(now: now ?? Date())
                    .tint(Palette.accent)
            case .library:
                LibraryView().paper()
            case .review:
                ReviewView().paper()
            case .player:
                PlayerView(model: player, explaining: startExplaining).paper()
            case .importing:
                ImportView().paper()
            }
        }
        .environment(router)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(router.route == .home ? nil : .light)
    }
}

private extension View {
    /// The paper screens, not yet moved to «الأصلي», are always light with red ink.
    func paper() -> some View {
        environment(\.colorScheme, .light).tint(Theme.red)
    }
}

/// Every screen in a fixed state, for previews and CI screenshots.
public struct GalleryEntry {
    public let name: String
    public let size: CGSize
    public let view: AnyView
}

public enum Gallery {
    public static let landscape = CGSize(width: 1180, height: 820)
    public static let portrait = CGSize(width: 820, height: 1180)

    @MainActor
    public static func entries() -> [GalleryEntry] {
        let page = Samples.sinePage
        func entry(_ name: String, _ view: RootView, size: CGSize = landscape) -> GalleryEntry {
            GalleryEntry(name: name, size: size, view: AnyView(view))
        }
        func foundation(_ scheme: ColorScheme) -> GalleryEntry {
            GalleryEntry(
                name: "00-foundation-\(scheme == .dark ? "dark" : "light")",
                size: landscape,
                view: AnyView(FoundationSheet().environment(\.colorScheme, scheme))
            )
        }
        // A Friday in October, so the date line and the week stay the same in every render.
        let friday = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 16, hour: 10).date ?? Date()
        func home(_ name: String, _ scheme: ColorScheme, size: CGSize = landscape) -> GalleryEntry {
            GalleryEntry(name: name, size: size, view: AnyView(RootView(route: .home, now: friday).environment(\.colorScheme, scheme)))
        }
        // Home, take two (the tutor's note), beside the first for comparison.
        func note(_ name: String, _ scheme: ColorScheme, size: CGSize = landscape) -> GalleryEntry {
            let view = HomeNoteView(now: friday)
                .environment(AppRouter(route: .home))
                .environment(\.colorScheme, scheme)
            return GalleryEntry(name: name, size: size, view: AnyView(view))
        }
        return [
            note("00-home-b-light", .light),
            note("00-home-b-dark", .dark),
            note("00-home-b-portrait", .light, size: portrait),
            note("00-home-b-full", .light, size: CGSize(width: 1180, height: 1500)),
            foundation(.light),
            foundation(.dark),
            home("00-home-light", .light),
            home("00-home-dark", .dark),
            home("00-home-portrait", .light, size: portrait),
            home("00-home-full", .light, size: CGSize(width: 1180, height: 2160)),
            home("00-home-full-dark", .dark, size: CGSize(width: 1180, height: 2160)),
            entry("01-library", RootView(route: .library)),
            entry("02-player", RootView(route: .player, player: PlayerModel.settled(page, step: 4, revealed: 1))),
            entry("03-ask", RootView(route: .player, player: PlayerModel.settled(page, step: 3))),
            entry("04-ask-wrong", RootView(route: .player, player: PlayerModel.settled(page, step: 3, picked: "zero"))),
            entry("05-ask-right", RootView(route: .player, player: PlayerModel.settled(page, step: 3, picked: "neg"))),
            entry("06-explain", RootView(route: .player, player: PlayerModel.settled(page, step: 7), startExplaining: true)),
            entry("07-review", RootView(route: .review)),
            entry("08-import", RootView(route: .importing)),
            entry("09-player-portrait", RootView(route: .player, player: PlayerModel.settled(page, step: 4)), size: portrait),
            entry("10-summary-spotlight", RootView(route: .player, player: PlayerModel.settled(page, step: 8))),
        ]
    }
}

struct Gallery_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(Gallery.entries(), id: \.name) { entry in
            entry.view
                .frame(width: entry.size.width, height: entry.size.height)
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName(entry.name)
        }
    }
}
