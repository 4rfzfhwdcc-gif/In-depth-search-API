import Foundation

enum DeepSeekModel: String, CaseIterable, Identifiable, Codable {
    case flash = "deepseek-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "DeepSeek V4 Flash"
        case .pro: return "DeepSeek V4 Pro"
        }
    }

    var shortName: String {
        switch self {
        case .flash: return "V4 Flash"
        case .pro: return "V4 Pro"
        }
    }

    var description: String {
        switch self {
        case .flash: return "日常聊天 · 更省费用"
        case .pro: return "复杂任务 · 能力更强"
        }
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable {
    var id: UUID = UUID()
    var role: ChatRole
    var content: String
    var reasoning: String = ""
    var createdAt: Date = Date()
}

struct ChatConversation: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "新对话"
    var messages: [ChatMessage] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
