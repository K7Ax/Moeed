import Foundation
import MoeedCore

public enum TutorError: Error, CustomStringConvertible {
    case http(Int, String)
    case api(String)

    public var description: String {
        switch self {
        case let .http(status, body): "the model service answered \(status): \(body.prefix(300))"
        case let .api(message): "the model stopped: \(message)"
        }
    }
}

/// A vision model that reads the marked-up slide and writes the TDP-L script, streamed as it's written.
public protocol TutorModel: Sendable {
    /// Shown in logs, e.g. "gemini/gemini-flash-latest".
    var name: String { get }
    func stream(system: String, image png: Data, text: String) -> AsyncThrowingStream<String, Error>
}

/// Claude, through the Messages API, streaming its answer as it's written.
/// The key is the student's own (kept in the Keychain by the app, or an environment variable for the CLI).
public struct ClaudeTutor: TutorModel {
    public static let defaultModel = "claude-sonnet-5-5"

    public var apiKey: String
    public var model: String
    public var maxTokens: Int

    public init(apiKey: String, model: String = ClaudeTutor.defaultModel, maxTokens: Int = 3000) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
    }

    public var name: String { "anthropic/\(model)" }

    /// The reply's text, piece by piece.
    public func stream(system: String, image png: Data, text: String) -> AsyncThrowingStream<String, Error> {
        let request = makeRequest(system: system, image: png, text: text)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw TutorError.http(status, body)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:"),
                              let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        switch event["type"] as? String {
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any], let piece = delta["text"] as? String {
                                continuation.yield(piece)
                            }
                        case "error":
                            let message = (event["error"] as? [String: Any])?["message"] as? String
                            throw TutorError.api(message ?? "unknown error")
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeRequest(system: String, image png: Data, text: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            // The instructions are the same for every slide, so they're cached between calls.
            "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": png.base64EncodedString()]],
                    ["type": "text", "text": text],
                ],
            ]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}

/// A lesson as it's being written: recompiled after every finished line,
/// so the first steps can play while the model is still writing the rest.
public struct LessonDraft: Sendable {
    public var script: String
    public var lesson: SlidePage
    public var report: TDPReport
    public var isFinished: Bool
}

public enum Explainer {
    /// Asks the tutor to explain one grounded slide and streams the lesson as it grows.
    public static func explain(
        _ slide: GroundedSlide,
        deckTitle: String,
        deckPageCount: Int,
        with tutor: any TutorModel
    ) -> AsyncThrowingStream<LessonDraft, Error> {
        let png = SetOfMarks.draw(slide)?.pngData() ?? slide.image.pngData() ?? Data()
        let request = TutorPrompt.request(map: slide.map, page: slide.page, deckTitle: deckTitle, deckPageCount: deckPageCount)
        let map = slide.map
        let page = slide.page

        func draft(_ script: String, finished: Bool) -> LessonDraft {
            let compiled = LessonCompiler.compile(source: script, map: map, page: page, deckTitle: deckTitle, deckPageCount: deckPageCount)
            return LessonDraft(script: script, lesson: compiled.page, report: compiled.report, isFinished: finished)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var script = ""
                    var lines = 0
                    for try await piece in tutor.stream(system: TutorPrompt.system, image: png, text: request) {
                        script += piece
                        guard let end = script.lastIndex(of: "\n") else { continue }
                        let finished = script[..<end]
                        let count = finished.filter { $0 == "\n" }.count + 1
                        if count > lines {
                            lines = count
                            continuation.yield(draft(String(finished), finished: false))
                        }
                    }
                    continuation.yield(draft(script, finished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
