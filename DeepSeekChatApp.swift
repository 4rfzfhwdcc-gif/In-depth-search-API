import SwiftUI

@main
@MainActor
struct DeepSeekChatApp: App {
    @StateObject private var chatStore = ChatStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ChatHomeView()
                .environmentObject(chatStore)
                .environmentObject(settings)
        }
    }
}
