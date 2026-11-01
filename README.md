# DeepSeek Chat V1.3.0 · 原生 iPhone App（SwiftUI）

独立、无第三方库的 iOS 17+ SwiftUI 工程，直接连接 DeepSeek 官方 API。

## V1.3.0 功能

- 默认模型：DeepSeek V4.1 Flash（API ID：`deepseek-flash`）
- 保留 DeepSeek V4.0 Pro 选项（API ID：`deepseek-v4-pro`）
- 深度思考开关；开启后可选「即时 / 均衡 / Max」三档推理强度
- SSE 流式聊天，分别接收回答与 `reasoning_content`
- 图片发送：从系统相册多选，或使用相机拍照；每条消息最多 5 张
- 图片在本机转为 JPEG，最长边缩放至 1600 px，单张不超过 2 MB
- 图片以 Base64 data URL 随 Chat Completions 请求发送；图片也会保存在本地聊天记录中，支持多轮引用
- 多轮对话、聊天历史、本地自动保存、左滑删除、开始新对话
- API Key 存在 iOS Keychain 中，不写入源码或聊天记录
- 联网搜索开关：通过 DeepSeek 官方 Search API 检索最多 5 条网页摘要，模型回答附带来源链接
- 长按用户消息可撤回，并同时删除该消息及其对应的 AI 回复（仅删除本机记录）
- 请求取消、错误提示、文本选择和复制、浅色/深色系统主题

## 模型与官方路由说明

- `deepseek-flash` 对应 DeepSeek V4.1 Flash，且官方 Vision 文档明确支持图片输入。
- App 按要求将 `deepseek-v4-pro` 显示为「DeepSeek V4.0 Pro」并保留此选项。但 DeepSeek 官方公告称，自 2026-09-14 起，`deepseek-v4-pro` 请求临时路由至 V4.1 Flash，直到 V4.1-Pro 发布。实际推理模型和计费以 DeepSeek 服务端当前路由为准。
- 官方 Vision 文档明确列出的图片输入模型是 `deepseek-flash`。图片分析建议选择 V4.1 Flash；若选择 V4.0 Pro 后图片请求返回 HTTP 400，请切换至 V4.1 Flash 重试。

## 推理强度映射

DeepSeek Chat Completions 官方支持 `low`、`high`、`max` 三档（关闭深度思考时使用 `none`）。App 直接提供一一对应的三个选项：

| App 选项 | API `reasoning_effort` | 说明 |
|---|---|---|
| 即时 | `low` | 优先响应速度，较低推理强度 |
| 均衡 | `high` | 兼顾速度与推理深度，默认档位 |
| Max | `max` | 最高推理强度，适合复杂任务 |

关闭深度思考时，推理强度选择器隐藏，并向 API 发送 `thinking: {"type":"disabled"}` 与 `reasoning_effort: "none"`。

## V1.2.1 流式修复（2026-11-01）

- 兼容 Chat Completions SSE 空事件、用量统计事件、只有角色没有文本的首帧以及最后的 `[DONE]` 不带空行的情况。
- 正常处理 `Content-Type: application/json` 的非流式回复，不再直接报流式格式异常。
- 当服务器流式响应格式异常且 **尚未收到任何文字或思考内容** 时，自动回退 **一次** 普通非流式请求。可能会产生额外一次 API 调用和费用；收到部分内容后不会自动重发。
- 网络中断时保留部分已收到的回复，返回更清晰的错误原因；HTTP 401/402/429 仍直接提示，不会自动重试。
- 保留 V1.2 的「即时 / 均衡 / Max」档位，旧档位偏好自动迁移。
- 不更改 API Key 的 Keychain 保存方式、Bundle ID 或聊天记录文件格式。

**重要：** 该补丁修复了已确认的解析器脆弱性，但没有用户的私有 API 响应样本，不能保证截图中问题的具体根因一定是同一个。请在重新构建 IPA 并安装后实测「你好」。

## 联网搜索

- 开关可在顶部模型菜单或「设置 → 聊天模型」中控制，默认关闭。
- 开启后，文字问题会先请求 `POST https://api.deepseek.com/v1/tools/search`，取回最多 5 条网页摘要，再作为外部参考资料交给当前所选模型。
- 搜索结果会被明确标记为不可信外部内容，模型被要求忽略其中的指令，并用 Markdown 链接标注来源。
- 搜索词与原问题按官方接口限制截取至 128 个字符；纯图片消息不触发独立搜索。
- 官方 Search API 当前价格为每 1,000 次成功且返回结果的请求 0.75 美元；模型输入 Token 另行计费。失败或无结果请求不计 Search 请求费用，价格以官方文档为准。

## 撤回消息

- 长按自己发送的消息，选择「撤回消息」，确认后删除该用户消息及其后紧邻的 AI 回复。
- 如果该消息对应的 AI 回复仍在生成，会先取消当前请求，再删除这一组消息。
- 撤回仅修改本机聊天记录；已发送给 DeepSeek API 的内容无法从服务器端收回。
- 撤回较早的消息时，如果同一对话正在生成另一条回复，需先停止生成，避免正在使用的上下文与本地历史不一致。

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