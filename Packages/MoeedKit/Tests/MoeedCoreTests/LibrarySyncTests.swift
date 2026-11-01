import XCTest
@testable import MoeedCore

/// Fixtures are shaped like Blackboard Learn's public API answers; the names and ids are made up.
final class LibrarySyncTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private let memberships = #"""
    {"results": [
      {"courseId": "_10_1", "availability": {"available": "Yes"},
       "course": {"id": "_10_1", "courseId": "OS201_101_1_481", "name": "Operating Systems", "termId": "_9_1", "availability": {"available": "Term"}}},
      {"courseId": "_11_1", "availability": {"available": "Yes"},
       "course": {"id": "_11_1", "courseId": "Merged_OS201_A_1_481", "name": "\tOperating  Systems\t", "termId": "_9_1", "availability": {"available": "Yes"}}},
      {"courseId": "_12_1", "availability": {"available": "Yes"},
       "course": {"id": "_12_1", "courseId": "OS201_102_1_481", "name": "Operating Systems", "termId": "_9_1", "availability": {"available": "No"}}},
      {"courseId": "_13_1", "availability": {"available": "Disabled"},
       "course": {"id": "_13_1", "courseId": "OS201_103_1_481", "name": "Operating Systems", "termId": "_9_1", "availability": {"available": "Term"}}},
      {"courseId": "_20_1", "availability": {"available": "Yes"},
       "course": {"id": "_20_1", "courseId": "COM301_201_1_481", "name": "Data Communication", "termId": "_9_1", "availability": {"available": "Term"}}},
      {"courseId": "_30_1", "availability": {"available": "Disabled"},
       "course": {"id": "_30_1", "courseId": "Merged_LA101_A_1_472", "name": "Linear Algebra", "termId": "_8_1", "availability": {"available": "Yes"}}}
    ]}
    """#

    func testSectionsOfOneSubjectShareAFolderAndClosedOnesAreLeftOut() throws {
        let page: Blackboard.Page<Blackboard.Membership> = try decode(memberships)
        let subjects = Blackboard.subjects(page.results)
        XCTAssertEqual(subjects.map(\.name), ["Operating Systems", "Data Communication"])
        // The merged course comes first; the closed section and the disabled enrolment are skipped.
        XCTAssertEqual(subjects.first?.courseIds, ["_11_1", "_10_1"])
        XCTAssertEqual(subjects.first?.termId, "_9_1")
    }

    /// One course: a Slides folder of file items, a syllabus page (an Ultra document, stored as a folder
    /// holding its body) with a linked file, and an assignment whose instructions link a lab sheet.
    private let contents = #"""
    {"results": [
      {"id": "_1", "parentId": "_root", "title": "Slides", "contentHandler": {"id": "resource/x-bb-folder"}},
      {"id": "_2", "parentId": "_1", "title": "Chapter 1", "modified": "2026-09-01T10:00:00.000Z",
       "contentHandler": {"id": "resource/x-bb-file", "file": {"fileName": "chapter1.pdf"}}},
      {"id": "_3", "parentId": "_1", "title": "Draft", "availability": {"available": "No"},
       "contentHandler": {"id": "resource/x-bb-file"}},
      {"id": "_4", "parentId": "_root", "title": "Syllabus", "contentHandler": {"id": "resource/x-bb-folder"}},
      {"id": "_5", "parentId": "_4", "title": "Course Syllabus", "contentHandler": {"id": "resource/x-bb-folder", "isBbPage": true}},
      {"id": "_6", "parentId": "_5", "title": "ultraDocumentBody", "contentHandler": {"id": "resource/x-bb-document"},
       "body": "<p>Read this.</p><a href=\"x\" data-bbtype=\"attachment\" data-bbfile=\"{&quot;displayName&quot;:&quot;Syllabus.pdf&quot;,&quot;fileName&quot;:&quot;Syllabus.pdf&quot;,&quot;fileSize&quot;:1200,&quot;resourceUrl&quot;:&quot;https://bb.test/bbcswebdav/pid-6-dt-content-rid-61_1/xid-61_1?a=1&amp;b=2&quot;}\">Syllabus.pdf</a>"},
      {"id": "_7", "parentId": "_root", "title": "Labs\t", "contentHandler": {"id": "resource/x-bb-folder"}},
      {"id": "_8", "parentId": "_7", "title": "Lab 1", "contentHandler": {"id": "resource/x-bb-asmt-test-link",
       "instructions": "<p>Sheet:</p><a data-bbtype=\"attachment\" data-bbfile=\"{&quot;displayName&quot;:&quot;lab1.JPG&quot;,&quot;fileName&quot;:&quot;lab1.JPG.jpg&quot;,&quot;fileSize&quot;:300,&quot;resourceUrl&quot;:&quot;https://bb.test/bbcswebdav/pid-8-dt-asiobject-rid-81_1/xid-81_1?a=1&quot;}\">lab1</a><a data-bbfile=\"{&quot;displayName&quot;:&quot;Lab 1 sheet&quot;,&quot;fileName&quot;:&quot;Lab 1 sheet.pdf&quot;,&quot;resourceUrl&quot;:&quot;https://bb.test/bbcswebdav/pid-8-dt-asiobject-rid-82_1/xid-82_1&quot;}\">x</a>"}}
    ]}
    """#

    func testTheWalkFindsFileItemsAndLinkedFilesUnderTheirFolders() throws {
        let page: Blackboard.Page<Blackboard.Content> = try decode(contents)
        let found = Blackboard.files(in: page.results)
        XCTAssertEqual(found.count, 4)
        XCTAssertEqual(found.first, .attachments(content: "_2", folders: ["Slides"], modified: "2026-09-01T10:00:00.000Z"))

        let linked = found.compactMap { item -> (EmbeddedFile, [String])? in
            if case let .embedded(file, folders) = item { return (file, folders) } else { return nil }
        }
        // The syllabus page is not a folder: its file sits in "Syllabus".
        XCTAssertEqual(linked.map { $0.1 }, [["Syllabus"], ["Labs"], ["Labs"]])
        XCTAssertEqual(linked.map { $0.0.id }, ["xid-61_1", "xid-81_1", "xid-82_1"])
        XCTAssertEqual(linked.map { $0.0.fileName }, ["Syllabus.pdf", "lab1.JPG", "Lab 1 sheet.pdf"])
        XCTAssertEqual(linked.first?.0.size, 1200)
        XCTAssertEqual(linked.first?.0.url.absoluteString, "https://bb.test/bbcswebdav/pid-6-dt-content-rid-61_1/xid-61_1?a=1&b=2")
    }

    func testALinkedFileIsCountedOnceWhenTheTextRepeatsIt() {
        let link = #"<a data-bbfile="{&quot;fileName&quot;:&quot;a.pdf&quot;,&quot;resourceUrl&quot;:&quot;https://bb.test/x/xid-5_1&quot;}">a</a>"#
        XCTAssertEqual(Blackboard.embeddedFiles(in: link + link + "<a data-bbfile=\"not json\">").count, 1)
    }

    private func file(_ key: String, _ name: String, version: String = "v1", folders: [String] = ["Term 1", "Operating Systems", "Slides"]) -> RemoteFile {
        RemoteFile(key: key, folders: folders, fileName: name, version: version, source: .link(URL(string: "https://bb.test/\(key)")!))
    }

    func testThePlanSortsFilesIntoNewChangedAndUnchanged() {
        let manifest = LibraryManifest(files: [
            "a": .init(path: "Term 1/Operating Systems/Slides/ch1.pdf", version: "v1", gone: false),
            "b": .init(path: "Term 1/Operating Systems/Old name/ch2.pdf", version: "v1", gone: false),
            "c": .init(path: "Term 1/Operating Systems/Slides/ch3.pdf", version: "v1", gone: false),
        ])
        let plan = LibrarySync.plan([
            file("a", "ch1.pdf"),
            file("b", "ch2.pdf", version: "v2"),
            file("d", "ch4.pdf"),
            file("d", "ch4.pdf"),
        ], against: manifest)

        XCTAssertEqual(plan.unchanged, 1)
        // A changed file keeps the place it was given, even though its folder was renamed on Blackboard.
        XCTAssertEqual(plan.updated.map(\.path), ["Term 1/Operating Systems/Old name/ch2.pdf"])
        XCTAssertEqual(plan.new.map(\.path), ["Term 1/Operating Systems/Slides/ch4.pdf"])
        XCTAssertEqual(plan.gone, ["c"])
    }

    func testTwoFilesWithOneNameGetNumbered() {
        let manifest = LibraryManifest(files: ["a": .init(path: "T/S/Slides/Lab.pdf", version: "v1", gone: true)])
        let plan = LibrarySync.plan([
            file("b", "lab.pdf", folders: ["T", "S", "Slides"]),
            file("c", "Lab.pdf", folders: ["T", "S", "Slides"]),
        ], against: manifest)
        // The gone file is still on the disk, so its name stays taken.
        XCTAssertEqual(plan.new.map(\.path), ["T/S/Slides/lab (2).pdf", "T/S/Slides/Lab (3).pdf"])
        XCTAssertEqual(plan.gone, [])
    }

    func testRecordingAndMarkingGoneUpdateTheManifest() {
        var manifest = LibraryManifest()
        let plan = LibrarySync.plan([file("a", "ch1.pdf")], against: manifest)
        LibrarySync.record(plan.new[0], in: &manifest)
        XCTAssertEqual(manifest.files["a"], .init(path: "Term 1/Operating Systems/Slides/ch1.pdf", version: "v1", gone: false))

        LibrarySync.markGone(["a"], in: &manifest)
        XCTAssertEqual(manifest.files["a"]?.gone, true)
        // Back on Blackboard: fetched again into the same place.
        XCTAssertEqual(LibrarySync.plan([file("a", "ch1.pdf")], against: manifest).updated.map(\.path), ["Term 1/Operating Systems/Slides/ch1.pdf"])
    }

    func testTheShelfPutsTheNewestTermFirstAndFilesInReadingOrder() {
        let manifest = LibraryManifest(files: [
            "1": .init(path: "الفصل الأول 1447-1448/Calculus/notes.pdf", version: "v", gone: false),
            "2": .init(path: "الفصل الأول 1448-1449/Circuits/Lectures/Chapter 10.pdf", version: "v", gone: false),
            "3": .init(path: "الفصل الأول 1448-1449/Circuits/Lectures/Chapter 2.pdf", version: "v", gone: true),
            "4": .init(path: "الفصل الأول 1448-1449/Circuits/Syllabus.pdf", version: "v", gone: false),
            "5": .init(path: "الفصل الأول 1448-1449/Circuits/Labs/Lab 1.pdf", version: "v", gone: false),
            "6": .init(path: "الفصل الثاني 1448-1449/Signals/a.pdf", version: "v", gone: false),
            "7": .init(path: "Other/Seminar/b.pdf", version: "v", gone: false),
        ])
        let shelf = Shelf(manifest)
        XCTAssertEqual(shelf.terms.map(\.name), ["الفصل الثاني 1448-1449", "الفصل الأول 1448-1449", "الفصل الأول 1447-1448", "Other"])
        let circuits = shelf.terms[1].subjects[0]
        XCTAssertEqual(circuits.files.map(\.name), ["Syllabus.pdf", "Lab 1.pdf", "Chapter 2.pdf", "Chapter 10.pdf"])
        XCTAssertEqual(circuits.files[1].folders, ["Labs"])
        XCTAssertEqual(circuits.files[2].gone, true)
    }

    func testOneNotificationSaysWhatArrivedAndWhere() {
        let term = "الفصل الأول 1448-1449"
        XCTAssertNil(SyncNews.message(new: [], updated: []))
        XCTAssertEqual(
            SyncNews.message(new: ["\(term)/Circuits/Lectures/Chapter 5.pdf"], updated: []),
            .init(title: "جديد في بلاك بورد", body: "Chapter 5 · Circuits")
        )
        XCTAssertEqual(SyncNews.message(new: [], updated: ["\(term)/Circuits/a.pdf", "\(term)/Signals/b.pdf"])?.title, "تحدّث في بلاك بورد")
        XCTAssertEqual(
            SyncNews.message(new: ["\(term)/A/1.pdf", "\(term)/B/2.pdf", "\(term)/B/3.pdf"], updated: ["\(term)/C/4.pdf", "\(term)/D/5.pdf"])?.body,
            "5 ملفات: 2 في B، 1 في A، 1 في C، وغيرها"
        )
        XCTAssertEqual(SyncNews.message(new: ["\(term)/A/1.pdf", "\(term)/A/2.pdf"], updated: [])?.body, "ملفين: 2 في A")
    }

    func testNamesAreSafeForTheDisk() {
        XCTAssertEqual(LibrarySync.component("Lab 1/2: AM?"), "Lab 1-2- AM-")
        XCTAssertEqual(LibrarySync.component("..hidden"), "hidden")
        XCTAssertEqual(LibrarySync.component(" \t "), "_")
        XCTAssertEqual(LibrarySync.component("الفصل الأول 1448/1449"), "الفصل الأول 1448-1449")
        XCTAssertEqual(file("x", "a.pdf", folders: ["T", "Sub/ject"]).path, "T/Sub-ject/a.pdf")
    }
}
