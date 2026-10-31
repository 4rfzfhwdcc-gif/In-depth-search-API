# DeepSeek Chat · 原生 iPhone App（SwiftUI）

这是一个独立、无第三方库的 iOS 17+ SwiftUI 工程，通过 **DeepSeek 官方 API** 实现 AI 聊天。

## 已实现功能

- DeepSeek V4 Flash (`deepseek-flash`) / V4 Pro (`deepseek-v4-pro`) 模型选择
- 「深度思考」开关：向官方 API 发送 `thinking: {"type": "enabled" | "disabled"}`
- SSE 流式聊天：实时展示生成内容以及可展开的思考内容
- 多轮对话、聊天历史、本地自动保存、左滑删除、开始新对话
- API Key 存在 iOS Keychain 中（没有写死 Key，也不会将 Key 保存到聊天文件）
- 请求取消、错误提示、文本选择和复制、浅色/深色系统主题
- 聊天记录存储在 App 沙盒 `Application Support/conversations.json`（不与第三方同步）

**不包含：** 图片/文件上传、语音、联网搜索工具、云端聊天同步、iOS 推送。

## 获取 API Key

从 [DeepSeek 开放平台](https://platform.deepseek.com) 创建 API Key，首次进入 App 的「设置」填写并保存。

> 请求直接从手机发到 `https://api.deepseek.com/chat/completions`，不经过自己搭建的转发服务。API 费用由你自己的 DeepSeek 账户产生。不要把 Key 放到公开仓库中。

## 方案一：使用 Mac + Xcode（建议，适合真机）

1. 在 Mac 上安装兼容设备系统版本的 Xcode。
2. 双击 `DeepSeekChat.xcodeproj`。
3. 选中项目 → `TARGETS` → `DeepSeekChat` → `Signing & Capabilities`，选自己的 Team。
4. 将 Bundle Identifier `com.example.deepseekchat` 改成自己唯一的标识。
5. 连接 iPhone，选设备后点击 Run 安装测试。
6. 若需导出签名 IPA：按自己的签名权限，在 Xcode 中 Archive → Distribute App。

注意：免费 Apple ID 的开发签名有期限与功能限制，导出用于分发的 IPA 可能需要 Apple Developer Program 资格、设备注册、合适的证书和描述文件。

## 方案二：只有 Windows，通过 GitHub Actions 编译 IPA（未签名）

1. 在 GitHub 新建一个代码仓库。
2. **先解压工程文件夹**，把 `DeepSeekChat.xcodeproj`、`DeepSeekChat/`、`.github/`、`README.md` 等放到仓库根目录。上传时确保隐藏的 `.github/workflows/build-unsigned-ipa.yml` 没丢失。
3. 提交后打开仓库的 **Actions** → **Build unsigned iOS IPA** → **Run workflow**。
4. 构建成功后到该次运行的 **Artifacts** 下载 `DeepSeekChat-unsigned-IPA`，其中有 `DeepSeekChat-unsigned.ipa`。
5. **注意：此 IPA 是未签名构建产物，无法直接在普通未越狱 iPhone 上点击安装。** 需要使用合规的个人/开发者签名方式重新签名；如需给其他人使用，需要合适的签名和分发方案。

GitHub Actions 使用 macOS 构建机。工作流在本环境没有实际执行过；如果 GitHub 的 runner/Xcode 版本发生变化，需根据日志调整。

## 重要说明

- 本工程为源代码和 Xcode 工程；由于本交付环境不是 macOS/Xcode，**目前没有真机编译、运行或签名验证，也没有附带已签名 IPA**。
- DeepSeek 的模型、接口和价格可能更新。当前模型 ID 与流式格式依据官方文档：
  - https://api-docs.deepseek.com/zh-cn/api/create-chat-completion/
  - https://api-docs.deepseek.com/zh-cn/api/list-models/
- 现有聊天记录在本机以 JSON 存储（设置 iOS 文件数据保护）；拥有已解锁设备/沙盒访问权限者仍可能读取聊天记录。不要把敏感信息直接发送给第三方 API。
- 卸载 App 通常会删除聊天文件；API Key 的钥匙串项可能遵循 iOS 钥匙串保留策略。
- 模型切换会影响**下一次**发送的消息，不会追溯修改历史生成内容。
