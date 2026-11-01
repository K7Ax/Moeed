import SwiftUI
import MoeedUI

@main
struct MoeedApp: App {
    init() {
        // Before launch finishes, as iOS requires of a background task's handler.
        BackgroundSync.register(.device)
    }

    var body: some Scene {
        WindowGroup {
            RootView(library: .device)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
