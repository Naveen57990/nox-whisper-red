import Foundation
import Cocoa

public final class ScreenFlashController {
    public static let shared = ScreenFlashController()
    
    private var flashWindow: NSWindow?
    
    private init() {}
    
    private func setupWindowIfNeeded(screen: NSScreen) {
        if flashWindow == nil {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .screenSaver
            win.ignoresMouseEvents = true
            win.sharingType = .none // Excluded from screen capture!
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            let borderView = NSBox(frame: win.contentView?.bounds ?? .zero)
            borderView.autoresizingMask = [.width, .height]
            borderView.boxType = .custom
            borderView.borderWidth = 5
            borderView.borderColor = NSColor.systemBlue.withAlphaComponent(0.8)
            borderView.fillColor = NSColor.clear
            
            win.contentView?.addSubview(borderView)
            self.flashWindow = win
        }
    }
    
    public func flash(times: Int) {
        guard let screen = NSScreen.main else { return }
        setupWindowIfNeeded(screen: screen)
        guard let win = flashWindow else { return }
        
        Task { @MainActor in
            win.setFrame(screen.frame, display: true)
            for _ in 0..<times {
                win.alphaValue = 0.0
                win.orderFront(nil)
                
                // Fade in
                await NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    win.animator().alphaValue = 0.85
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                
                // Fade out
                await NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    win.animator().alphaValue = 0.0
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            win.orderOut(nil)
        }
    }
}
