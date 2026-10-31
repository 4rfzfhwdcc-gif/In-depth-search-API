import SwiftUI

@MainActor
struct HistoryView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if store.conversations.isEmpty {
                    ContentUnavailableView("暂无历史对话", systemImage: "bubble.left.and.bubble.right", description: Text("开始聊天后，对话会自动保存在这里。"))
                }
                ForEach(store.conversations) { conversation in
                    Button {
                        selectedID = conversation.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.body)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Text(conversation.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedID == conversation.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.conversations[$0].id }
                    for id in ids { store.deleteConversation(id) }
                    if let selectedID, ids.contains(selectedID) {
                        self.selectedID = store.conversations.first?.id
                    }
                }
            }
            .navigationTitle("历史对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedID = store.createConversation()
                        dismiss()
                    } label: {
                        Label("新对话", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
