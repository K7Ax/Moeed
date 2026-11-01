import Foundation

/// The parts of Blackboard Learn's public REST API (v1) the library sync reads.
/// The app calls it with the student's own signed-in session and only ever reads.
public enum Blackboard {
    public struct Page<Item: Decodable>: Decodable {
        public var results: [Item]
        public var paging: Paging?

        public struct Paging: Decodable {
            public var nextPage: String?
        }
    }

    public struct Availability: Decodable, Sendable {
        public var available: String?
    }

    public struct Membership: Decodable, Sendable {
        public var courseId: String
        public var availability: Availability?
        public var course: Course?
    }

    public struct Course: Decodable, Sendable {
        public var id: String
        public var courseId: String?
        public var name: String?
        public var termId: String?
        public var availability: Availability?
    }

    public struct Term: Decodable, Sendable {
        public var id: String
        public var name: String?
    }

    /// The signed-in student; reading it is how the app knows the session works.
    public struct User: Decodable, Sendable {
        public var id: String
        public var userName: String?
        public var name: Name?

        public struct Name: Decodable, Sendable {
            public var given: String?
            public var family: String?
        }
    }

    public struct Content: Decodable, Sendable {
        public var id: String
        public var parentId: String?
        public var title: String?
        public var modified: String?
        public var body: String?
        public var contentHandler: Handler?
        public var availability: Availability?
    }

    public struct Handler: Decodable, Sendable {
        public var id: String
        public var isBbPage: Bool?
        public var instructions: String?
    }

    public struct Attachment: Decodable, Sendable {
        public var id: String
        public var fileName: String?
    }
}

/// One subject in one term. The university opens a course per section and a merged one on top;
/// they all land in the same folder.
public struct Subject: Hashable, Sendable {
    public var termId: String?
    public var name: String
    /// Internal course ids (`_571270_1`), the merged course first.
    public var courseIds: [String]
}

/// A file linked inside a page's or an assignment's text. Ultra keeps lab sheets and syllabi there.
public struct EmbeddedFile: Hashable, Sendable {
    /// The file's id in the content collection (`xid-…`); it stays the same when the text around it is edited.
    public var id: String
    public var fileName: String
    public var size: Int?
    public var url: URL
}

/// A file found while walking a course, with Blackboard's folders above it.
public enum FoundFile: Hashable, Sendable {
    /// A file item; its attachments are listed by a separate request.
    case attachments(content: String, folders: [String], modified: String?)
    case embedded(EmbeddedFile, folders: [String])
}

extension Blackboard {
    /// The subjects the student can open now. A disabled enrolment or a closed course is skipped,
    /// so last term's folders are left as they were.
    public static func subjects(_ memberships: [Membership]) -> [Subject] {
        var order: [String] = []
        var found: [String: (subject: Subject, merged: Set<String>)] = [:]
        for membership in memberships {
            guard membership.availability?.available == "Yes", let course = membership.course,
                  course.availability?.available != "No" else { continue }
            let name = tidy(course.name ?? course.courseId ?? course.id)
            let key = (course.termId ?? "") + "\u{1F}" + name
            if found[key] == nil {
                order.append(key)
                found[key] = (Subject(termId: course.termId, name: name, courseIds: []), [])
            }
            found[key]?.subject.courseIds.append(course.id)
            if course.courseId?.hasPrefix("Merged_") == true { found[key]?.merged.insert(course.id) }
        }
        return order.compactMap { key in
            guard let entry = found[key] else { return nil }
            var subject = entry.subject
            let merged = entry.merged
            subject.courseIds = subject.courseIds.filter(merged.contains) + subject.courseIds.filter { !merged.contains($0) }
            return subject
        }
    }

    /// Every file in a course, from its contents as `contents?recursive=true` lists them.
    public static func files(in contents: [Content]) -> [FoundFile] {
        let byId = Dictionary(contents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func folders(above item: Content) -> [String] {
            var path: [String] = []
            var seen: Set<String> = []
            var parent = item.parentId
            while let id = parent, let folder = byId[id], seen.insert(id).inserted {
                // An Ultra document is stored as a folder holding its body; to the student it isn't a folder.
                if folder.contentHandler?.id == "resource/x-bb-folder", folder.contentHandler?.isBbPage != true {
                    path.insert(tidy(folder.title ?? ""), at: 0)
                }
                parent = folder.parentId
            }
            return path
        }

        var found: [FoundFile] = []
        for item in contents where item.availability?.available != "No" {
            let path = folders(above: item)
            if item.contentHandler?.id == "resource/x-bb-file" {
                found.append(.attachments(content: item.id, folders: path, modified: item.modified))
            }
            for text in [item.body, item.contentHandler?.instructions].compactMap({ $0 }) {
                found += embeddedFiles(in: text).map { .embedded($0, folders: path) }
            }
        }
        return found
    }

    /// Files linked in Ultra's rich text: `<a data-bbtype="attachment" data-bbfile="{…json…}">`.
    public static func embeddedFiles(in html: String) -> [EmbeddedFile] {
        var files: [EmbeddedFile] = []
        var rest = html[...]
        while let start = rest.range(of: "data-bbfile=\"") {
            let value = rest[start.upperBound...]
            guard let end = value.firstIndex(of: "\"") else { break }
            let json = unescape(String(value[..<end]))
            rest = value[value.index(after: end)...]
            guard let info = try? JSONDecoder().decode(LinkedFile.self, from: Data(json.utf8)),
                  let link = info.resourceUrl, let url = URL(string: link) else { continue }
            let id = xid(in: link) ?? link
            guard !files.contains(where: { $0.id == id }) else { continue }
            files.append(EmbeddedFile(id: id, fileName: info.name, size: info.fileSize, url: url))
        }
        return files
    }

    private struct LinkedFile: Decodable {
        var fileName: String?
        var displayName: String?
        var fileSize: Int?
        var resourceUrl: String?

        /// The name the student sees, unless it lost its extension.
        var name: String {
            let display = tidy(displayName ?? "")
            if !(display as NSString).pathExtension.isEmpty { return display }
            let stored = tidy(fileName ?? "")
            return stored.isEmpty ? (display.isEmpty ? "file" : display) : stored
        }
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    static func xid(in link: String) -> String? {
        link.range(of: #"xid-[0-9_]+"#, options: .regularExpression).map { String(link[$0]) }
    }

    /// Names come with stray tabs and double spaces.
    public static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
