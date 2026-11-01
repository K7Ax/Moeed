import Foundation
import Observation
import MoeedCore
import MoeedEngine

/// The library behind the screen: what's on the shelf, whether Blackboard is linked, and the sync.
/// Files go to Documents/Blackboard/<term>/<subject>/<Blackboard's folders>/; nothing leaves the device.
@MainActor
@Observable
public final class LibraryModel {
    public enum Phase: Equatable {
        /// Never linked: the screen offers to link.
        case unlinked
        case idle
        /// A sync is running; the words say what it's doing.
        case syncing(String)
        /// The session ended; signing in again picks up where the sync stopped.
        case signedOut
        case failed(String)
    }

    /// KSU's Blackboard, the one this was built and checked against.
    public static let ksu = URL(string: "https://lms.ksu.edu.sa")!

    public internal(set) var phase: Phase
    public internal(set) var shelf: Shelf
    public internal(set) var lastSync: Date?
    /// 0...1 while files are downloading.
    public internal(set) var progress: Double?
    /// Files added or changed by a sync and not opened yet.
    public internal(set) var unseen: Set<String>
    public var showSignIn = false
    /// Set when the student taps a library notification: the app opens on the library.
    public var wantsFocus = false

    let base: URL
    let root: URL
    /// False for the gallery's samples: they never touch the disk, the Keychain or the network.
    let live: Bool
    /// The gallery's fixed clock, so "last synced" reads the same in every render.
    let fixedNow: Date?
    private let vault = SessionVault()
    private static let unseenKey = "library.unseen"
    private static let linkedKey = "library.linked"
    private static let nextSyncKey = "library.nextSync"
    private static let toldSignedOutKey = "library.toldSignedOut"

    /// As asked: Blackboard is read once a week. After a sync that couldn't finish, again within the hour.
    static let week: TimeInterval = 7 * 24 * 3600
    static let retry: TimeInterval = 3600

    init(phase: Phase, shelf: Shelf, lastSync: Date?, unseen: Set<String>, progress: Double? = nil,
         base: URL = LibraryModel.ksu, root: URL, live: Bool, now: Date? = nil) {
        self.phase = phase
        self.shelf = shelf
        self.lastSync = lastSync
        self.unseen = unseen
        self.progress = progress
        self.base = base
        self.root = root
        self.live = live
        self.fixedNow = now
    }

    /// The library on this device, shared by the screen and the background sync.
    public static let device = LibraryModel.onDevice()

    static func onDevice() -> LibraryModel {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let unseen = Set(UserDefaults.standard.stringArray(forKey: unseenKey) ?? [])
        let model = LibraryModel(
            phase: UserDefaults.standard.bool(forKey: linkedKey) ? .idle : .unlinked,
            shelf: Shelf(terms: []), lastSync: nil, unseen: unseen,
            root: documents.appendingPathComponent("Blackboard", isDirectory: true), live: true
        )
        model.reload()
        return model
    }

    var now: Date { fixedNow ?? Date() }
    public var isLinked: Bool { phase != .unlinked }
    public var isSyncing: Bool { if case .syncing = phase { true } else { false } }

    func url(of file: Shelf.File) -> URL {
        root.appendingPathComponent(file.path)
    }

    /// Opening a file takes away its «جديد».
    func opened(_ file: Shelf.File) {
        unseen.remove(file.path)
        saveUnseen()
    }

    // MARK: Linking

    /// The sign-in page found a working session.
    func linked(_ cookies: [HTTPCookie]) {
        showSignIn = false
        guard live else { return }
        vault.save(cookies)
        UserDefaults.standard.set(true, forKey: Self.linkedKey)
        UserDefaults.standard.set(false, forKey: Self.toldSignedOutKey)
        phase = .idle
        // The moment the student has just asked for new files is the moment to ask about telling them.
        BackgroundSync.askToNotify()
        Task { await sync() }
    }

    /// Forgets the session. The files already fetched stay where they are.
    public func unlink() {
        guard live else { return }
        vault.clear()
        UserDefaults.standard.set(false, forKey: Self.linkedKey)
        phase = .unlinked
    }

    // MARK: Sync

    /// When the next sync is due; nil until the first one.
    var nextSync: Date? {
        get {
            let stamp = UserDefaults.standard.double(forKey: Self.nextSyncKey)
            return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Self.nextSyncKey) }
    }

    /// On opening the app: syncs if it's due. The button syncs any time.
    public func syncIfDue() async {
        guard live, phase == .idle else { return }
        if let nextSync, now < nextSync { return }
        await sync()
    }

    /// Asks iOS to wake the app for the next sync (it decides exactly when).
    public func scheduleNext() {
        guard live, isLinked else { return }
        BackgroundSync.schedule(at: nextSync ?? now)
    }

    /// `background`: woken by iOS while the app is closed, so what arrived is told in a notification.
    public func sync(background: Bool = false) async {
        guard live, !isSyncing else { return }
        let cookies = vault.load()
        guard !cookies.isEmpty else {
            phase = isLinked ? .signedOut : .unlinked
            return
        }
        let session = Self.session(cookies)
        let syncer = LibrarySyncer(client: BlackboardClient(base: base, session: session), root: root)
        phase = .syncing("يقرأ موادك في بلاك بورد…")
        progress = nil
        do {
            let report = try await syncer.sync { step in
                Task { @MainActor [weak self] in self?.show(step) }
            }
            unseen.formUnion(report.new + report.updated)
            saveUnseen()
            phase = .idle
            nextSync = now.addingTimeInterval(report.failed.isEmpty ? Self.week : Self.retry)
            if background, let news = SyncNews.message(new: report.new, updated: report.updated) {
                BackgroundSync.notify(news)
            }
        } catch BlackboardError.signedOut {
            phase = .signedOut
            nextSync = now.addingTimeInterval(Self.week)
            // Said once; the library screen keeps saying it until the student signs in again.
            if background, !UserDefaults.standard.bool(forKey: Self.toldSignedOutKey) {
                UserDefaults.standard.set(true, forKey: Self.toldSignedOutKey)
                BackgroundSync.notify(.init(title: "بلاك بورد يبيك تدخل مرة ثانية", body: "انتهت الجلسة، فوقفت المزامنة. افتح مُعيد وادخل، ويكمل من حيث وقف."))
            }
        } catch {
            // iOS ending the background time is not a failure to show; the next try is within the hour.
            phase = Task.isCancelled ? .idle : .failed(Self.words(for: error))
            nextSync = now.addingTimeInterval(Self.retry)
        }
        // Blackboard may have renewed the session along the way.
        if let renewed = session.configuration.httpCookieStorage?.cookies, !renewed.isEmpty, phase != .signedOut {
            vault.save(renewed)
        }
        progress = nil
        reload()
        scheduleNext()
    }

    private func show(_ step: LibrarySyncer.Progress) {
        guard isSyncing else { return }
        switch step {
        case let .reading(subject):
            phase = .syncing("يقرأ \(subject)…")
        case let .downloading(done, total, name):
            phase = .syncing("يجيب \(name)")
            progress = Double(done) / Double(max(total, 1))
        }
    }

    func reload() {
        guard live else { return }
        let manifest = LibrarySyncer(client: BlackboardClient(base: base), root: root).loadManifest()
        shelf = Shelf(manifest)
        lastSync = manifest.lastSync
    }

    private func saveUnseen() {
        guard live else { return }
        UserDefaults.standard.set(Array(unseen).sorted(), forKey: Self.unseenKey)
    }

    /// A session that carries the student's cookies and nothing else.
    nonisolated static func session(_ cookies: [HTTPCookie]) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        for cookie in cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        return URLSession(configuration: configuration)
    }

    static func words(for error: Error) -> String {
        if let error = error as? URLError, error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            return "ما فيه اتصال بالإنترنت. نكمل لما يرجع."
        }
        return "ما قدرنا نكمل المزامنة. جرّب بعد شوي."
    }
}

// MARK: - Samples

extension LibraryModel {
    /// A made-up term for the gallery: two subjects, a few lectures, one new chapter.
    static func sample(_ phase: Phase = .idle, progress: Double? = nil, now: Date) -> LibraryModel {
        let term = "الفصل الأول 1448-1449"
        let older = "الفصل الثاني 1447-1448"
        let paths: [(String, Bool)] = [
            ("\(term)/الدوائر الكهربائية/Syllabus.pdf", false),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 1 - Basic Concepts.pdf", false),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 2 - Basic Laws.pdf", false),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 3 - Methods of Analysis.pdf", false),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 4 - Circuit Theorems (draft).pdf", true),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 4 - Circuit Theorems.pdf", false),
            ("\(term)/الدوائر الكهربائية/Lectures/Chapter 5 - Sinusoids and Phasors.pdf", false),
            ("\(term)/الدوائر الكهربائية/Labs/Lab 4 - Kirchhoff.pdf", false),
            ("\(term)/الإلكترونيات/Lectures/Diodes.pdf", false),
            ("\(term)/الإلكترونيات/Lectures/Diode Applications.pptx", false),
            ("\(term)/الإلكترونيات/Homework/HW 2.pdf", false),
            ("\(older)/التفاضل والتكامل/Final review.pdf", false),
        ]
        var manifest = LibraryManifest()
        for (index, (path, gone)) in paths.enumerated() {
            manifest.files["\(index)"] = .init(path: path, version: "v1", gone: gone)
        }
        let unseen: Set<String> = [
            "\(term)/الدوائر الكهربائية/Lectures/Chapter 5 - Sinusoids and Phasors.pdf",
            "\(term)/الدوائر الكهربائية/Labs/Lab 4 - Kirchhoff.pdf",
            "\(term)/الإلكترونيات/Lectures/Diode Applications.pptx",
        ]
        let empty = phase == .unlinked
        return LibraryModel(
            phase: phase, shelf: empty ? Shelf(terms: []) : Shelf(manifest),
            lastSync: empty ? nil : now.addingTimeInterval(-2 * 3600), unseen: empty ? [] : unseen,
            progress: progress, root: URL(fileURLWithPath: "/dev/null"), live: false, now: now
        )
    }
}
