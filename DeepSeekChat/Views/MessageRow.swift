import SwiftUI
import UIKit

struct MessageRow: View {
    let message: ChatMessage
    @State private var showReasoning = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if isUser { Spacer(minLength: 38) }
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 30, height: 30)
                    .background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            }
            VStack(alignment: .leading, spacing: 10) {
                if !isUser && !message.reasoning.isEmpty {
                    DisclosureGroup(isExpanded: $showReasoning) {
                        Text(message.reasoning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 7)
                    } label: {
                        Label("思考过程", systemImage: "brain.head.profile")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if isUser {
                    Text(message.content)
                        .textSelection(.enabled)
                } else if message.content.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(message.reasoning.isEmpty ? "正在思考…" : "正在生成回答…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } else {
                    MarkdownMessage(source: message.content)
                }
            }
            .font(.system(size: 16))
            .frame(maxWidth: isUser ? nil : .infinity, alignment: .leading)
            .padding(.horizontal, isUser ? 14 : 2)
            .padding(.vertical, isUser ? 11 : 5)
            .background {
                if isUser {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
            }
            if !isUser { Spacer(minLength: 4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownMessage: View {
    let source: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .full)
            ) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(source)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
