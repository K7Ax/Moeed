import XCTest
import MoeedCore
@testable import MoeedEngine

/// A Blackboard that lives in memory: answers by path (and query, when one is given).
final class FakeBlackboard: URLProtocol {
    struct Reply {
        var status = 200
        var type = "application/json"
        var body: String
    }

    nonisolated(unsafe) static var replies: [String: Reply] = [:]
    nonisolated(unsafe) static var asked: [String] = []

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeBlackboard.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let withQuery = url.path + (url.query.map { "?" + $0 } ?? "")
        Self.asked.append(withQuery)
        let reply = Self.replies[withQuery] ?? Self.replies[url.path] ?? Reply(status: 404, body: "{}")
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: ["Content-Type": reply.type])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class BlackboardSyncTests: XCTestCase {
    private let api = "/learn/api/public/v1"
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("moeed-library-\(UUID().uuidString)")
        FakeBlackboard.asked = []
        FakeBlackboard.replies = [
            // Two pages of enrolments: the merged course, then a section of the same subject.
            "\(api)/users/me/courses": .init(body: #"""
            {"results": [{"courseId": "_11_1", "availability": {"available": "Yes"},
              "course": {"id": "_11_1", "courseId": "Merged_OS201_A_1_481", "name": "Operating Systems", "termId": "_9_1", "availability": {"available": "Yes"}}}],
             "paging": {"nextPage": "/learn/api/public/v1/users/me/courses?expand=course&limit=100&offset=1"}}
            """#),
            "\(api)/users/me/courses?expand=course&limit=100&offset=1": .init(body: #"""
            {"results": [{"courseId": "_10_1", "availability": {"available": "Yes"},
              "course": {"id": "_10_1", "courseId": "OS201_101_1_481", "name": "Operating Systems", "termId": "_9_1", "availability": {"available": "Term"}}}]}
            """#),
            "\(api)/terms/_9_1": .init(body: #"{"id": "_9_1", "name": "الفصل الأول 1448/1449"}"#),
            "\(api)/courses/_11_1/contents": .init(body: #"""
            {"results": [
              {"id": "_1", "parentId": "_root", "title": "Slides", "contentHandler": {"id": "resource/x-bb-folder"}},
              {"id": "_2", "parentId": "_1", "title": "Chapter 1", "modified": "2026-09-01T10:00:00.000Z", "contentHandler": {"id": "resource/x-bb-file"}},
              {"id": "_8", "parentId": "_root", "title": "Lab 1", "contentHandler": {"id": "resource/x-bb-asmt-test-link",
               "instructions": "<a data-bbfile=\"{&quot;fileName&quot;:&quot;Lab 1.pdf&quot;,&quot;fileSize&quot;:3,&quot;resourceUrl&quot;:&quot;https://bb.test/bbcswebdav/pid-8/xid-81_1?sig=a&amp;t=1&quot;}\">Lab 1</a>"}}
            ]}
            """#),
            // A closed section: its contents can't be read.
            "\(api)/courses/_10_1/contents": .init(status: 403, body: #"{"status": 403}"#),
            "\(api)/courses/_11_1/contents/_2/attachments": .init(body: #"{"results": [{"id": "_91_1", "fileName": "chapter1.pdf"}]}"#),
            "\(api)/courses/_11_1/contents/_2/attachments/_91_1/download": .init(type: "application/pdf", body: "%PDF one"),
            "/bbcswebdav/pid-8/xid-81_1": .init(type: "application/pdf", body: "lab"),
        ]
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func syncer() -> LibrarySyncer {
        LibrarySyncer(client: BlackboardClient(base: URL(string: "https://bb.test")!, session: FakeBlackboard.session()), root: root)
    }

    private func contents(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testTheFirstSyncBuildsTermSubjectAndFolders() async throws {
        let report = try await syncer().sync()

        XCTAssertEqual(report.new.sorted(), [
            "الفصل الأول 1448-1449/Operating Systems/Lab 1.pdf",
            "الفصل الأول 1448-1449/Operating Systems/Slides/chapter1.pdf",
        ])
        XCTAssertEqual(try contents("الفصل الأول 1448-1449/Operating Systems/Slides/chapter1.pdf"), "%PDF one")
        XCTAssertEqual(try contents("الفصل الأول 1448-1449/Operating Systems/Lab 1.pdf"), "lab")
        XCTAssertEqual(report.skipped.map { $0.course }, ["_10_1"])
        // Only reads: every request was a GET to the paths above, with the second page followed.
        XCTAssertTrue(FakeBlackboard.asked.contains("\(api)/users/me/courses?expand=course&limit=100&offset=1"))

        let manifest = syncer().loadManifest()
        XCTAssertEqual(manifest.files.count, 2)
        XCTAssertEqual(manifest.files["attachment:_91_1"]?.version, "modified:2026-09-01T10:00:00.000Z")
        XCTAssertNotNil(manifest.lastSync)
    }

    func testTheNextSyncFetchesOnlyWhatChanged() async throws {
        _ = try await syncer().sync()

        let quiet = try await syncer().sync()
        XCTAssertEqual(quiet.new, [])
        XCTAssertEqual(quiet.updated, [])
        XCTAssertEqual(quiet.unchanged, 2)

        // The professor replaces chapter 1.
        FakeBlackboard.replies["\(api)/courses/_11_1/contents"]?.body = FakeBlackboard.replies["\(api)/courses/_11_1/contents"]!.body
            .replacingOccurrences(of: "2026-09-01T10:00:00.000Z", with: "2026-10-05T08:00:00.000Z")
        FakeBlackboard.replies["\(api)/courses/_11_1/contents/_2/attachments/_91_1/download"]?.body = "%PDF two"
        let changed = try await syncer().sync()
        XCTAssertEqual(changed.updated, ["الفصل الأول 1448-1449/Operating Systems/Slides/chapter1.pdf"])
        XCTAssertEqual(try contents("الفصل الأول 1448-1449/Operating Systems/Slides/chapter1.pdf"), "%PDF two")
    }

    func testAFileRemovedFromBlackboardStaysOnTheDevice() async throws {
        _ = try await syncer().sync()
        FakeBlackboard.replies["\(api)/courses/_10_1/contents"] = .init(body: #"{"results": []}"#)
        FakeBlackboard.replies["\(api)/courses/_11_1/contents"] = .init(body: #"{"results": []}"#)

        let report = try await syncer().sync()
        XCTAssertEqual(report.gone.count, 2)
        XCTAssertEqual(try contents("الفصل الأول 1448-1449/Operating Systems/Lab 1.pdf"), "lab")
        XCTAssertEqual(syncer().loadManifest().files["xid-81_1"]?.gone, true)
    }

    func testAnEndedSessionAsksToSignInAgain() async throws {
        // Blackboard sends an ended session to its login page.
        FakeBlackboard.replies["\(api)/users/me/courses"] = .init(type: "text/html", body: "<!DOCTYPE html><html>Sign in</html>")
        do {
            _ = try await syncer().sync()
            XCTFail("expected signedOut")
        } catch {
            XCTAssertEqual(error as? BlackboardError, .signedOut)
        }

        FakeBlackboard.replies["\(api)/users/me/courses"] = .init(status: 401, body: "{}")
        do {
            _ = try await syncer().sync()
            XCTFail("expected signedOut")
        } catch {
            XCTAssertEqual(error as? BlackboardError, .signedOut)
        }
    }
}
