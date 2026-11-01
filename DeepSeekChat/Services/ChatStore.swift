import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [ChatConversation] = []

    private let storageURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        storageURL = base.appendingPathComponent("conversations.json")

        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            conversations = saved.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func conversation(_ id: UUID?) -> ChatConversation? {
        guard let id else { return nil }
        return conversations.first { $0.id == id }
    }

    @discardableResult
    func createConversation() -> UUID {
        let conversation = ChatConversation()
        conversations.insert(conversation, at: 0)
        scheduleSave()
        return conversation.id
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        scheduleSave()
    }

    @discardableResult
    func addMessage(
        _ role: ChatRole,
        content: String,
        attachments: [ChatImageAttachment] = [],
        to conversationID: UUID
    ) -> UUID? {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return nil }
        let message = ChatMessage(role: role, content: content, attachments: attachments)
        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()
        if role == .user && conversations[index].title == "新对话" {
            let firstLine = content.components(separatedBy: .newlines).first ?? content
            conversations[index].title = firstLine.isEmpty && !attachments.isEmpty
                ? "图片对话"
                : String(firstLine.prefix(26))
        }
        sortConversations()
        scheduleSave()
        return message.id
    }

    func appendDelta(_ text: String, reasoning: Bool, conversationID: UUID, messageID: UUID) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        if reasoning {
            conversations[c].messages[m].reasoning += text
        } else {
            conversations[c].messages[m].content += text
        }
        conversations[c].updatedAt = Date()
        scheduleSave()
    }

    /// Retracts a user message and the assistant response immediately following it.
    /// Messages are stored in alternating user/assistant order, so the next user
    /// message is the boundary of the pair.
    @discardableResult
    func retractUserMessage(_ id: UUID, from conversationID: UUID) -> Bool {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == id }),
              conversations[conversationIndex].messages[messageIndex].role == .user else {
            return false
        }

        let messages = conversations[conversationIndex].messages
        var endIndex = messageIndex + 1
        while endIndex < messages.count && messages[endIndex].role != .user {
            endIndex += 1
        }
        conversations[conversationIndex].messages.removeSubrange(messageIndex..<endIndex)

        if conversations[conversationIndex].messages.isEmpty {
            conversations[conversationIndex].title = "新对话"
        } else if let firstUser = conversations[conversationIndex].messages.first(where: { $0.role == .user }) {
            let firstLine = firstUser.content.components(separatedBy: .newlines).first ?? firstUser.content
            conversations[conversationIndex].title = firstLine.isEmpty && !firstUser.attachments.isEmpty
                ? "图片对话"
                : String(firstLine.prefix(26))
        }
        conversations[conversationIndex].updatedAt = Date()
        sortConversations()
        scheduleSave()
        return true
    }

    func removeMessage(_ id: UUID, from conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.removeAll { $0.id == id }
        scheduleSave()
    }

    func flush() {
        saveTask?.cancel()
        saveImmediately()
    }

    private func sortConversations() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.saveImmediately()
        }
    }

    private func saveImmediately() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        do {
            try data.write(to: storageURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: storageURL.path
            )
        } catch {
            // Local-only app: persistence failures do not interrupt the chat UI.
            // We deliberately avoid logging conversation contents.
        }
    }
}
