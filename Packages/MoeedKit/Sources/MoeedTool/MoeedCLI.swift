import Foundation
import MoeedCore
import MoeedEngine

/// The engine from the command line, for trying it on a lecture without the app.
///
///     moeed ground  <file.pdf> <page> <out-dir>              regions, slide image, Set-of-Marks image, prompt
///     moeed compile <file.pdf> <page> <script.tdp> <out-dir>  check a hand-written or pasted script
///     moeed explain <file.pdf> <page> <out-dir>               ask a model to explain the slide
///
/// `explain` picks the model from MOEED_PROVIDER (claude | gemini), or else from whichever key is set:
/// ANTHROPIC_API_KEY or GEMINI_API_KEY (a free one comes from Google AI Studio). MOEED_MODEL overrides the provider's default model.
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
        let tutor = try tutorFromEnvironment()
        let (slide, dir, name) = try load(pdf, page, out)
        print("asking \(tutor.name)")
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

    static func tutorFromEnvironment() throws -> any TutorModel {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key].flatMap { $0.isEmpty ? nil : $0 } }
        let model = value("MOEED_MODEL")
        let provider = value("MOEED_PROVIDER")
            ?? (value("ANTHROPIC_API_KEY") != nil ? "claude" : "gemini")
        switch provider {
        case "claude":
            guard let key = value("ANTHROPIC_API_KEY") else { throw TutorError.api("set ANTHROPIC_API_KEY") }
            return ClaudeTutor(apiKey: key, model: model ?? ClaudeTutor.defaultModel)
        case "gemini":
            guard let key = value("GEMINI_API_KEY") else { throw TutorError.api("set GEMINI_API_KEY (free from Google AI Studio) or ANTHROPIC_API_KEY") }
            return model.map { OpenAITutor.gemini(key: key, model: $0) } ?? OpenAITutor.gemini(key: key)
        default:
            throw TutorError.api("unknown MOEED_PROVIDER \(provider): use claude or gemini")
        }
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
