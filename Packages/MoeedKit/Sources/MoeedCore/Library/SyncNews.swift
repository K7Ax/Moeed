import Foundation

/// What a sync brought, said in one notification: the file and its subject when there's one,
/// otherwise how many arrived and where, the busiest subject first.
public enum SyncNews {
    public struct Message: Equatable, Sendable {
        public var title: String
        public var body: String

        public init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }

    /// `new` and `updated` are library paths: term/subject/…/file.
    public static func message(new: [String], updated: [String]) -> Message? {
        let all = new + updated
        guard !all.isEmpty else { return nil }
        let title = new.isEmpty ? "تحدّث في بلاك بورد" : "جديد في بلاك بورد"
        if all.count == 1 {
            return Message(title: title, body: "\(stem(all[0])) · \(subject(all[0]))")
        }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for path in all {
            let name = subject(path)
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        let ranked = order.enumerated().sorted { a, b in
            let (ca, cb) = (counts[a.element] ?? 0, counts[b.element] ?? 0)
            return ca != cb ? ca > cb : a.offset < b.offset
        }.map(\.element)
        var parts = ranked.prefix(3).map { "\((counts[$0] ?? 0).figures) في \($0)" }
        if ranked.count > 3 { parts.append("وغيرها") }
        return Message(title: title, body: "\(files(all.count)): " + parts.joined(separator: "، "))
    }

    /// «ملفين»، «3 ملفات»، «11 ملف».
    static func files(_ count: Int) -> String {
        switch count {
        case 2: "ملفين"
        case 3...10: "\(count.figures) ملفات"
        default: "\(count.figures) ملف"
        }
    }

    static func subject(_ path: String) -> String {
        let parts = path.split(separator: "/")
        return parts.count > 1 ? String(parts[1]) : ""
    }

    static func stem(_ path: String) -> String {
        let name = String(path.split(separator: "/").last ?? "")
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
    }
}
