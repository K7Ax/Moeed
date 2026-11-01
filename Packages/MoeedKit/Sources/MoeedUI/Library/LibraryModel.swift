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

    let base: URL
    let root: URL
    /// False for the gallery's samples: they never touch the disk, the Keychain or the network.
    let live: Bool
    /// The gallery's fixed clock, so "last synced" reads the same in every render.
    let fixedNow: Date?
    private let vault = SessionVault()
    private static let unseenKey = "library.unseen"
    private static let linkedKey = "library.linked"

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

    /// The library on this device.
    public static func onDevice() -> LibraryModel {
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
        phase = .idle
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

    /// Once a week on its own, as asked; the button syncs any time.
    public func syncIfDue() async {
        guard live, phase == .idle else { return }
        if let lastSync, now.timeIntervalSince(lastSync) < 7 * 24 * 3600 { return }
        await sync()
    }

    public func sync() async {
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
        } catch BlackboardError.signedOut {
            phase = .signedOut
        } catch {
            phase = .failed(Self.words(for: error))
        }
        // Blackboard may have renewed the session along the way.
        if let renewed = session.configuration.httpCookieStorage?.cookies, !renewed.isEmpty, phase != .signedOut {
            vault.save(renewed)
        }
        progress = nil
        reload()
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
