import Foundation

// MARK: - Exam Modes
public enum ExamMode: String, CaseIterable, Identifiable, Codable {
    case remote = "remote"
    case cbt = "cbt"
    case capsLock = "capsLock"
    case flash = "flash"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .remote: return "Remote Exam (Invisible HUD Window)"
        case .cbt: return "In-Person CBT (Menu Bar Stealth)"
        case .capsLock: return "Discreet LED (Caps Lock Blink)"
        case .flash: return "Discreet Pulse (Screen Border)"
        }
    }
    
    public var description: String {
        switch self {
        case .remote:
            return "Answers stream in a floating HUD window excluded from screen recording (invisible on Zoom/Teams/Screenshots)."
        case .cbt:
            return "Multiple-choice answer appears discreetly as a menu bar number/letter."
        case .capsLock:
            return "The keyboard Caps Lock LED blinks the answer number (e.g. 3 blinks for option 3)."
        case .flash:
            return "The screen border pulses subtly to signal the answer number."
        }
    }
}

// MARK: - Menu Bar Icon Disguise (Stealth system icons)
public enum MenuBarDisguise: String, CaseIterable, Identifiable, Codable {
    case settings = "settings"
    case wifi = "wifi"
    case battery = "battery"
    case controlCenter = "controlCenter"
    case volume = "volume"
    case focus = "focus"
    case display = "display"
    case spotlight = "spotlight"
    case rubricHexagon = "rubricHexagon"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .settings: return "Settings (Gear ⚙️)"
        case .wifi: return "Wi-Fi (Signal 📶)"
        case .battery: return "Battery (100% 🔋)"
        case .controlCenter: return "Control Center (🎛)"
        case .volume: return "Sound / Volume (🔊)"
        case .focus: return "Focus / Do Not Disturb (🌙)"
        case .display: return "Display / Monitor (🖥)"
        case .spotlight: return "Search / Spotlight (🔍)"
        case .rubricHexagon: return "Default (NOX RED)"
        }
    }
    
    public var systemSymbolName: String {
        switch self {
        case .settings: return "gearshape.fill"
        case .wifi: return "wifi"
        case .battery: return "battery.100"
        case .controlCenter: return "slider.horizontal.3"
        case .volume: return "speaker.wave.2.fill"
        case .focus: return "moon.fill"
        case .display: return "display"
        case .spotlight: return "magnifyingglass"
        case .rubricHexagon: return "hexagon.fill"
        }
    }
}

// MARK: - LLM Backend Type
public enum LLMBackend: String, CaseIterable, Identifiable, Codable {
    case ollama = "ollama"
    case cloudAPI = "cloudAPI"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .ollama: return "Local Ollama (Offline)"
        case .cloudAPI: return "Cloud API (OpenAI / Groq / OpenRouter)"
        }
    }
}

// MARK: - LLM Configuration
public struct LLMConfig: Codable {
    public var backend: LLMBackend = .ollama
    public var endpoint: String = "http://localhost:11434"
    public var selectedModel: String = "qwen2.5vl:3b"
    public var apiKey: String = ""
    public var temperature: Double = 0.1
    public var systemPrompt: String = """
You are an expert exam and interview assistant. You are given an image or OCR text of a question.
Analyze the question carefully.
1. If it is multiple-choice: Clearly identify the correct option number/letter, state it first as "ANSWER: [Number/Letter]", then provide a concise 1-2 sentence explanation.
2. If it is a coding/technical question: Provide the direct solution and concise explanation.
3. Be as accurate, clear, and direct as possible.
"""
    public var preferVision: Bool = true
    
    public init() {}
}

// MARK: - Question Solve Response
public struct SolveResult {
    public var questionText: String
    public var fullAnswer: String
    public var parsedChoice: Int? // 1, 2, 3, 4, etc.
    public var parsedLetter: String? // "A", "B", "C", "D"
    public var latencyMs: Int
    
    public init(questionText: String, fullAnswer: String, parsedChoice: Int? = nil, parsedLetter: String? = nil, latencyMs: Int = 0) {
        self.questionText = questionText
        self.fullAnswer = fullAnswer
        self.parsedChoice = parsedChoice
        self.parsedLetter = parsedLetter
        self.latencyMs = latencyMs
    }
}

// MARK: - App State / Settings Store
public final class AppSettings {
    public static let shared = AppSettings()
    
    public var mode: ExamMode = .remote
    
    private let llmConfigKey = "NoxWhisperRed.llmConfig"
    private var _cachedLLMConfig: LLMConfig? = nil
    public var llmConfig: LLMConfig {
        get {
            if let cached = _cachedLLMConfig { return cached }
            if let data = UserDefaults.standard.data(forKey: llmConfigKey),
               let decoded = try? JSONDecoder().decode(LLMConfig.self, from: data) {
                _cachedLLMConfig = decoded
                return decoded
            }
            let def = LLMConfig()
            _cachedLLMConfig = def
            return def
        }
        set {
            _cachedLLMConfig = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: llmConfigKey)
            }
        }
    }
    public var availableModels: [String] = []
    
    private let disguiseKey = "NoxWhisperRed.menuBarDisguise"
    public var menuBarDisguise: MenuBarDisguise {
        get {
            if let saved = UserDefaults.standard.string(forKey: disguiseKey),
               let d = MenuBarDisguise(rawValue: saved) {
                return d
            }
            return .rubricHexagon
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: disguiseKey)
        }
    }
    public var isSolving: Bool = false
    public var currentStatus: String = "Ready"
    public var latestResult: SolveResult? = nil
    
    // Shortcuts
    public var triggerShortcutText: String = "⌥ + ⌘ + ⌃"
    public var toggleHUDShortcutText: String = "⌥ + ⌘ + H"
    
    public var onStateChange: (() -> Void)? = nil
    
    private init() {}
    
    public func notifyChange() {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?()
        }
    }
}
