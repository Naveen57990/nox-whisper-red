import Foundation
import Cocoa

public final class SolverCoordinator {
    public static let shared = SolverCoordinator()
    
    private init() {}
    
    public func triggerSolve() {
        guard !AppSettings.shared.isSolving else {
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let mode = AppSettings.shared.mode
        
        AppSettings.shared.isSolving = true
        AppSettings.shared.latestResult = SolveResult(questionText: "", fullAnswer: "")
        
        // In remote mode, immediately show the overlay HUD near the cursor
        if mode == .remote {
            OverlayController.shared.show(near: mouseLocation)
            OverlayController.shared.setSolvingState(isSolving: true, status: "Capturing question at cursor...")
        } else if mode == .cbt {
            MenuBarManager.shared.setStatusSolving()
        }
        
        Task {
            do {
                // 1. Capture screen at cursor
                let capture = try await ScreenCaptureService.shared.captureDisplayAtCursor()
                
                await MainActor.run {
                    if mode == .remote {
                        OverlayController.shared.setStatusText("Reading question with OCR...")
                    }
                }
                
                // 2. Perform Apple Vision OCR
                let (anchor, context) = try await OCRService.shared.recognizeText(
                    from: capture.image,
                    cursorPercent: capture.mousePercent
                )
                
                await MainActor.run {
                    if mode == .remote {
                        OverlayController.shared.setStatusText("Thinking with \(AppSettings.shared.llmConfig.selectedModel)...")
                    }
                }
                
                // 3. Send to Local LLM (Ollama)
                let result = try await LLMClient.shared.solve(
                    image: capture.imageData,
                    ocrContext: context.isEmpty ? anchor : context,
                    pointerCoordinates: capture.mousePercent,
                    config: AppSettings.shared.llmConfig
                ) { token in
                    if mode == .remote {
                        OverlayController.shared.appendToken(token)
                    }
                }
                
                await MainActor.run {
                    AppSettings.shared.latestResult = result
                    AppSettings.shared.isSolving = false
                    
                    if mode == .remote {
                        OverlayController.shared.setFinalResult(result)
                    }
                    
                    // Dispatch to selected feedback mode
                    if let choice = result.parsedChoice {
                        switch mode {
                        case .remote:
                            break // Already displayed in overlay HUD
                        case .cbt:
                            MenuBarManager.shared.setAnswerDisplay(choice: choice, letter: result.parsedLetter)
                        case .capsLock:
                            CapsLockController.shared.blink(times: choice)
                        case .flash:
                            ScreenFlashController.shared.flash(times: choice)
                        }
                    } else if mode == .cbt {
                        MenuBarManager.shared.setAnswerDisplay(choice: nil, letter: "?")
                    }
                }
            } catch {
                await MainActor.run {
                    let isCloud = AppSettings.shared.llmConfig.backend == .cloudAPI
                    let advice = isCloud ?
                        "Please verify your API key, internet connection, and endpoint at \(AppSettings.shared.llmConfig.endpoint) with model '\(AppSettings.shared.llmConfig.selectedModel)'." :
                        "Please ensure Ollama is running at \(AppSettings.shared.llmConfig.endpoint) with model '\(AppSettings.shared.llmConfig.selectedModel)'."
                    let errResult = SolveResult(
                        questionText: "Error",
                        fullAnswer: "Failed to solve: \(error.localizedDescription)\n\n\(advice)"
                    )
                    AppSettings.shared.latestResult = errResult
                    if mode == .remote {
                        OverlayController.shared.setFinalResult(errResult)
                    } else if mode == .cbt {
                        MenuBarManager.shared.setAnswerDisplay(choice: nil, letter: "ERR")
                    }
                }
            }
        }
    }
}
