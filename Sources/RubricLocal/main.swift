import Foundation
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (menu bar app, optional dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Menu Bar item
        MenuBarManager.shared.setup()
        
        // Start Global Keystroke Hotkey Monitor
        HotkeyManager.shared.start()
        
        // Pre-fetch models in background
        Task {
            let models = await LLMClient.shared.fetchAvailableModels(config: AppSettings.shared.llmConfig)
            await MainActor.run {
                if !models.isEmpty {
                    AppSettings.shared.availableModels = models
                }
                if AppSettings.shared.llmConfig.backend == .ollama {
                    if AppSettings.shared.llmConfig.selectedModel.isEmpty {
                        if models.contains("qwen2.5vl:3b") {
                            AppSettings.shared.llmConfig.selectedModel = "qwen2.5vl:3b"
                        } else if let first = models.first {
                            AppSettings.shared.llmConfig.selectedModel = first
                        }
                    }
                }
            }
        }
        
        print("NOX WHISHPER RED initialized successfully. Menu bar item is active.")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
