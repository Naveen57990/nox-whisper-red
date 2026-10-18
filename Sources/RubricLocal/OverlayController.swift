import Foundation
import Cocoa

public final class OverlayController: NSObject {
    public static let shared = OverlayController()
    
    private var panel: NSPanel?
    private var statusDot: NSBox?
    private var statusLabel: NSTextField?
    private var modelBadge: NSTextField?
    private var latencyLabel: NSTextField?
    private var answerBadge: NSTextField?
    private var answerTextView: NSTextView?
    private var scrollView: NSScrollView?
    
    private override init() {
        super.init()
        setupPanel()
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 420, height: 320),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating // Floats on top
        p.isMovableByWindowBackground = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // CRITICAL: Excluded from all screen capture, recordings, Zoom, Teams, screenshots!
        p.sharingType = .none
        
        // Background Frosted Glass Blur
        let visualEffect = NSVisualEffectView(frame: p.contentView?.bounds ?? .zero)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor(srgbRed: 0.9, green: 0.15, blue: 0.22, alpha: 0.35).cgColor
        
        let container = NSView(frame: visualEffect.bounds)
        container.autoresizingMask = [.width, .height]
        
        // --- 1. Header Bar ---
        let headerView = NSView(frame: NSRect(x: 0, y: container.bounds.height - 42, width: container.bounds.width, height: 42))
        headerView.autoresizingMask = [.width, .minYMargin]
        
        // Status indicator dot (Crimson Red)
        let dot = NSBox(frame: NSRect(x: 14, y: 16, width: 10, height: 10))
        dot.boxType = .custom
        dot.borderWidth = 0
        dot.fillColor = NSColor(srgbRed: 0.95, green: 0.15, blue: 0.22, alpha: 1.0)
        dot.cornerRadius = 5
        headerView.addSubview(dot)
        self.statusDot = dot
        
        // Title: NOX WHISHPER RED
        let titleLbl = NSTextField(labelWithString: "NOX WHISHPER RED")
        titleLbl.frame = NSRect(x: 30, y: 12, width: 175, height: 18)
        titleLbl.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
        titleLbl.textColor = NSColor(srgbRed: 1.0, green: 0.28, blue: 0.34, alpha: 1.0)
        headerView.addSubview(titleLbl)
        self.statusLabel = titleLbl
        
        // Model badge
        let badge = NSTextField(labelWithString: AppSettings.shared.llmConfig.selectedModel)
        badge.frame = NSRect(x: 210, y: 13, width: 110, height: 16)
        badge.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        badge.textColor = NSColor.white.withAlphaComponent(0.7)
        headerView.addSubview(badge)
        self.modelBadge = badge
        
        // Latency
        let lat = NSTextField(labelWithString: "")
        lat.frame = NSRect(x: container.bounds.width - 110, y: 13, width: 60, height: 16)
        lat.alignment = .right
        lat.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        lat.textColor = NSColor.white.withAlphaComponent(0.5)
        lat.autoresizingMask = [.minXMargin]
        headerView.addSubview(lat)
        self.latencyLabel = lat
        
        // Close button
        let closeBtn = NSButton(frame: NSRect(x: container.bounds.width - 34, y: 10, width: 22, height: 22))
        closeBtn.title = "×"
        closeBtn.bezelStyle = .circular
        closeBtn.isBordered = false
        closeBtn.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        closeBtn.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        closeBtn.target = self
        closeBtn.action = #selector(hide)
        closeBtn.autoresizingMask = [.minXMargin]
        headerView.addSubview(closeBtn)
        
        container.addSubview(headerView)
        
        // --- 2. Prominent Answer Banner ---
        let banner = NSTextField(labelWithString: "")
        banner.frame = NSRect(x: 14, y: container.bounds.height - 84, width: container.bounds.width - 28, height: 34)
        banner.autoresizingMask = [.width, .minYMargin]
        banner.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        banner.textColor = NSColor(srgbRed: 1.0, green: 0.35, blue: 0.4, alpha: 1.0)
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor(srgbRed: 0.85, green: 0.1, blue: 0.16, alpha: 0.22).cgColor
        banner.layer?.cornerRadius = 8
        banner.layer?.borderWidth = 1
        banner.layer?.borderColor = NSColor(srgbRed: 1.0, green: 0.25, blue: 0.3, alpha: 0.45).cgColor
        banner.alignment = .center
        banner.isHidden = true
        container.addSubview(banner)
        self.answerBadge = banner
        
        // --- 3. Scrollable Answer Text ---
        let scroll = NSScrollView(frame: NSRect(x: 14, y: 46, width: container.bounds.width - 28, height: container.bounds.height - 96))
        scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        
        let tv = NSTextView(frame: scroll.bounds)
        tv.autoresizingMask = [.width]
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textColor = NSColor.white.withAlphaComponent(0.95)
        tv.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        tv.string = "Hover cursor over a question and press \(AppSettings.shared.triggerShortcutText) to solve."
        scroll.documentView = tv
        
        container.addSubview(scroll)
        self.scrollView = scroll
        self.answerTextView = tv
        
        // --- 4. Bottom Footer Bar ---
        let footerView = NSView(frame: NSRect(x: 0, y: 0, width: container.bounds.width, height: 40))
        footerView.autoresizingMask = [.width, .maxYMargin]
        
        let copyBtn = NSButton(frame: NSRect(x: 14, y: 8, width: 90, height: 24))
        copyBtn.title = "Copy"
        copyBtn.bezelStyle = .rounded
        copyBtn.font = NSFont.systemFont(ofSize: 11)
        copyBtn.target = self
        copyBtn.action = #selector(copyAnswer)
        footerView.addSubview(copyBtn)
        
        let clearBtn = NSButton(frame: NSRect(x: 110, y: 8, width: 80, height: 24))
        clearBtn.title = "Clear"
        clearBtn.bezelStyle = .rounded
        clearBtn.font = NSFont.systemFont(ofSize: 11)
        clearBtn.target = self
        clearBtn.action = #selector(clearContent)
        footerView.addSubview(clearBtn)
        
        container.addSubview(footerView)
        
        visualEffect.addSubview(container)
        p.contentView = visualEffect
        self.panel = p
    }
    
    public func updateModelBadge() {
        modelBadge?.stringValue = AppSettings.shared.llmConfig.selectedModel
    }
    
    public func setSolvingState(isSolving: Bool, status: String = "Solving...") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isSolving {
                self.statusDot?.fillColor = NSColor.systemOrange
                self.statusLabel?.stringValue = "Solving..."
                self.answerBadge?.isHidden = true
                self.answerTextView?.string = "\(status)\n\nThinking with \(AppSettings.shared.llmConfig.selectedModel)..."
                self.latencyLabel?.stringValue = ""
            } else {
                self.statusDot?.fillColor = NSColor(srgbRed: 0.95, green: 0.15, blue: 0.22, alpha: 1.0)
                self.statusLabel?.stringValue = "NOX WHISHPER RED"
            }
        }
    }
    
    public func setStatusText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tv = self.answerTextView else { return }
            if tv.string.contains("Capturing") || tv.string.contains("Reading") || tv.string.contains("Thinking") || tv.string.contains("Solving") {
                tv.string = "\(text)\n\nWaiting for response from \(AppSettings.shared.llmConfig.selectedModel)..."
            }
        }
    }
    
    public func appendToken(_ token: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tv = self.answerTextView else { return }
            // If placeholder text is currently present, clear it on first token
            if tv.string.contains("Thinking with") || tv.string.contains("Waiting for response") || tv.string.starts(with: "Hover cursor") {
                tv.string = ""
            }
            tv.string += token
            tv.scrollToEndOfDocument(nil)
        }
    }
    
    public func setFinalResult(_ result: SolveResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setSolvingState(isSolving: false)
            self.answerTextView?.string = result.fullAnswer
            self.latencyLabel?.stringValue = "\(result.latencyMs)ms"
            
            if let choice = result.parsedChoice {
                let letterStr = result.parsedLetter.map { " (\($0))" } ?? ""
                self.answerBadge?.stringValue = "👉 ANSWER: OPTION \(choice)\(letterStr)"
                self.answerBadge?.isHidden = false
                
                // Adjust scroll view top margin
                if let container = self.scrollView?.superview {
                    self.scrollView?.frame = NSRect(
                        x: 14,
                        y: 46,
                        width: container.bounds.width - 28,
                        height: container.bounds.height - 140
                    )
                }
            } else {
                self.answerBadge?.isHidden = true
                if let container = self.scrollView?.superview {
                    self.scrollView?.frame = NSRect(
                        x: 14,
                        y: 46,
                        width: container.bounds.width - 28,
                        height: container.bounds.height - 96
                    )
                }
            }
        }
    }
    
    @objc public func showDefault() {
        show(near: nil)
    }
    
    public func show(near point: NSPoint? = nil) {
        guard let p = panel else { return }
        updateModelBadge()
        
        let mouseLoc = point ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
        
        var origin = NSPoint(x: mouseLoc.x + 25, y: mouseLoc.y - 120)
        if origin.x + p.frame.width > screen.frame.maxX - 20 {
            origin.x = max(screen.frame.minX + 20, mouseLoc.x - p.frame.width - 25)
        }
        if origin.x < screen.frame.minX + 20 {
            origin.x = screen.frame.minX + 20
        }
        if origin.y + p.frame.height > screen.frame.maxY - 40 {
            origin.y = screen.frame.maxY - p.frame.height - 40
        }
        if origin.y < screen.frame.minY + 20 {
            origin.y = screen.frame.minY + 20
        }
        
        p.setFrameOrigin(origin)
        p.level = .floating
        p.orderFrontRegardless()
    }
    
    @objc public func hide() {
        panel?.orderOut(nil)
    }
    
    public func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show(near: NSEvent.mouseLocation)
        }
    }
    
    @objc private func copyAnswer() {
        if let text = answerTextView?.string, !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @objc private func clearContent() {
        answerBadge?.isHidden = true
        answerTextView?.string = "Ready. Press \(AppSettings.shared.triggerShortcutText) on a question."
        latencyLabel?.stringValue = ""
    }
}
