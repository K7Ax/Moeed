import Foundation
import MoeedCore
#if os(iOS)
import BackgroundTasks
import UserNotifications
#endif

/// Keeps the library in step while the app is closed. iOS wakes the app for a short while
/// (a background app refresh) around the time the next sync is due; the sync runs, and what it
/// brought is told in a notification. A tap on it opens the library.
///
/// iOS decides the exact time and gives about half a minute. If that runs out mid-download, the files
/// already fetched are kept and the rest come on the next wake, within the hour.
/// Swift Playgrounds can't declare a background task, so there it does nothing and the sync runs
/// when the app opens. Off iOS (the CI renders) every call is empty.
@MainActor
public enum BackgroundSync {
    public static let identifier = "io.github.k7ax.moeed.sync"

    /// Called once while the app launches, before it finishes launching.
    public static func register(_ model: LibraryModel) {
        #if os(iOS)
        UNUserNotificationCenter.current().delegate = NotificationTaps.shared
        guard permitted else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            MainActor.assumeIsolated {
                let work = Task { await model.sync(background: true) }
                task.expirationHandler = { work.cancel() }
                Task {
                    await work.value
                    task.setTaskCompleted(success: !work.isCancelled)
                }
            }
        }
        #endif
    }

    static func schedule(at date: Date) {
        #if os(iOS)
        guard permitted else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = date
        // Replaces the one already waiting; fails only where background refresh is off.
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    static func askToNotify() {
        #if os(iOS)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif
    }

    static func notify(_ news: SyncNews.Message) {
        #if os(iOS)
        let content = UNMutableNotificationContent()
        content.title = news.title
        content.body = news.body
        content.sound = .default
        content.threadIdentifier = "library"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        #endif
    }

    #if os(iOS)
    /// Only an identifier listed in the app's Info.plist may be registered; any other is a crash.
    private static var permitted: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String])?.contains(identifier) == true
    }
    #endif
}

#if os(iOS)
/// Opens the library when a notification is tapped, and shows one that arrives while the app is open.
private final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTaps()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { LibraryModel.device.wantsFocus = true }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
#endif
