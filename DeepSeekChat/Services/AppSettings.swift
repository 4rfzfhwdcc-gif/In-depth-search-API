import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var selectedModel: DeepSeekModel {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel") }
    }

    @Published var thinkingEnabled: Bool {
        didSet { UserDefaults.standard.set(thinkingEnabled, forKey: "thinkingEnabled") }
    }

    @Published var reasoningEffort: DeepSeekReasoningEffort {
        didSet { UserDefaults.standard.set(reasoningEffort.rawValue, forKey: "reasoningEffort") }
    }

    init() {
        let storedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        selectedModel = DeepSeekModel(rawValue: storedModel) ?? .flash
        thinkingEnabled = UserDefaults.standard.bool(forKey: "thinkingEnabled")
        let storedEffort = UserDefaults.standard.string(forKey: "reasoningEffort") ?? ""
        reasoningEffort = DeepSeekReasoningEffort(rawValue: storedEffort) ?? .high
    }
}
