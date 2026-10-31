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
                    Text(settings.selectedModel.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据与费用") {
                    Text("聊天记录仅保存在此设备的 App 本地存储，卸载 App 通常会删除记录。")
                    Text("API 调用由 DeepSeek 按实际使用量计费；V4 Pro 通常比 Flash 更贵。")
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
