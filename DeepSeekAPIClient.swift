import Foundation

struct APIMessage: Encodable {
    let role: String
    let content: String
}

enum ChatStreamDelta {
    case content(String)
    case reasoning(String)
}

enum ChatAPIError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case invalidStream

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case .http(let status, let message):
            switch status {
            case 401: return "API Key 无效或已失效，请在设置中检查。\n\(message)"
            case 402: return "API 账户余额不足，请检查 DeepSeek 开放平台。\n\(message)"
            case 429: return "请求过于频繁，请稍后重试。\n\(message)"
            default: return "API 请求失败（HTTP \(status)）。\n\(message)"
            }
        case .invalidStream:
            return "服务器返回的流式数据不符合预期。"
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let thinking: ThinkingOption

    struct ThinkingOption: Encodable {
        let type: String
    }
}

private struct StreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta

        struct Delta: Decodable {
            let content: String?
            let reasoning_content: String?
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: Detail

    struct Detail: Decodable {
        let message: String
    }
}

enum DeepSeekAPIClient {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    static func stream(
        messages: [APIMessage],
        model: DeepSeekModel,
        thinkingEnabled: Bool,
        apiKey: String
    ) -> AsyncThrowingStream<ChatStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(
                        ChatCompletionRequest(
                            model: model.rawValue,
                            messages: messages,
                            stream: true,
                            thinking: .init(type: thinkingEnabled ? "enabled" : "disabled")
                        )
                    )

                    let configuration = URLSessionConfiguration.default
                    configuration.timeoutIntervalForResource = 600
                    let session = URLSession(configuration: configuration)
                    defer { session.invalidateAndCancel() }

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ChatAPIError.invalidResponse
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var data = Data()
                        for try await byte in bytes {
                            try Task.checkCancellation()
                            if data.count >= 16_384 { break }
                            data.append(byte)
                        }
                        let serverError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
                        throw ChatAPIError.http(httpResponse.statusCode, serverError?.error.message ?? "")
                    }

                    var dataLines: [String] = []
                    var receivedDone = false
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let event = dataLines.joined(separator: "\n")
                                dataLines.removeAll(keepingCapacity: true)
                                if event == "[DONE]" {
                                    receivedDone = true
                                    break
                                }
                                try handleEvent(event, continuation: continuation)
                            }
                            continue
                        }
                        if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        }
                    }
                    if !receivedDone && !dataLines.isEmpty {
                        let event = dataLines.joined(separator: "\n")
                        if event == "[DONE]" {
                            receivedDone = true
                        } else {
                            try handleEvent(event, continuation: continuation)
                        }
                    }
                    try Task.checkCancellation()
                    guard receivedDone else { throw ChatAPIError.invalidStream }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private static func handleEvent(
        _ text: String,
        continuation: AsyncThrowingStream<ChatStreamDelta, Error>.Continuation
    ) throws {
        guard let data = text.data(using: .utf8) else { return }
        if let serverError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
            throw ChatAPIError.http(200, serverError.error.message)
        }
        guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else {
            throw ChatAPIError.invalidStream
        }
        for choice in chunk.choices {
            if let reasoning = choice.delta.reasoning_content, !reasoning.isEmpty {
                continuation.yield(.reasoning(reasoning))
            }
            if let content = choice.delta.content, !content.isEmpty {
                continuation.yield(.content(content))
            }
        }
    }
}
