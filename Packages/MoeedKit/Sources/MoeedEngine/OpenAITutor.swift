import Foundation

/// Any service that speaks the OpenAI chat-completions format. Gemini Flash has a free tier that is enough
/// for testing; Groq, OpenRouter and local servers work the same way.
public struct OpenAITutor: TutorModel {
    public var provider: String
    public var endpoint: URL
    public var apiKey: String
    public var model: String
    public var maxTokens: Int

    public init(provider: String, endpoint: URL, apiKey: String, model: String, maxTokens: Int = 3000) {
        self.provider = provider
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
    }

    /// Gemini through its OpenAI-compatible endpoint; a free key comes from Google AI Studio.
    public static func gemini(key: String, model: String = "gemini-flash-latest") -> OpenAITutor {
        OpenAITutor(
            provider: "gemini",
            endpoint: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!,
            apiKey: key, model: model
        )
    }

    public var name: String { "\(provider)/\(model)" }

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
                    // Kept so an empty answer can say what the service actually sent.
                    var raw = ""
                    var pieces = 0
                    for try await line in bytes.lines {
                        if raw.count < 1500 { raw += line + "\n" }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        if let error = event["error"] as? [String: Any] {
                            throw TutorError.api(error["message"] as? String ?? "unknown error")
                        }
                        let choices = event["choices"] as? [[String: Any]] ?? []
                        if let delta = choices.first?["delta"] as? [String: Any], let piece = delta["content"] as? String {
                            pieces += 1
                            continuation.yield(piece)
                        }
                    }
                    if pieces == 0 { throw TutorError.api("no text in the reply: \(raw.prefix(1500))") }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeRequest(system: String, image png: Data, text: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64," + png.base64EncodedString(), "detail": "high"]],
                        ["type": "text", "text": text],
                    ],
                ],
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}
