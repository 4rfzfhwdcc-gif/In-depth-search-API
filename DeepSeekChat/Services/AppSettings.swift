import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var selectedModel: DeepSeekModel {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel") }
    }

    @Published var thinkingEnabled: Bool {
        didSet { UserDefaults.standard.set(thinkingEnabled, forKey: "thinkingEnabled") }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        selectedModel = DeepSeekModel(rawValue: stored) ?? .flash
        thinkingEnabled = UserDefaults.standard.bool(forKey: "thinkingEnabled")
    }
}
