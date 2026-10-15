import Observation
import SwiftUI
import MoeedCore

@MainActor
@Observable
public final class AppRouter {
    public enum Route: Hashable {
        case library, review, player, importing
    }

    public var route: Route

    public init(route: Route = .library) {
        self.route = route
    }
}

public struct RootView: View {
    @State private var router: AppRouter
    @State private var player: PlayerModel
    private let startExplaining: Bool

    @MainActor
    public init(route: AppRouter.Route = .library, player: PlayerModel? = nil, startExplaining: Bool = false) {
        _router = State(initialValue: AppRouter(route: route))
        _player = State(initialValue: player ?? PlayerModel(page: Samples.sinePage))
        self.startExplaining = startExplaining
    }

    public var body: some View {
        Group {
            switch router.route {
            case .library:
                LibraryView()
            case .review:
                ReviewView()
            case .player:
                PlayerView(model: player, explaining: startExplaining)
            case .importing:
                ImportView()
            }
        }
        .environment(router)
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .tint(Theme.red)
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
        return [
            foundation(.light),
            foundation(.dark),
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
