import Foundation

/// Parses DeepSeek Chat Completions SSE frames without assuming every data event
/// carries `choices[0].delta`. This type is independent of UIKit/SwiftUI so it
/// can be exercised with lightweight decoder tests.
struct DeepSeekStreamEvent {
    var content: [String] = []
    var reasoning: [String] = []
    var finished = false
    var done = false

    var hasText: Bool { !content.isEmpty || !reasoning.isEmpty }
}

enum DeepSeekStreamParsingError: LocalizedError {
    case malformedFrame
    case serverError(String)
    case missingCompletion

    var errorDescription: String? {
        switch self {
        case .malformedFrame:
            return "服务端返回了无法解析的聊天数据。"
        case .serverError(let message):
            return "DeepSeek 返回错误：\(message)"
        case .missingCompletion:
            return "接口没有返回可显示的回复内容。"
        }
    }
}

struct DeepSeekStreamParser {
    private var dataLines: [String] = []
    private(set) var sawDone = false
    private(set) var sawFinishReason = false

    /// Returns an event when a blank SSE delimiter is received.
    mutating func acceptLine(_ line: String) throws -> DeepSeekStreamEvent? {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try flush()
        }
        if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5))
            dataLines.append(value.hasPrefix(" ") ? String(value.dropFirst()) : value)
        }
        // SSE comments (: keep-alive), ids, event names and retry fields are
        // protocol metadata and do not contain Chat Completions tokens.
        return nil
    }

    /// Handles a final `data: [DONE]` without a trailing blank line.
    mutating func flush() throws -> DeepSeekStreamEvent? {
        guard !dataLines.isEmpty else { return nil }
        let payload = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        if payload.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
            sawDone = true
            return DeepSeekStreamEvent(done: true)
        }
        let event = try Self.decodeJSON(payload)
        if event.finished { sawFinishReason = true }
        return event
    }

    static func parseNonStreamingResponse(_ data: Data) throws -> DeepSeekStreamEvent {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let root = json as? [String: Any] else {
            throw DeepSeekStreamParsingError.malformedFrame
        }
        try throwIfServerError(root)
        guard let choices = root["choices"] as? [[String: Any]], !choices.isEmpty else {
            throw DeepSeekStreamParsingError.missingCompletion
        }
        var event = DeepSeekStreamEvent(finished: true)
        for choice in choices {
            guard let message = choice["message"] as? [String: Any] else { continue }
            let reasoning = text(from: message["reasoning_content"])
            if !reasoning.isEmpty { event.reasoning.append(reasoning) }
            let content = text(from: message["content"])
            if !content.isEmpty { event.content.append(content) }
        }
        guard event.hasText else { throw DeepSeekStreamParsingError.missingCompletion }
        return event
    }

    private static func decodeJSON(_ payload: String) throws -> DeepSeekStreamEvent {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw DeepSeekStreamParsingError.malformedFrame
        }
        try throwIfServerError(root)
        var event = DeepSeekStreamEvent()
        // Usage-only or service metadata events may not contain `choices`.
        guard let choices = root["choices"] as? [[String: Any]] else { return event }
        for choice in choices {
            if let finishReason = choice["finish_reason"] as? String, !finishReason.isEmpty {
                event.finished = true
            }
            guard let delta = (choice["delta"] ?? choice["message"]) as? [String: Any] else {
                continue
            }
            let reasoning = text(from: delta["reasoning_content"])
            if !reasoning.isEmpty { event.reasoning.append(reasoning) }
            let content = text(from: delta["content"])
            if !content.isEmpty { event.content.append(content) }
        }
        return event
    }

    private static func text(from value: Any?) -> String {
        if let string = value as? String { return string }
        // Some OpenAI-compatible gateways send typed text parts instead of a string.
        if let parts = value as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }

    private static func throwIfServerError(_ root: [String: Any]) throws {
        if let error = root["error"] as? [String: Any] {
            let description = (error["message"] as? String) ?? "未知 API 错误"
            throw DeepSeekStreamParsingError.serverError(description)
        }
        if let type = root["type"] as? String, type == "error" {
            throw DeepSeekStreamParsingError.serverError((root["message"] as? String) ?? "未知 API 错误")
        }
    }
}