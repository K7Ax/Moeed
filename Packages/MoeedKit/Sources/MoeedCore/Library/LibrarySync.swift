import Foundation

/// A file on Blackboard and where it belongs in the library: term / subject / Blackboard's folders / file.
public struct RemoteFile: Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case attachment(course: String, content: String, attachment: String)
        case link(URL)
    }

    /// Stable across syncs: the attachment's id, or the linked file's id in the content collection.
    public var key: String
    public var folders: [String]
    public var fileName: String
    /// Changes when the file may have been replaced on Blackboard.
    public var version: String
    public var source: Source

    public init(key: String, folders: [String], fileName: String, version: String, source: Source) {
        self.key = key
        self.folders = folders
        self.fileName = fileName
        self.version = version
        self.source = source
    }

    /// Where it would go if nothing else were there, relative to the library folder.
    public var path: String {
        (folders + [fileName]).map(LibrarySync.component).joined(separator: "/")
    }
}

/// What the library already holds, kept as JSON next to the files.
public struct LibraryManifest: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        /// Relative to the library folder. Kept once given, so a file doesn't move when Blackboard renames its folder.
        public var path: String
        public var version: String
        /// Removed from Blackboard. The local copy stays: a student's lecture is never deleted for them.
        public var gone: Bool
    }

    public var files: [String: Entry]
    public var lastSync: Date?

    public init(files: [String: Entry] = [:], lastSync: Date? = nil) {
        self.files = files
        self.lastSync = lastSync
    }
}

public struct SyncPlan: Sendable {
    public struct Item: Hashable, Sendable {
        public var file: RemoteFile
        public var path: String
    }

    public var new: [Item] = []
    public var updated: [Item] = []
    public var unchanged = 0
    /// Keys of files that are no longer on Blackboard.
    public var gone: [String] = []
}

public enum LibrarySync {
    /// Compares what Blackboard has now with what the library holds.
    public static func plan(_ remote: [RemoteFile], against manifest: LibraryManifest) -> SyncPlan {
        var plan = SyncPlan()
        var seen: Set<String> = []
        // Paths are compared without case: the iPad's disk may not tell "Lab.pdf" from "lab.pdf".
        var taken = Set(manifest.files.values.map { $0.path.lowercased() })
        for file in remote where seen.insert(file.key).inserted {
            if let entry = manifest.files[file.key] {
                if entry.version == file.version && !entry.gone {
                    plan.unchanged += 1
                } else {
                    plan.updated.append(.init(file: file, path: entry.path))
                }
            } else {
                let path = free(file.path, taken: taken)
                taken.insert(path.lowercased())
                plan.new.append(.init(file: file, path: path))
            }
        }
        plan.gone = manifest.files.filter { !$0.value.gone && !seen.contains($0.key) }.map(\.key).sorted()
        return plan
    }

    /// After a file is saved at its path.
    public static func record(_ item: SyncPlan.Item, in manifest: inout LibraryManifest) {
        manifest.files[item.file.key] = .init(path: item.path, version: item.file.version, gone: false)
    }

    public static func markGone(_ keys: [String], in manifest: inout LibraryManifest) {
        for key in keys { manifest.files[key]?.gone = true }
    }

    /// `name.pdf`, then `name (2).pdf`, `name (3).pdf`…
    static func free(_ path: String, taken: Set<String>) -> String {
        guard taken.contains(path.lowercased()) else { return path }
        let ext = (path as NSString).pathExtension
        let stem = ext.isEmpty ? path : String(path.dropLast(ext.count + 1))
        var number = 2
        while true {
            let candidate = stem + " (\(number))" + (ext.isEmpty ? "" : "." + ext)
            if !taken.contains(candidate.lowercased()) { return candidate }
            number += 1
        }
    }

    /// A name that is safe as one folder or file name.
    public static func component(_ name: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        // Whitespace first, so a stray tab becomes a space rather than a dash.
        let scalars = Blackboard.tidy(name).unicodeScalars.map { unsafe.contains($0) ? "-" : Character($0) }
        var clean = String(scalars)
        while clean.hasPrefix(".") { clean.removeFirst() }
        if clean.count > 120 { clean = String(clean.prefix(120)) }
        return clean.isEmpty ? "_" : clean
    }
}
