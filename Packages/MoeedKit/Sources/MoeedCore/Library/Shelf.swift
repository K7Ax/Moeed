import Foundation

/// The library as the student sees it: terms, newest first; each term's subjects; each subject's
/// files under Blackboard's own folders. Read from the manifest, so it needs no network.
public struct Shelf: Hashable, Sendable {
    public struct File: Hashable, Sendable, Identifiable {
        /// Relative to the library folder.
        public var path: String
        public var name: String
        /// Blackboard's folders inside the subject; empty for a file at the subject's top.
        public var folders: [String]
        /// Removed from Blackboard; the copy on the device stays.
        public var gone: Bool

        public var id: String { path }
    }

    public struct Subject: Hashable, Sendable, Identifiable {
        public var name: String
        public var files: [File]
        public var id: String { name }
    }

    public struct Term: Hashable, Sendable, Identifiable {
        public var name: String
        public var subjects: [Subject]
        public var id: String { name }
    }

    public var terms: [Term]

    public init(terms: [Term]) {
        self.terms = terms
    }

    public init(_ manifest: LibraryManifest) {
        var tree: [String: [String: [File]]] = [:]
        for entry in manifest.files.values {
            let parts = entry.path.split(separator: "/").map(String.init)
            guard parts.count >= 3 else { continue }
            let file = File(path: entry.path, name: parts[parts.count - 1], folders: Array(parts[2..<(parts.count - 1)]), gone: entry.gone)
            tree[parts[0], default: [:]][parts[1], default: []].append(file)
        }
        terms = tree.map { term, subjects in
            Term(name: term, subjects: subjects.map { name, files in
                Subject(name: name, files: files.sorted(by: Self.reading))
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }.sorted(by: Self.newestFirst)
    }

    /// Files at the subject's top first, then folder by folder, each in the order a person numbers them.
    static func reading(_ a: File, _ b: File) -> Bool {
        if a.folders != b.folders {
            if a.folders.isEmpty || b.folders.isEmpty { return a.folders.isEmpty }
            return a.folders.joined(separator: "/").localizedStandardCompare(b.folders.joined(separator: "/")) == .orderedAscending
        }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    /// A term's name carries its years («الفصل الأول 1448/1449»): the later year comes first.
    /// Within a year, the name decides; a term with no year («Other») goes last.
    static func newestFirst(_ a: Term, _ b: Term) -> Bool {
        let (ya, yb) = (year(a.name), year(b.name))
        if ya != yb { return ya > yb }
        return a.name.localizedStandardCompare(b.name) == .orderedDescending
    }

    static func year(_ name: String) -> Int {
        var best = -1
        var digits = ""
        for character in name + " " {
            if let value = character.wholeNumberValue, character.isASCII {
                digits.append(String(value))
            } else {
                if digits.count == 4, let number = Int(digits) { best = max(best, number) }
                digits = ""
            }
        }
        return best
    }
}
