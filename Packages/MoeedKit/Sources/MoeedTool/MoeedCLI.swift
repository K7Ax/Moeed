import Foundation
import MoeedCore
import MoeedEngine

/// The engine from the command line, for trying it on a lecture without the app.
///
///     moeed ground  <file.pdf> <page> <out-dir>              regions, slide image, Set-of-Marks image, prompt
///     moeed compile <file.pdf> <page> <script.tdp> <out-dir>  check a hand-written or pasted script
///     moeed explain <file.pdf> <page> <out-dir>               ask Claude (needs ANTHROPIC_API_KEY)
@main
struct MoeedCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            switch args.first {
            case "ground" where args.count == 4:
                try ground(pdf: args[1], page: args[2], out: args[3])
            case "compile" where args.count == 5:
                try compile(pdf: args[1], page: args[2], script: args[3], out: args[4])
            case "explain" where args.count == 4:
                try await explain(pdf: args[1], page: args[2], out: args[3])
            default:
                print("usage: moeed ground|explain <file.pdf> <page> <out-dir>\n       moeed compile <file.pdf> <page> <script.tdp> <out-dir>")
                exit(2)
            }
        } catch {
            FileHandle.standardError.write(Data("moeed: \(error)\n".utf8))
            exit(1)
        }
    }

    static func load(_ pdf: String, _ page: String, _ out: String) throws -> (GroundedSlide, URL, String) {
        guard let number = Int(page) else { throw EngineError.noPage(0) }
        let url = URL(fileURLWithPath: pdf)
        let slide = try PDFGrounder.ground(url, page: number)
        let dir = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (slide, dir, "p\(number)")
    }

    static func ground(pdf: String, page: String, out: String) throws {
        let (slide, dir, name) = try load(pdf, page, out)
        try slide.image.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
        try SetOfMarks.draw(slide)?.pngData()?.write(to: dir.appendingPathComponent("\(name)-som.png"))
        try Data(slide.map.listing.utf8).write(to: dir.appendingPathComponent("\(name)-regions.txt"))
        let prompt = TutorPrompt.system + "\n\n---\n\n" + TutorPrompt.request(map: slide.map, page: slide.page, deckTitle: deckTitle(pdf), deckPageCount: 0)
        try Data(prompt.utf8).write(to: dir.appendingPathComponent("\(name)-prompt.txt"))
        print("\(slide.map.regions.count) regions on page \(slide.page) (\(Int(slide.map.width)) × \(Int(slide.map.height))):")
        print(slide.map.listing)
    }

    static func compile(pdf: String, page: String, script: String, out: String) throws {
        let (slide, dir, name) = try load(pdf, page, out)
        let source = try String(contentsOfFile: script, encoding: .utf8)
        let compiled = LessonCompiler.compile(source: source, map: slide.map, page: slide.page, deckTitle: deckTitle(pdf), deckPageCount: 0)
        try write(compiled.page, to: dir.appendingPathComponent("\(name)-lesson.json"))
        printReport(compiled.report, steps: compiled.page.steps.count)
    }

    static func explain(pdf: String, page: String, out: String) async throws {
        guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
            throw TutorError.api("set ANTHROPIC_API_KEY first")
        }
        let (slide, dir, name) = try load(pdf, page, out)
        let model = ProcessInfo.processInfo.environment["MOEED_MODEL"] ?? ClaudeTutor.defaultModel
        let tutor = ClaudeTutor(apiKey: key, model: model)
        let started = Date()
        var printed = 0
        var last: LessonDraft?
        for try await draft in Explainer.explain(slide, deckTitle: deckTitle(pdf), deckPageCount: 0, with: tutor) {
            // Echo each line as it lands, with the time since the request went out.
            let lines = draft.script.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines.dropFirst(printed) where !line.isEmpty {
                print(String(format: "%5.1fs  ", Date().timeIntervalSince(started)) + line)
            }
            printed = lines.count
            last = draft
        }
        guard let last else { return }
        try Data(last.script.utf8).write(to: dir.appendingPathComponent("\(name).tdp"))
        try write(last.lesson, to: dir.appendingPathComponent("\(name)-lesson.json"))
        printReport(last.report, steps: last.lesson.steps.count)
    }

    static func deckTitle(_ pdf: String) -> String {
        URL(fileURLWithPath: pdf).deletingPathExtension().lastPathComponent
    }

    static func write(_ lesson: SlidePage, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(lesson).write(to: url)
    }

    static func printReport(_ report: TDPReport, steps: Int) {
        print("\n\(steps) steps · \(report.errors.count) errors · \(report.warnings.count) warnings · \(report.repairs.count) repairs")
        for e in report.errors { print("  error   \(e)") }
        for w in report.warnings { print("  warning \(w)") }
        for r in report.repairs { print("  repair  \(r)") }
    }
}
