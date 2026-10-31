# DeepSeek Chat V1.1 · 原生 iPhone App（SwiftUI）

独立、无第三方库的 iOS 17+ SwiftUI 工程，直接连接 DeepSeek 官方 API。

## V1.1 功能

- 默认模型：DeepSeek V4.1 Flash（API ID：`deepseek-flash`）
- 保留 DeepSeek V4.0 Pro 选项（API ID：`deepseek-v4-pro`）
- 深度思考开关；开启后可选「即时 / 中 / 高 / 极限 / Max」推理强度
- SSE 流式聊天，分别接收回答与 `reasoning_content`
- 图片发送：从系统相册多选，或使用相机拍照；每条消息最多 5 张
- 图片在本机转为 JPEG，最长边缩放至 1600 px，单张不超过 2 MB
- 图片以 Base64 data URL 随 Chat Completions 请求发送；图片也会保存在本地聊天记录中，支持多轮引用
- 多轮对话、聊天历史、本地自动保存、左滑删除、开始新对话
- API Key 存在 iOS Keychain 中，不写入源码或聊天记录
- 请求取消、错误提示、文本选择和复制、浅色/深色系统主题

## 模型与官方路由说明

- `deepseek-flash` 对应 DeepSeek V4.1 Flash，且官方 Vision 文档明确支持图片输入。
- App 按要求将 `deepseek-v4-pro` 显示为「DeepSeek V4.0 Pro」并保留此选项。但 DeepSeek 官方公告称，自 2026-09-14 起，`deepseek-v4-pro` 请求临时路由至 V4.1 Flash，直到 V4.1-Pro 发布。实际推理模型和计费以 DeepSeek 服务端当前路由为准。
- 官方 Vision 文档明确列出的图片输入模型是 `deepseek-flash`。图片分析建议选择 V4.1 Flash；若选择 V4.0 Pro 后图片请求返回 HTTP 400，请切换至 V4.1 Flash 重试。

## 推理强度映射

DeepSeek Chat Completions 当前实际支持 `low`、`high`、`max` 三档（关闭深度思考时使用 `none`）。为了保留用户要求的五个界面选项，映射如下：

| App 选项 | API `reasoning_effort` | 说明 |
|---|---|---|
| 即时 | `low` | 最低思考强度 |
| 中 | `high` | DeepSeek 将 `medium` 归一化为 `high` |
| 高 | `high` | 官方 high |
| 极限 | `max` | 官方 max |
| Max | `max` | 官方 max |

因此「中/高」以及「极限/Max」目前是相同的服务端强度，不代表 API 有五个独立档位。后续 DeepSeek 若开放更多强度档位，可再扩展映射。

## API Key

从 [DeepSeek 开放平台](https://platform.deepseek.com) 创建 API Key，在 App 的「设置」中保存。请求直接从手机发送到 `https://api.deepseek.com/chat/completions`，不经过中转服务器。

## Windows 用户构建 IPA

1. 将工程根目录中的 `.github/`、`DeepSeekChat/`、`DeepSeekChat.xcodeproj/`、`.gitignore` 和 `README.md` 上传到 GitHub 仓库根目录。
2. 打开仓库的 **Actions** → **构建无签名的 iOS IPA** → **运行工作流程**。
3. 构建成功后，在该次运行页面的 Artifacts 下载 `DeepSeekChat-unsigned-IPA`。
4. 解压后得到 `DeepSeekChat-unsigned.ipa`。这是未签名 IPA，需要使用自己的合规签名方式签名后安装。

## 隐私与限制

- API Key 保存在 iOS Keychain。
- 聊天记录和压缩图片仅保存在本机 App 沙盒；卸载 App 通常会删除本地聊天文件。
- 图片每条消息最多 5 张、单张最多 2 MB；当前图片发送采用 Base64 data URL。
- 相册使用系统 Photos Picker；拍照需要相机权限。
- 该项目未在当前环境中使用 Xcode 真机编译或运行。GitHub Actions 构建成功后仍应在 iPhone 上验证相册、相机、图片 API、多轮对话和推理强度。
