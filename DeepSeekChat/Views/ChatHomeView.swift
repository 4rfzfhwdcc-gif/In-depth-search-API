import SwiftUI
import PhotosUI
import UIKit

@MainActor
struct ChatHomeView: View {
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedID: UUID?
    @State private var draft = ""
    @State private var selectedImages: [ChatImageAttachment] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showImageSourceOptions = false
    @State private var showCamera = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var isStreaming = false
    @State private var requestTask: Task<Void, Never>?
    @State private var activeRequestID: UUID?
    @State private var activeAnswerID: UUID?
    @State private var activeConversationID: UUID?
    @State private var errorText: String?

    private let maxImagesPerMessage = 5
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
                        if settings.thinkingEnabled {
                            Picker("推理强度", selection: $settings.reasoningEffort) {
                                ForEach(DeepSeekReasoningEffort.allCases) { effort in
                                    Text(effort.displayName).tag(effort)
                                }
                            }
                        }
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
            .sheet(isPresented: $showCamera) {
                CameraImagePicker(
                    onImage: { image in
                        if let attachment = makeAttachment(from: image) {
                            appendSelectedImage(attachment)
                        }
                        showCamera = false
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoPickerItems,
                maxSelectionCount: max(1, maxImagesPerMessage - selectedImages.count),
                matching: .images
            )
            .confirmationDialog("添加图片", isPresented: $showImageSourceOptions, titleVisibility: .visible) {
                Button("从相册选择") { showPhotoPicker = true }
                Button("拍照") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        errorText = "当前设备没有可用的摄像头。"
                    }
                }
                Button("取消", role: .cancel) { }
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
            .onChange(of: photoPickerItems) { _, items in
                loadPickedImages(items)
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
            Text("DeepSeek \(settings.selectedModel.shortName) 已就绪\n输入问题或添加图片，开始新对话")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(selectedImages) { attachment in
                            ZStack(alignment: .topTrailing) {
                                if let image = UIImage(data: attachment.data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Button {
                                    selectedImages.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.65))
                                }
                                .offset(x: 5, y: -5)
                                .accessibilityLabel("移除图片")
                            }
                            .padding(.top, 5)
                            .padding(.trailing, 5)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 80)
            }

            HStack(alignment: .bottom, spacing: 9) {
                Button {
                    showImageSourceOptions = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .frame(width: 42, height: 42)
                        .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                }
                .disabled(isStreaming || selectedImages.count >= maxImagesPerMessage)
                .accessibilityLabel("添加图片")

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
                .disabled(!isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty)
                .opacity((!isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty) ? 0.4 : 1)
                .accessibilityLabel(isStreaming ? "停止生成" : "发送消息")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.bar)
    }

    private func loadPickedImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let availableSlots = max(0, maxImagesPerMessage - selectedImages.count)
        guard availableSlots > 0 else {
            photoPickerItems = []
            return
        }
        Task { @MainActor in
            var loaded: [ChatImageAttachment] = []
            for item in items.prefix(availableSlots) {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let attachment = makeAttachment(from: image) else { continue }
                loaded.append(attachment)
            }
            selectedImages.append(contentsOf: loaded)
            photoPickerItems = []
            if loaded.isEmpty {
                errorText = "没有读取到可用图片，请选择 JPEG、PNG 或其他常见图片格式。"
            }
        }
    }

    private func makeAttachment(from image: UIImage) -> ChatImageAttachment? {
        let maxSide: CGFloat = 1600
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        let scale = min(1, maxSide / max(originalSize.width, originalSize.height))
        let targetSize = CGSize(
            width: max(1, (originalSize.width * scale).rounded()),
            height: max(1, (originalSize.height * scale).rounded())
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        var quality: CGFloat = 0.78
        var jpegData = resized.jpegData(compressionQuality: quality)
        while let currentData = jpegData, currentData.count > 2 * 1024 * 1024, quality > 0.48 {
            quality -= 0.1
            jpegData = resized.jpegData(compressionQuality: quality)
        }
        guard let data = jpegData, data.count <= 2 * 1024 * 1024 else {
            errorText = "图片压缩后仍超过 2 MB，请换一张图片。"
            return nil
        }
        return ChatImageAttachment(mimeType: "image/jpeg", data: data)
    }

    private func appendSelectedImage(_ attachment: ChatImageAttachment) {
        guard selectedImages.count < maxImagesPerMessage else {
            errorText = "每条消息最多发送 5 张图片。"
            return
        }
        selectedImages.append(attachment)
    }

    private func newConversation() {
        stop()
        selectedID = store.createConversation()
        draft = ""
        selectedImages = []
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
        guard !prompt.isEmpty || !selectedImages.isEmpty else { return }
        guard let apiKey = KeychainService.readAPIKey(), !apiKey.isEmpty else {
            showSettings = true
            return
        }

        let conversationID = selectedID ?? store.createConversation()
        selectedID = conversationID
        let outgoingImages = selectedImages
        guard store.addMessage(.user, content: prompt, attachments: outgoingImages, to: conversationID) != nil else { return }
        draft = ""
        selectedImages = []

        let outbound = (store.conversation(conversationID)?.messages ?? [])
            .map { APIMessage(role: $0.role.rawValue, text: $0.content, attachments: $0.attachments) }
        guard let answerID = store.addMessage(.assistant, content: "", to: conversationID) else { return }

        let requestID = UUID()
        activeRequestID = requestID
        activeAnswerID = answerID
        activeConversationID = conversationID
        isStreaming = true
        let selectedModel = settings.selectedModel
        let thinkingEnabled = settings.thinkingEnabled
        let reasoningEffort = settings.reasoningEffort

        requestTask = Task {
            do {
                for try await delta in DeepSeekAPIClient.stream(
                    messages: outbound,
                    model: selectedModel,
                    thinkingEnabled: thinkingEnabled,
                    reasoningEffort: reasoningEffort,
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

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            onCancel()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
