import Foundation
import MoeedCore

public enum BlackboardError: Error, CustomStringConvertible, Equatable {
    /// The session ended; the student signs in again (the app never holds the password).
    case signedOut
    case http(Int, String)

    public var description: String {
        switch self {
        case .signedOut: "the Blackboard session has ended; sign in again"
        case let .http(status, body): "Blackboard answered \(status): \(body.prefix(200))"
        }
    }
}

/// Reads Blackboard Learn with the student's own session: the app signs in through a web view and
/// hands its cookies to `session`. It only sends GET requests; nothing on Blackboard is changed.
public struct BlackboardClient: Sendable {
    public var base: URL
    public var session: URLSession

    public init(base: URL, session: URLSession = .shared) {
        self.base = base
        self.session = session
    }

    /// The signed-in student. Succeeds only while the session is alive.
    public func me() async throws -> Blackboard.User {
        try await get("/learn/api/public/v1/users/me")
    }

    public func memberships() async throws -> [Blackboard.Membership] {
        try await all("/learn/api/public/v1/users/me/courses?expand=course&limit=100")
    }

    public func term(_ id: String) async throws -> Blackboard.Term {
        try await get("/learn/api/public/v1/terms/\(id)")
    }

    public func contents(of course: String) async throws -> [Blackboard.Content] {
        try await all("/learn/api/public/v1/courses/\(course)/contents?recursive=true&limit=200")
    }

    public func attachments(course: String, content: String) async throws -> [Blackboard.Attachment] {
        try await all("/learn/api/public/v1/courses/\(course)/contents/\(content)/attachments")
    }

    /// Saves the file at `destination`, replacing what was there only once the new copy has arrived.
    public func download(_ source: RemoteFile.Source, to destination: URL) async throws {
        let url = switch source {
        case let .attachment(course, content, attachment):
            address("/learn/api/public/v1/courses/\(course)/contents/\(content)/attachments/\(attachment)/download")
        case let .link(link):
            link
        }
        let (temporary, response) = try await session.download(for: request(url))
        defer { try? FileManager.default.removeItem(at: temporary) }
        try check(response, body: (try? Data(contentsOf: temporary)) ?? Data())
        // A file never comes back as a web page; a page here is the login screen.
        if (response as? HTTPURLResponse)?.mimeType == "text/html" { throw BlackboardError.signedOut }
        let files = FileManager.default
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if files.fileExists(atPath: destination.path) {
            _ = try files.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try files.moveItem(at: temporary, to: destination)
        }
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(for: request(address(path)))
        try check(response, body: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // An ended session is sent to the login page, which answers 200 with HTML.
            if data.first(where: { !Character(UnicodeScalar($0)).isWhitespace }) == UInt8(ascii: "<") {
                throw BlackboardError.signedOut
            }
            throw error
        }
    }

    /// Every page of a list.
    func all<T: Decodable>(_ path: String) async throws -> [T] {
        var items: [T] = []
        var next: String? = path
        var pages = 0
        while let current = next, pages < 100 {
            let page: Blackboard.Page<T> = try await get(current)
            items += page.results
            next = page.paging?.nextPage.flatMap { $0.isEmpty ? nil : $0 }
            pages += 1
        }
        return items
    }

    func address(_ path: String) -> URL {
        URL(string: path, relativeTo: base)!.absoluteURL
    }

    func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        return request
    }

    func check(_ response: URLResponse, body: @autoclosure () -> Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw BlackboardError.signedOut }
        guard (200..<300).contains(status) else {
            throw BlackboardError.http(status, String(decoding: body().prefix(300), as: UTF8.self))
        }
    }
}

/// Keeps a folder on the device in step with Blackboard: term / subject / Blackboard's folders / files.
/// New and changed files are downloaded. Nothing local is ever deleted; a file removed from Blackboard
/// is only marked as gone in the manifest.
public struct LibrarySyncer: Sendable {
    public static let manifestName = ".moeed-library.json"

    public var client: BlackboardClient
    public var root: URL

    public init(client: BlackboardClient, root: URL) {
        self.client = client
        self.root = root
    }

    /// What a sync is doing now, for the screen to say.
    public enum Progress: Sendable {
        /// Reading a subject's contents on Blackboard.
        case reading(subject: String)
        /// Fetching file `done + 1` of `total`.
        case downloading(done: Int, total: Int, name: String)
    }

    public struct Report: Sendable {
        /// Relative paths.
        public var new: [String] = []
        public var updated: [String] = []
        public var unchanged = 0
        public var gone: [String] = []
        /// Path and reason, for files that will be tried again next time.
        public var failed: [(path: String, reason: String)] = []
        /// Courses that couldn't be read (a closed section, say), and why.
        public var skipped: [(course: String, reason: String)] = []
    }

    /// Everything Blackboard has for the subjects open now, without downloading anything.
    public func scan(progress: @Sendable (Progress) -> Void = { _ in }) async throws -> (files: [RemoteFile], skipped: [(course: String, reason: String)]) {
        var terms: [String: String] = [:]
        var files: [RemoteFile] = []
        var skipped: [(course: String, reason: String)] = []
        for subject in Blackboard.subjects(try await client.memberships()) {
            let term = try await termName(subject.termId, known: &terms)
            progress(.reading(subject: subject.name))
            for course in subject.courseIds {
                do {
                    for found in Blackboard.files(in: try await client.contents(of: course)) {
                        switch found {
                        case let .embedded(file, folders):
                            files.append(RemoteFile(
                                key: file.id, folders: [term, subject.name] + folders, fileName: file.fileName,
                                version: "size:\(file.size ?? -1)", source: .link(file.url)
                            ))
                        case let .attachments(content, folders, modified):
                            for attachment in try await client.attachments(course: course, content: content) {
                                files.append(RemoteFile(
                                    key: "attachment:\(attachment.id)", folders: [term, subject.name] + folders,
                                    fileName: Blackboard.tidy(attachment.fileName ?? attachment.id),
                                    version: "modified:\(modified ?? "")",
                                    source: .attachment(course: course, content: content, attachment: attachment.id)
                                ))
                            }
                        }
                    }
                } catch let error as BlackboardError where error != .signedOut {
                    skipped.append((course, error.description))
                }
            }
        }
        return (files, skipped)
    }

    public func sync(now: Date = Date(), progress: @Sendable (Progress) -> Void = { _ in }) async throws -> Report {
        var manifest = loadManifest()
        let (remote, skipped) = try await scan(progress: progress)
        let plan = LibrarySync.plan(remote, against: manifest)
        var report = Report(unchanged: plan.unchanged, skipped: skipped)

        let fetch = plan.new.map { ($0, true) } + plan.updated.map { ($0, false) }
        for (done, (item, isNew)) in fetch.enumerated() {
            progress(.downloading(done: done, total: fetch.count, name: item.file.fileName))
            do {
                try await client.download(item.file.source, to: root.appendingPathComponent(item.path))
                LibrarySync.record(item, in: &manifest)
                if isNew { report.new.append(item.path) } else { report.updated.append(item.path) }
            } catch BlackboardError.signedOut {
                // Keep what already arrived; the rest comes after the student signs in again.
                try saveManifest(manifest)
                throw BlackboardError.signedOut
            } catch {
                report.failed.append((item.path, String(describing: error)))
            }
        }
        // Skipped courses hide their files; don't call those gone.
        if skipped.isEmpty {
            LibrarySync.markGone(plan.gone, in: &manifest)
            report.gone = plan.gone.compactMap { manifest.files[$0]?.path }
        }
        manifest.lastSync = now
        try saveManifest(manifest)
        return report
    }

    func termName(_ id: String?, known: inout [String: String]) async throws -> String {
        guard let id else { return "Other" }
        if let name = known[id] { return name }
        let name: String
        do {
            name = Blackboard.tidy(try await client.term(id).name ?? id)
        } catch BlackboardError.signedOut {
            throw BlackboardError.signedOut
        } catch {
            name = id
        }
        known[id] = name
        return name
    }

    var manifestURL: URL { root.appendingPathComponent(Self.manifestName) }

    public func loadManifest() -> LibraryManifest {
        guard let data = try? Data(contentsOf: manifestURL) else { return LibraryManifest() }
        return (try? Self.decoder.decode(LibraryManifest.self, from: data)) ?? LibraryManifest()
    }

    func saveManifest(_ manifest: LibraryManifest) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Self.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
