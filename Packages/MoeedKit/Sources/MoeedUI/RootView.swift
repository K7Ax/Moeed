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
                // «الأصلي» follows the system's light and dark. Home opens on a question.
                HomeAskView(now: now ?? Date())
                    .tint(Palette.accent)
            case .library:
                LibraryView().paper()
            case .review:
                ReviewView().paper()
            case .player:
                // A sheet rising over home, as Music's player does.
                TutorPlayerView(model: player)
                    .transition(.move(edge: .bottom))
            case .importing:
                ImportView().paper()
            }
        }
        .animation(.smooth(duration: 0.45), value: router.route)
        .environment(router)
        .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
        .preferredColorScheme(scheme)
    }

    /// Home follows the system, the player is always dark, and the paper screens are still light.
    private var scheme: ColorScheme? {
        switch router.route {
        case .home: nil
        case .player: .dark
        default: .light
        }
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
        // Home with the sidebar folded away, full screen.
        func full(_ name: String, _ scheme: ColorScheme) -> GalleryEntry {
            let view = HomeAskView(now: friday, sidebar: false)
                .environment(AppRouter(route: .home))
                .environment(\.colorScheme, scheme)
            return GalleryEntry(name: name, size: landscape, view: AnyView(view))
        }
        // The two homes not taken, kept for reference.
        func alternative<V: View>(_ name: String, _ view: V) -> GalleryEntry {
            GalleryEntry(name: name, size: landscape, view: AnyView(view.environment(AppRouter(route: .home)).environment(\.colorScheme, .light)))
        }
        func player(_ name: String, _ model: PlayerModel, size: CGSize = landscape) -> GalleryEntry {
            entry(name, RootView(route: .player, player: model), size: size)
        }
        // The same lesson, compiled from the TDP-L script the way a model's answer would be.
        let compiled = LessonCompiler.compile(
            source: Samples.sineScript, map: Samples.sineRegions,
            page: page.id, deckTitle: page.deckTitle, deckPageCount: page.deckPageCount
        ).page
        return [
            home("00-home-light", .light),
            home("00-home-dark", .dark),
            home("00-home-portrait", .light, size: portrait),
            full("00-home-fullscreen", .light),
            full("00-home-fullscreen-dark", .dark),
            player("02-player", PlayerModel.settled(page, step: 4, revealed: 1)),
            player("03-ask", PlayerModel.settled(page, step: 3)),
            player("04-ask-wrong", PlayerModel.settled(page, step: 3, picked: "zero")),
            player("05-ask-right", PlayerModel.settled(page, step: 3, picked: "neg")),
            player("06-player-later", PlayerModel.settled(page, step: 7, revealed: 1)),
            player("09-player-portrait", PlayerModel.settled(page, step: 4, revealed: 1), size: portrait),
            player("09-ask-portrait", PlayerModel.settled(page, step: 3, picked: "zero"), size: portrait),
            player("10-summary-spotlight", PlayerModel.settled(page, step: 8)),
            player("11-compiled-step", PlayerModel.settled(compiled, step: 4, revealed: 1)),
            player("11-compiled-ask", PlayerModel.settled(compiled, step: 3, picked: "b")),
            player("11-compiled-measure", PlayerModel.settled(compiled, step: 6, revealed: 2)),
            foundation(.light),
            foundation(.dark),
            alternative("90-home-a", HomeView(now: friday)),
            alternative("91-home-b", HomeNoteView(now: friday)),
            entry("01-library", RootView(route: .library)),
            entry("07-review", RootView(route: .review)),
            entry("08-import", RootView(route: .importing)),
        ]
    }
}

public extension Gallery {
    /// Every step of a lesson the engine wrote, as the player shows it once the step has played.
    @MainActor
    static func lesson(_ page: SlidePage, prefix: String) -> [GalleryEntry] {
        page.steps.indices.map { index in
            let model = PlayerModel.settled(page, step: index)
            let name = "\(prefix)-\(String(format: "%02d", index + 1))"
            return GalleryEntry(name: name, size: landscape, view: AnyView(RootView(route: .player, player: model)))
        }
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
