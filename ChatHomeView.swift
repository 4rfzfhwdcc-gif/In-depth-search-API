import SwiftUI

@MainActor
struct ChatHomeView: View {
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedID: UUID?
    @State private var draft = ""
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var isStreaming = false
    @State private var requestTask: Task<Void, Never>?
    @State private var activeRequestID: UUID?
    @State private var activeAnswerID: UUID?
    @State private var activeConversationID: UUID?
    @State private var errorText: String?

    private var current: ChatConversation? { store.conversation(selectedID) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let current, !current.messages.isEmpty {
                    conversationScroll(current)
                } else {
                    welcomeView
                }
                Divider()
                composer
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("DeepSeek Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("历史对话")
                }
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("选择模型", selection: $settings.selectedModel) {
                            ForEach(DeepSeekModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        Toggle("深度思考", isOn: $settings.thinkingEnabled)
                    } label: {
                        HStack(spacing: 5) {
                            Text(settings.selectedModel.shortName)
                                .font(.subheadline.weight(.semibold))
                            if settings.thinkingEnabled {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: newConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建对话")
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(selectedID: $selectedID)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("请求失败", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("确定", role: .cancel) { errorText = nil }
                Button("检查设置") { errorText = nil; showSettings = true }
            } message: {
                Text(errorText ?? "")
            }
            .onAppear {
                if selectedID == nil { selectedID = store.conversations.first?.id }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { store.flush() }
            }
        }
    }

    private func conversationScroll(_ conversation: ChatConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(conversation.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: conversation.messages.last?.id) { _ in
                scrollToBottom(proxy, conversation)
            }
            .onChange(of: conversation.messages.last?.content.count) { _ in
                scrollToBottom(proxy, conversation)
            }
            .onChange(of: conversation.messages.last?.reasoning.count) { _ in
                scrollToBottom(proxy, conversation)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, _ conversation: ChatConversation) {
        guard let id = conversation.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.indigo, .indigo.opacity(0.25))
                .padding(20)
                .background(.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
            Text("今天想聊些什么？")
                .font(.title2.bold())
            Text("DeepSeek \(settings.selectedModel.shortName) 已就绪\n输入问题，开始你的新对话")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("向 DeepSeek 发送消息…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                .disabled(isStreaming)
                .accessibilityLabel("输入消息")
            Button {
                if isStreaming { stop() } else { send() }
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 43, height: 43)
                    .background(isStreaming ? Color.red : Color.indigo, in: Circle())
            }
            .disabled(!isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((!isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.4 : 1)
            .accessibilityLabel(isStreaming ? "停止生成" : "发送消息")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.bar)
    }

    private func newConversation() {
        stop()
        selectedID = store.createConversation()
        draft = ""
    }

    private func stop() {
        requestTask?.cancel()
        requestTask = nil
        if let conversationID = activeConversationID,
           let answerID = activeAnswerID,
           let answer = store.conversation(conversationID)?.messages.first(where: { $0.id == answerID }),
           answer.content.isEmpty && answer.reasoning.isEmpty {
            store.removeMessage(answerID, from: conversationID)
        }
        activeRequestID = nil
        activeAnswerID = nil
        activeConversationID = nil
        isStreaming = false
        store.flush()
    }

    private func send() {
        guard !isStreaming else { return }
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard let apiKey = KeychainService.readAPIKey(), !apiKey.isEmpty else {
            showSettings = true
            return
        }
        let conversationID = selectedID ?? store.createConversation()
        selectedID = conversationID
        guard store.addMessage(.user, content: prompt, to: conversationID) != nil else { return }
        draft = ""

        let outbound = (store.conversation(conversationID)?.messages ?? [])
            .filter { !$0.content.isEmpty }
            .map { APIMessage(role: $0.role.rawValue, content: $0.content) }
        guard let answerID = store.addMessage(.assistant, content: "", to: conversationID) else { return }

        let requestID = UUID()
        activeRequestID = requestID
        activeAnswerID = answerID
        activeConversationID = conversationID
        isStreaming = true
        let selectedModel = settings.selectedModel
        let thinkingEnabled = settings.thinkingEnabled

        requestTask = Task {
            do {
                for try await delta in DeepSeekAPIClient.stream(
                    messages: outbound,
                    model: selectedModel,
                    thinkingEnabled: thinkingEnabled,
                    apiKey: apiKey
                ) {
                    guard !Task.isCancelled, activeRequestID == requestID else { break }
                    switch delta {
                    case .content(let text):
                        store.appendDelta(text, reasoning: false, conversationID: conversationID, messageID: answerID)
                    case .reasoning(let text):
                        store.appendDelta(text, reasoning: true, conversationID: conversationID, messageID: answerID)
                    }
                }
            } catch is CancellationError {
                // User tapped Stop; keep any partial answer.
            } catch {
                if activeRequestID == requestID && !Task.isCancelled {
                    errorText = error.localizedDescription
                }
            }
            if activeRequestID == requestID {
                if let answer = store.conversation(conversationID)?.messages.first(where: { $0.id == answerID }),
                   answer.content.isEmpty && answer.reasoning.isEmpty {
                    store.removeMessage(answerID, from: conversationID)
                }
                activeRequestID = nil
                activeAnswerID = nil
                activeConversationID = nil
                isStreaming = false
                requestTask = nil
                store.flush()
            }
        }
    }
}
