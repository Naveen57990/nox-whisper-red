import Foundation
import Cocoa

public final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    public static let shared = SettingsWindowController()
    
    private var modeRadioButtons: [NSButton] = []
    
    // LLM & API Tab Properties
    private var backendRadioButtons: [NSButton] = []
    private var presetPopup: NSPopUpButton?
    private var apiKeyField: NSTextField?
    private var endpointField: NSTextField?
    private var modelField: NSTextField?
    private var modelPopup: NSPopUpButton?
    private var visionCheckbox: NSButton?
    private var testStatusLabel: NSTextField?
    
    private var screenPermLabel: NSTextField?
    private var accessPermLabel: NSTextField?
    
    // Disguise Icon Tab Properties
    private var disguiseRadioButtons: [NSButton] = []
    private var disguisePreviewImageView: NSImageView?
    private var disguisePreviewTitle: NSTextField?
    
    private struct ProviderPreset {
        let name: String
        let backend: LLMBackend
        let endpoint: String
        let defaultModel: String
        let recommendedModels: [String]
    }
    
    private let providerPresets: [ProviderPreset] = [
        ProviderPreset(
            name: "Ollama Local (Offline, Free)",
            backend: .ollama,
            endpoint: "http://localhost:11434",
            defaultModel: "qwen2.5vl:3b",
            recommendedModels: ["qwen2.5vl:3b", "qwen2.5vl:7b", "qwen2.5:7b", "llama3.2-vision", "deepseek-r1:8b"]
        ),
        ProviderPreset(
            name: "OpenAI (GPT-4o / GPT-4o-mini)",
            backend: .cloudAPI,
            endpoint: "https://api.openai.com/v1",
            defaultModel: "gpt-4o",
            recommendedModels: ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"]
        ),
        ProviderPreset(
            name: "Groq (Ultra-Fast 70B, ~400ms)",
            backend: .cloudAPI,
            endpoint: "https://api.groq.com/openai/v1",
            defaultModel: "llama-3.3-70b-versatile",
            recommendedModels: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]
        ),
        ProviderPreset(
            name: "OpenRouter (Gemini, Claude, Multi)",
            backend: .cloudAPI,
            endpoint: "https://openrouter.ai/api/v1",
            defaultModel: "google/gemini-2.0-flash-exp:free",
            recommendedModels: ["google/gemini-2.0-flash-exp:free", "anthropic/claude-3.5-sonnet", "meta-llama/llama-3.3-70b-instruct"]
        ),
        ProviderPreset(
            name: "DeepSeek (DeepSeek-V3 / R1)",
            backend: .cloudAPI,
            endpoint: "https://api.deepseek.com/v1",
            defaultModel: "deepseek-chat",
            recommendedModels: ["deepseek-chat", "deepseek-reasoner"]
        ),
        ProviderPreset(
            name: "Custom OpenAI-Compatible Endpoint",
            backend: .cloudAPI,
            endpoint: "",
            defaultModel: "",
            recommendedModels: []
        )
    ]
    
    private init() {
        let win = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 640, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "NOX WHISHPER RED - Settings & LLM"
        win.center()
        win.isReleasedWhenClosed = false
        super.init(window: win)
        buildUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func buildUI() {
        guard let win = window else { return }
        let contentView = NSView(frame: win.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        
        let tabView = NSTabView(frame: NSRect(x: 16, y: 16, width: contentView.bounds.width - 32, height: contentView.bounds.height - 32))
        tabView.autoresizingMask = [.width, .height]
        
        // Tab 1: Mode
        let modeTab = NSTabViewItem(identifier: "mode")
        modeTab.label = "Feedback Mode"
        modeTab.view = createModeView(frame: tabView.bounds)
        tabView.addTabViewItem(modeTab)
        
        // Tab 2: Menu Bar Icon Disguise
        let iconTab = NSTabViewItem(identifier: "icon")
        iconTab.label = "Menu Bar Icon"
        iconTab.view = createIconDisguiseView(frame: tabView.bounds)
        tabView.addTabViewItem(iconTab)
        
        // Tab 3: LLM Engine & API
        let llmTab = NSTabViewItem(identifier: "llm")
        llmTab.label = "LLM Engine & API"
        llmTab.view = createLLMView(frame: tabView.bounds)
        tabView.addTabViewItem(llmTab)
        
        // Tab 4: Permissions & Test
        let permTab = NSTabViewItem(identifier: "perm")
        permTab.label = "Permissions & Benchmark"
        permTab.view = createPermView(frame: tabView.bounds)
        tabView.addTabViewItem(permTab)
        
        contentView.addSubview(tabView)
        win.contentView = contentView
    }
    
    // MARK: - Tab 1: Modes
    private func createModeView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        
        let title = NSTextField(labelWithString: "Select Answer Delivery Mode:")
        title.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        title.frame = NSRect(x: 20, y: frame.height - 50, width: 400, height: 22)
        view.addSubview(title)
        
        var yPos = frame.height - 90
        modeRadioButtons.removeAll()
        
        for mode in ExamMode.allCases {
            let btn = NSButton(radioButtonWithTitle: mode.displayName, target: self, action: #selector(didSelectModeRadio(_:)))
            btn.frame = NSRect(x: 24, y: yPos, width: 360, height: 22)
            btn.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            btn.state = (AppSettings.shared.mode == mode) ? .on : .off
            view.addSubview(btn)
            modeRadioButtons.append(btn)
            
            let desc = NSTextField(labelWithString: mode.description)
            desc.frame = NSRect(x: 44, y: yPos - 34, width: frame.width - 80, height: 32)
            desc.font = NSFont.systemFont(ofSize: 11)
            desc.textColor = .secondaryLabelColor
            view.addSubview(desc)
            
            yPos -= 70
        }
        
        let shortcutNote = NSTextField(labelWithString: "💡 Press ⌥ + ⌘ + ⌃ (Option + Command + Control) to solve the question under your cursor.\n💡 Press ⌥ + ⌘ + H to toggle the Invisible HUD window.")
        shortcutNote.frame = NSRect(x: 24, y: 30, width: frame.width - 50, height: 40)
        shortcutNote.font = NSFont.systemFont(ofSize: 12)
        shortcutNote.textColor = .systemBlue
        view.addSubview(shortcutNote)
        
        return view
    }
    
    @objc private func didSelectModeRadio(_ sender: NSButton) {
        guard let idx = modeRadioButtons.firstIndex(of: sender), idx < ExamMode.allCases.count else { return }
        let selected = ExamMode.allCases[idx]
        AppSettings.shared.mode = selected
        for (i, btn) in modeRadioButtons.enumerated() {
            btn.state = (i == idx) ? .on : .off
        }
        MenuBarManager.shared.rebuildMenu()
    }
    
    // MARK: - Tab 3: LLM Engine & Cloud API
    private func createLLMView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        let currentBackend = AppSettings.shared.llmConfig.backend
        let currentEP = AppSettings.shared.llmConfig.endpoint
        
        let title = NSTextField(labelWithString: "LLM Engine & Cloud API Configuration")
        title.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        title.frame = NSRect(x: 20, y: frame.height - 38, width: 380, height: 22)
        view.addSubview(title)
        
        // 1. Engine Backend Selector
        let backendLabel = NSTextField(labelWithString: "Engine Backend:")
        backendLabel.frame = NSRect(x: 20, y: frame.height - 70, width: 130, height: 18)
        backendLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(backendLabel)
        
        backendRadioButtons.removeAll()
        let b1 = NSButton(radioButtonWithTitle: "Local Ollama (Offline, Free)", target: self, action: #selector(didSelectBackendRadio(_:)))
        b1.frame = NSRect(x: 160, y: frame.height - 71, width: 220, height: 22)
        b1.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        b1.state = (currentBackend == .ollama) ? .on : .off
        view.addSubview(b1)
        backendRadioButtons.append(b1)
        
        let b2 = NSButton(radioButtonWithTitle: "Cloud API Key (OpenAI / Groq / etc.)", target: self, action: #selector(didSelectBackendRadio(_:)))
        b2.frame = NSRect(x: 390, y: frame.height - 71, width: 220, height: 22)
        b2.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        b2.state = (currentBackend == .cloudAPI) ? .on : .off
        view.addSubview(b2)
        backendRadioButtons.append(b2)
        
        // 2. Provider Preset
        let presetLabel = NSTextField(labelWithString: "Provider Preset:")
        presetLabel.frame = NSRect(x: 20, y: frame.height - 105, width: 130, height: 18)
        presetLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(presetLabel)
        
        let presetPop = NSPopUpButton(frame: NSRect(x: 160, y: frame.height - 107, width: 340, height: 26))
        for p in providerPresets {
            presetPop.addItem(withTitle: p.name)
        }
        presetPop.target = self
        presetPop.action = #selector(didSelectPreset(_:))
        view.addSubview(presetPop)
        self.presetPopup = presetPop
        
        // Select matching preset
        if currentBackend == .ollama || currentEP.contains("11434") {
            presetPop.selectItem(at: 0)
        } else if currentEP.contains("openai.com") {
            presetPop.selectItem(at: 1)
        } else if currentEP.contains("groq.com") {
            presetPop.selectItem(at: 2)
        } else if currentEP.contains("openrouter.ai") {
            presetPop.selectItem(at: 3)
        } else if currentEP.contains("deepseek.com") {
            presetPop.selectItem(at: 4)
        } else {
            presetPop.selectItem(at: 5)
        }
        
        // 3. API Key
        let keyLabel = NSTextField(labelWithString: "API Key:")
        keyLabel.frame = NSRect(x: 20, y: frame.height - 140, width: 130, height: 18)
        keyLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(keyLabel)
        
        let keyField = NSTextField(frame: NSRect(x: 160, y: frame.height - 142, width: 340, height: 24))
        keyField.stringValue = AppSettings.shared.llmConfig.apiKey
        keyField.placeholderString = (currentBackend == .ollama) ? "(Optional for local Ollama)" : "sk-... (Paste your API key here)"
        keyField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        keyField.delegate = self
        view.addSubview(keyField)
        self.apiKeyField = keyField
        
        // 4. Server Endpoint
        let epLabel = NSTextField(labelWithString: "Server Endpoint:")
        epLabel.frame = NSRect(x: 20, y: frame.height - 175, width: 130, height: 18)
        epLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(epLabel)
        
        let epField = NSTextField(frame: NSRect(x: 160, y: frame.height - 177, width: 250, height: 24))
        epField.stringValue = AppSettings.shared.llmConfig.endpoint
        epField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        epField.delegate = self
        view.addSubview(epField)
        self.endpointField = epField
        
        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(refreshModels))
        refreshBtn.frame = NSRect(x: 420, y: frame.height - 179, width: 80, height: 28)
        view.addSubview(refreshBtn)
        
        // 5. Selected Model
        let modelLabel = NSTextField(labelWithString: "Selected Model:")
        modelLabel.frame = NSRect(x: 20, y: frame.height - 210, width: 130, height: 18)
        modelLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(modelLabel)
        
        let mField = NSTextField(frame: NSRect(x: 160, y: frame.height - 212, width: 190, height: 24))
        mField.stringValue = AppSettings.shared.llmConfig.selectedModel
        mField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        mField.delegate = self
        view.addSubview(mField)
        self.modelField = mField
        
        let mPopup = NSPopUpButton(frame: NSRect(x: 355, y: frame.height - 214, width: 145, height: 26))
        mPopup.target = self
        mPopup.action = #selector(didSelectModelPopup(_:))
        view.addSubview(mPopup)
        self.modelPopup = mPopup
        
        // 6. Vision Checkbox
        let visCheck = NSButton(checkboxWithTitle: "Send screenshot image directly to Vision-capable models (e.g. gpt-4o, qwen2.5vl:3b)", target: self, action: #selector(didToggleVision))
        visCheck.frame = NSRect(x: 160, y: frame.height - 246, width: 440, height: 20)
        visCheck.state = AppSettings.shared.llmConfig.preferVision ? .on : .off
        view.addSubview(visCheck)
        self.visionCheckbox = visCheck
        
        // 7. Test Connection & Status
        let testBtn = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testBtn.frame = NSRect(x: 160, y: frame.height - 288, width: 140, height: 32)
        testBtn.bezelStyle = .rounded
        view.addSubview(testBtn)
        
        let statusLbl = NSTextField(labelWithString: "")
        statusLbl.frame = NSRect(x: 310, y: frame.height - 284, width: 280, height: 22)
        statusLbl.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(statusLbl)
        self.testStatusLabel = statusLbl
        
        // 8. Help / Guide Box
        let helpBox = NSBox(frame: NSRect(x: 20, y: 16, width: frame.width - 40, height: 98))
        helpBox.title = "Offline Local vs Cloud API Key"
        
        let helpText = NSTextField(wrappingLabelWithString: "• Local Ollama: 100% offline, free, private, zero subscription fees. Runs directly on your Mac (e.g. `ollama run qwen2.5vl:3b`).\n• Cloud API: Use your OpenAI, Groq, OpenRouter, or DeepSeek API key for lightning-fast speeds (~400ms on Groq) or large vision models.\n• Both modes stream live answers directly into the stealth Remote HUD and CBT menu bar.")
        helpText.frame = NSRect(x: 10, y: 6, width: helpBox.bounds.width - 24, height: 68)
        helpText.font = NSFont.systemFont(ofSize: 11)
        helpText.textColor = .secondaryLabelColor
        helpBox.addSubview(helpText)
        view.addSubview(helpBox)
        
        // Initialize model dropdown
        let initialModels = AppSettings.shared.availableModels.isEmpty ?
            (providerPresets.first(where: { $0.backend == currentBackend })?.recommendedModels ?? ["qwen2.5vl:3b"]) :
            AppSettings.shared.availableModels
        updateModelDropdown(with: initialModels)
        
        return view
    }
    
    @objc private func didSelectBackendRadio(_ sender: NSButton) {
        guard let idx = backendRadioButtons.firstIndex(of: sender) else { return }
        let backend: LLMBackend = (idx == 0) ? .ollama : .cloudAPI
        AppSettings.shared.llmConfig.backend = backend
        updateBackendRadios()
        
        if backend == .ollama {
            if AppSettings.shared.llmConfig.endpoint.isEmpty || AppSettings.shared.llmConfig.endpoint.contains("api.") {
                AppSettings.shared.llmConfig.endpoint = "http://localhost:11434"
                endpointField?.stringValue = "http://localhost:11434"
            }
            presetPopup?.selectItem(at: 0)
            updateModelDropdown(with: providerPresets[0].recommendedModels)
        } else {
            if AppSettings.shared.llmConfig.endpoint.contains("11434") || AppSettings.shared.llmConfig.endpoint.isEmpty {
                AppSettings.shared.llmConfig.endpoint = "https://api.openai.com/v1"
                endpointField?.stringValue = "https://api.openai.com/v1"
                AppSettings.shared.llmConfig.selectedModel = "gpt-4o"
                modelField?.stringValue = "gpt-4o"
                OverlayController.shared.updateModelBadge()
            }
            presetPopup?.selectItem(at: 1)
            updateModelDropdown(with: providerPresets[1].recommendedModels)
        }
    }
    
    private func updateBackendRadios() {
        let isOllama = AppSettings.shared.llmConfig.backend == .ollama
        if backendRadioButtons.count >= 2 {
            backendRadioButtons[0].state = isOllama ? .on : .off
            backendRadioButtons[1].state = isOllama ? .off : .on
        }
        apiKeyField?.placeholderString = isOllama ? "(Optional for local Ollama)" : "sk-... (Required for Cloud API)"
    }
    
    @objc private func didSelectPreset(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < providerPresets.count else { return }
        let preset = providerPresets[idx]
        
        if preset.name.contains("Custom") {
            AppSettings.shared.llmConfig.backend = .cloudAPI
            updateBackendRadios()
            return
        }
        
        AppSettings.shared.llmConfig.backend = preset.backend
        AppSettings.shared.llmConfig.endpoint = preset.endpoint
        endpointField?.stringValue = preset.endpoint
        
        if !preset.defaultModel.isEmpty {
            AppSettings.shared.llmConfig.selectedModel = preset.defaultModel
            modelField?.stringValue = preset.defaultModel
            OverlayController.shared.updateModelBadge()
        }
        
        updateBackendRadios()
        updateModelDropdown(with: preset.recommendedModels)
    }
    
    @objc private func didSelectModelPopup(_ sender: NSPopUpButton) {
        if let sel = sender.titleOfSelectedItem, !sel.isEmpty {
            modelField?.stringValue = sel
            AppSettings.shared.llmConfig.selectedModel = sel
            OverlayController.shared.updateModelBadge()
        }
    }
    
    private func updateModelDropdown(with list: [String]) {
        guard let popup = modelPopup else { return }
        popup.removeAllItems()
        let currentModel = AppSettings.shared.llmConfig.selectedModel
        
        for m in list {
            popup.addItem(withTitle: m)
        }
        
        if list.contains(currentModel) {
            popup.selectItem(withTitle: currentModel)
        } else if let first = list.first {
            popup.selectItem(withTitle: first)
        }
    }
    
    public func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field == apiKeyField {
            AppSettings.shared.llmConfig.apiKey = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if field == endpointField {
            AppSettings.shared.llmConfig.endpoint = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if field == modelField {
            let m = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !m.isEmpty {
                AppSettings.shared.llmConfig.selectedModel = m
                OverlayController.shared.updateModelBadge()
            }
        }
    }
    
    private func syncFieldsToConfig() {
        if let key = apiKeyField?.stringValue {
            AppSettings.shared.llmConfig.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let ep = endpointField?.stringValue {
            AppSettings.shared.llmConfig.endpoint = ep.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let m = modelField?.stringValue, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppSettings.shared.llmConfig.selectedModel = m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    @objc private func refreshModels() {
        syncFieldsToConfig()
        testStatusLabel?.stringValue = "Fetching models..."
        testStatusLabel?.textColor = .labelColor
        
        Task {
            let models = await LLMClient.shared.fetchAvailableModels(config: AppSettings.shared.llmConfig)
            await MainActor.run {
                if !models.isEmpty {
                    AppSettings.shared.availableModels = models
                    self.updateModelDropdown(with: models)
                    self.testStatusLabel?.stringValue = "Fetched \(models.count) models"
                    self.testStatusLabel?.textColor = .systemGreen
                } else {
                    self.testStatusLabel?.stringValue = "Could not fetch models from endpoint"
                    self.testStatusLabel?.textColor = .systemOrange
                }
            }
        }
    }
    
    @objc private func didToggleVision() {
        AppSettings.shared.llmConfig.preferVision = (visionCheckbox?.state == .on)
    }
    
    @objc private func testConnection() {
        syncFieldsToConfig()
        testStatusLabel?.stringValue = "Testing..."
        testStatusLabel?.textColor = .labelColor
        let start = Date()
        
        let config = AppSettings.shared.llmConfig
        if config.backend == .cloudAPI && config.apiKey.isEmpty {
            testStatusLabel?.stringValue = "⚠️ Please enter an API key for Cloud API"
            testStatusLabel?.textColor = .systemOrange
            return
        }
        
        Task {
            do {
                let res = try await LLMClient.shared.solve(
                    image: nil,
                    ocrContext: "Test ping: 1 + 1 = ? 1) 1 2) 2 3) 3",
                    pointerCoordinates: nil,
                    config: config
                ) { _ in }
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                await MainActor.run {
                    self.testStatusLabel?.stringValue = "✅ Connected (\(ms)ms): Choice \(res.parsedChoice.map(String.init) ?? res.parsedLetter ?? "OK")"
                    self.testStatusLabel?.textColor = .systemGreen
                }
            } catch {
                await MainActor.run {
                    self.testStatusLabel?.stringValue = "❌ Error: \(error.localizedDescription)"
                    self.testStatusLabel?.textColor = .systemRed
                }
            }
        }
    }
    
    // MARK: - Tab 3: Permissions & Test
    private func createPermView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        
        let title = NSTextField(labelWithString: "Permissions & Screen Stealth")
        title.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        title.frame = NSRect(x: 20, y: frame.height - 46, width: 300, height: 22)
        view.addSubview(title)
        
        // Screen capture permission row
        let sCheck = CGPreflightScreenCaptureAccess()
        let sLbl = NSTextField(labelWithString: "Screen Recording: \(sCheck ? "✅ Granted" : "⚠️ Needs Permission or Restart")")
        sLbl.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sLbl.textColor = sCheck ? .systemGreen : .systemOrange
        sLbl.frame = NSRect(x: 20, y: frame.height - 84, width: 310, height: 20)
        view.addSubview(sLbl)
        self.screenPermLabel = sLbl
        
        let sBtn = NSButton(title: "Open Settings", target: self, action: #selector(openScreenSettings))
        sBtn.frame = NSRect(x: 340, y: frame.height - 86, width: 120, height: 24)
        view.addSubview(sBtn)
        
        // Accessibility permission row
        let aCheck = AXIsProcessTrusted()
        let aLbl = NSTextField(labelWithString: "Accessibility (Hotkeys): \(aCheck ? "✅ Granted" : "⚠️ Needs Permission")")
        aLbl.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        aLbl.textColor = aCheck ? .systemGreen : .systemOrange
        aLbl.frame = NSRect(x: 20, y: frame.height - 118, width: 310, height: 20)
        view.addSubview(aLbl)
        self.accessPermLabel = aLbl
        
        let aBtn = NSButton(title: "Open Settings", target: self, action: #selector(openAccessSettings))
        aBtn.frame = NSRect(x: 340, y: frame.height - 120, width: 120, height: 24)
        view.addSubview(aBtn)
        
        // Critical macOS Permission Note Banner
        let noteBox = NSBox(frame: NSRect(x: 20, y: frame.height - 210, width: frame.width - 40, height: 76))
        noteBox.title = "Important macOS Permission Rule"
        let noteText = NSTextField(wrappingLabelWithString: "When you toggle Screen Recording ON in System Settings, macOS requires quitting and reopening the app once for the permission to take effect. If you just enabled it in System Settings, click 'Restart NOX WHISHPER RED' below.")
        noteText.frame = NSRect(x: 10, y: 6, width: noteBox.bounds.width - 24, height: 46)
        noteText.font = NSFont.systemFont(ofSize: 11)
        noteText.textColor = .secondaryLabelColor
        noteBox.addSubview(noteText)
        view.addSubview(noteBox)
        
        // Stealth explanation
        let stealthBox = NSBox(frame: NSRect(x: 20, y: frame.height - 305, width: frame.width - 40, height: 82))
        stealthBox.title = "Screen Recording Stealth (NSWindow.sharingType = .none)"
        let stealthText = NSTextField(wrappingLabelWithString: "NOX WHISHPER RED's Remote HUD window is completely excluded from ScreenCaptureKit, Zoom, Google Meet, Microsoft Teams, and screen recorders. The HUD is visible to you on your physical monitor, but completely invisible in recordings.")
        stealthText.frame = NSRect(x: 10, y: 6, width: stealthBox.bounds.width - 24, height: 50)
        stealthText.font = NSFont.systemFont(ofSize: 11)
        stealthText.textColor = .secondaryLabelColor
        stealthBox.addSubview(stealthText)
        view.addSubview(stealthBox)
        
        // Actions row
        let restartBtn = NSButton(title: "🔄 Restart NOX WHISHPER RED", target: self, action: #selector(restartApp))
        restartBtn.frame = NSRect(x: 20, y: 30, width: 180, height: 32)
        restartBtn.bezelStyle = .rounded
        view.addSubview(restartBtn)
        
        let refreshBtn = NSButton(title: "Check Status", target: self, action: #selector(refreshPermissionsUI))
        refreshBtn.frame = NSRect(x: 210, y: 30, width: 120, height: 32)
        refreshBtn.bezelStyle = .rounded
        view.addSubview(refreshBtn)
        
        let testBtn = NSButton(title: "Test Solve Under Mouse", target: self, action: #selector(runSampleSolve))
        testBtn.frame = NSRect(x: 340, y: 30, width: 180, height: 32)
        testBtn.bezelStyle = .rounded
        view.addSubview(testBtn)
        
        // Observe window becoming key to auto-refresh when user returns from System Settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPermissionsUI),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        
        return view
    }
    
    @objc public func refreshPermissionsUI() {
        let sCheck = CGPreflightScreenCaptureAccess()
        let aCheck = AXIsProcessTrusted()
        
        screenPermLabel?.stringValue = "Screen Recording: \(sCheck ? "✅ Granted" : "⚠️ Needs Permission or Restart")"
        screenPermLabel?.textColor = sCheck ? .systemGreen : .systemOrange
        
        accessPermLabel?.stringValue = "Accessibility (Hotkeys): \(aCheck ? "✅ Granted" : "⚠️ Needs Permission")"
        accessPermLabel?.textColor = aCheck ? .systemGreen : .systemOrange
    }
    
    @objc private func openScreenSettings() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openAccessSettings() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc public func restartApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", "/Applications/NOX WHISHPER RED.app"]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
    
    @objc private func runSampleSolve() {
        SolverCoordinator.shared.triggerSolve()
    }
    
    // MARK: - Tab 2: Menu Bar Disguise Icon
    private func createIconDisguiseView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        
        let title = NSTextField(labelWithString: "Stealth Menu Bar Icon Disguise")
        title.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        title.frame = NSRect(x: 20, y: frame.height - 46, width: 360, height: 22)
        view.addSubview(title)
        
        let subtitle = NSTextField(wrappingLabelWithString: "Choose a real macOS system icon so NOX WHISHPER RED appears as an ordinary system utility (like Settings, Wi-Fi, or Battery) in your top menu bar during exams, presentations, or proctoring.")
        subtitle.frame = NSRect(x: 20, y: frame.height - 86, width: frame.width - 40, height: 36)
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        view.addSubview(subtitle)
        
        // Two columns of radio buttons for icons
        disguiseRadioButtons.removeAll()
        let cases = MenuBarDisguise.allCases
        let colWidth: CGFloat = 280
        let rowHeight: CGFloat = 34
        let startY = frame.height - 128
        
        for (idx, disguise) in cases.enumerated() {
            let col = idx % 2
            let row = idx / 2
            let xPos: CGFloat = 20 + CGFloat(col) * colWidth
            let currentY = startY - CGFloat(row) * rowHeight
            
            // Icon image preview next to radio button
            let iv = NSImageView(frame: NSRect(x: xPos, y: currentY + 1, width: 20, height: 20))
            if let img = NSImage(systemSymbolName: disguise.systemSymbolName, accessibilityDescription: nil) {
                img.isTemplate = true
                iv.image = img
            }
            view.addSubview(iv)
            
            // Radio button
            let btn = NSButton(radioButtonWithTitle: disguise.displayName, target: self, action: #selector(didSelectDisguiseRadio(_:)))
            btn.frame = NSRect(x: xPos + 26, y: currentY, width: colWidth - 30, height: 22)
            btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            btn.state = (AppSettings.shared.menuBarDisguise == disguise) ? .on : .off
            view.addSubview(btn)
            disguiseRadioButtons.append(btn)
        }
        
        // Live Preview Box at bottom
        let previewBox = NSBox(frame: NSRect(x: 20, y: 24, width: frame.width - 40, height: 78))
        previewBox.title = "Live Menu Bar Preview"
        
        let previewContainer = NSView(frame: NSRect(x: 10, y: 8, width: previewBox.bounds.width - 24, height: 44))
        
        let mockLabel = NSTextField(labelWithString: "Active in your menu bar:")
        mockLabel.frame = NSRect(x: 10, y: 13, width: 160, height: 18)
        mockLabel.font = NSFont.systemFont(ofSize: 12)
        mockLabel.textColor = .secondaryLabelColor
        previewContainer.addSubview(mockLabel)
        
        let prevIV = NSImageView(frame: NSRect(x: 175, y: 11, width: 22, height: 22))
        let cur = AppSettings.shared.menuBarDisguise
        if let img = NSImage(systemSymbolName: cur.systemSymbolName, accessibilityDescription: nil) {
            img.isTemplate = true
            prevIV.image = img
        }
        previewContainer.addSubview(prevIV)
        self.disguisePreviewImageView = prevIV
        
        let prevTitle = NSTextField(labelWithString: "\(cur.displayName) - Live in Menu Bar")
        prevTitle.frame = NSRect(x: 205, y: 13, width: 340, height: 18)
        prevTitle.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        previewContainer.addSubview(prevTitle)
        self.disguisePreviewTitle = prevTitle
        
        previewBox.addSubview(previewContainer)
        view.addSubview(previewBox)
        
        return view
    }
    
    @objc private func didSelectDisguiseRadio(_ sender: NSButton) {
        guard let idx = disguiseRadioButtons.firstIndex(of: sender), idx < MenuBarDisguise.allCases.count else { return }
        let selected = MenuBarDisguise.allCases[idx]
        AppSettings.shared.menuBarDisguise = selected
        
        for (i, btn) in disguiseRadioButtons.enumerated() {
            btn.state = (i == idx) ? .on : .off
        }
        
        // Update status item icon immediately
        MenuBarManager.shared.updateIcon()
        MenuBarManager.shared.rebuildMenu()
        
        // Update live preview in settings window
        if let img = NSImage(systemSymbolName: selected.systemSymbolName, accessibilityDescription: nil) {
            img.isTemplate = true
            disguisePreviewImageView?.image = img
        }
        disguisePreviewTitle?.stringValue = "\(selected.displayName) - Live in Menu Bar"
    }
}
