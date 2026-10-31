import Foundation

enum DeepSeekModel: String, CaseIterable, Identifiable, Codable {
    case flash = "deepseek-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "DeepSeek V4.1 Flash"
        case .pro: return "DeepSeek V4.0 Pro"
        }
    }

    var shortName: String {
        switch self {
        case .flash: return "V4.1 Flash"
        case .pro: return "V4.0 Pro"
        }
    }

    var description: String {
        switch self {
        case .flash: return "默认模型 · 原生图片理解 · 日常与复杂任务"
        case .pro: return "保留 Pro API 选项 · 服务端实际路由以 DeepSeek 公告为准"
        }
    }
}

enum DeepSeekReasoningEffort: String, CaseIterable, Identifiable, Codable {
    case instant
    case balanced
    case max

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instant: return "即时"
        case .balanced: return "均衡"
        case .max: return "Max"
        }
    }

    /// DeepSeek Chat Completions supports low / high / max.
    var apiValue: String {
        switch self {
        case .instant: return "low"
        case .balanced: return "high"
        case .max: return "max"
        }
    }

    var mappingDescription: String {
        switch self {
        case .instant: return "API low：优先响应速度，使用较低推理强度。"
        case .balanced: return "API high：兼顾响应速度与推理深度，推荐日常使用。"
        case .max: return "API max：使用最高推理强度，适合复杂问题。"
        }
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatImageAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var mimeType: String = "image/jpeg"
    var data: Data

    init(id: UUID = UUID(), mimeType: String = "image/jpeg", data: Data) {
        self.id = id
        self.mimeType = mimeType
        self.data = data
    }
}

struct ChatMessage: Identifiable, Codable {
    var id: UUID = UUID()
    var role: ChatRole
    var content: String
    var reasoning: String = ""
    var attachments: [ChatImageAttachment] = []
    var createdAt: Date = Date()

    private enum CodingKeys: String, CodingKey {
        case id, role, content, reasoning, attachments, createdAt
    }

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        reasoning: String = "",
        attachments: [ChatImageAttachment] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.attachments = attachments
        self.createdAt = createdAt
    }

    // Backward-compatible decoding for V1.0 chat histories that have no attachments field.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try container.decode(ChatRole.self, forKey: .role)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning) ?? ""
        attachments = try container.decodeIfPresent([ChatImageAttachment].self, forKey: .attachments) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct ChatConversation: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "新对话"
    var messages: [ChatMessage] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
