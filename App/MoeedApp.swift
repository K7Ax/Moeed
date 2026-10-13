import SwiftUI
import MoeedUI

@main
struct MoeedApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
