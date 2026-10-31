import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput = ""
    @State private var hasSavedKey = false
    @State private var showKey = false
    @State private var statusText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("API Key", systemImage: "key.horizontal")
                        Spacer()
                        Label(hasSavedKey ? "已配置" : "未配置", systemImage: hasSavedKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(hasSavedKey ? .green : .orange)
                            .font(.footnote)
                    }
                    HStack {
                        Group {
                            if showKey {
                                TextField("粘贴 sk- 开头的 Key", text: $apiKeyInput)
                            } else {
                                SecureField("粘贴 sk- 开头的 Key", text: $apiKeyInput)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(showKey ? "隐藏 Key" : "显示 Key")
                    }
                    Button("保存 API Key") {
                        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty else {
                            statusText = "请输入 API Key。"
                            return
                        }
                        if KeychainService.saveAPIKey(key) {
                            apiKeyInput = ""
                            hasSavedKey = true
                            statusText = "已保存到系统钥匙串。"
                        } else {
                            statusText = "保存失败，请重试。"
                        }
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedKey {
                        Button("删除已保存的 API Key", role: .destructive) {
                            if KeychainService.deleteAPIKey() {
                                hasSavedKey = false
                                apiKeyInput = ""
                                statusText = "已删除 API Key。"
                            } else {
                                statusText = "删除失败，请重试。"
                            }
                        }
                    }
                    Link("前往 DeepSeek 开放平台获取 Key", destination: URL(string: "https://platform.deepseek.com")!)
                } header: {
                    Text("连接设置")
                } footer: {
                    Text("只连接官方 api.deepseek.com。你的 Key 保存在本机钥匙串；消息会发送给 DeepSeek API 处理。")
                }

                Section("聊天模型") {
                    Picker("模型", selection: $settings.selectedModel) {
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
                        Text(settings.reasoningEffort.mappingDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(settings.selectedModel.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("模型 ID：\(settings.selectedModel.rawValue)。DeepSeek 公告称自 2026-09-14 起 deepseek-v4-pro 请求临时路由至 V4.1 Flash，直到 V4.1-Pro 发布；App 保留 V4.0 Pro 选项，实际模型由服务端决定。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据与费用") {
                    Text("聊天记录仅保存在此设备的 App 本地存储，卸载 App 通常会删除记录。")
                    Text("API 调用由 DeepSeek 按实际使用量计费；图片会转换为 JPEG 并随聊天请求发送。")
                    Text("图片最多每条消息 5 张；最长边压缩至 1600 px，单张不超过 2 MB。本地聊天记录会保存压缩图片，以便后续多轮对话继续引用。")
                    Text("推理强度由 DeepSeek 官方 API 的 low / high / max 三档控制：即时对应 low，均衡对应 high，Max 对应 max。")
                    Text("这是个人 API 客户端，不需要你部署中转服务器。")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                hasSavedKey = KeychainService.readAPIKey() != nil
            }
            .alert("提示", isPresented: Binding(
                get: { statusText != nil },
                set: { if !$0 { statusText = nil } }
            )) {
                Button("知道了", role: .cancel) { statusText = nil }
            } message: {
                Text(statusText ?? "")
            }
        }
    }
}
