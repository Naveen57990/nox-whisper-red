import Foundation
import Cocoa
import SwiftUI

public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    public override init() {
        super.init()
    }
    
    public func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item
        updateIcon()
        rebuildMenu()
    }
    
    public func updateIcon() {
        guard let button = statusItem?.button else { return }
        let disguise = AppSettings.shared.menuBarDisguise
        
        if disguise == .rubricHexagon {
            if let customPath = Bundle.main.path(forResource: "NoxMenuIcon", ofType: "png"),
               let customImg = NSImage(contentsOfFile: customPath) {
                customImg.size = NSSize(width: 18, height: 18)
                button.image = customImg
                button.imagePosition = .imageLeading
                return
            }
        }
        
        if let img = NSImage(systemSymbolName: disguise.systemSymbolName, accessibilityDescription: "NOX WHISHPER RED") {
            img.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeading
        }
    }
    
    public func setStatusSolving() {
        guard let button = statusItem?.button else { return }
        button.title = " [⏳...]"
    }
    
    public func setAnswerDisplay(choice: Int?, letter: String?) {
        guard let button = statusItem?.button else { return }
        
        if let choice = choice {
            if let letter = letter {
                button.title = " [\(choice):\(letter)]"
            } else {
                button.title = " [\(choice)]"
            }
        } else if let letter = letter {
            button.title = " [\(letter)]"
        }
        
        // Auto-revert to normal icon after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.statusItem?.button?.title = ""
        }
    }
    
    public func rebuildMenu() {
        let menu = NSMenu()
        
        // Current Mode header
        let modeItem = NSMenuItem(title: "Mode: \(AppSettings.shared.mode.displayName)", action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Mode Submenu
        let modesMenu = NSMenu()
        for mode in ExamMode.allCases {
            let mItem = NSMenuItem(title: mode.displayName, action: #selector(didSelectMode(_:)), keyEquivalent: "")
            mItem.target = self
            mItem.representedObject = mode
            mItem.state = (AppSettings.shared.mode == mode) ? .on : .off
            modesMenu.addItem(mItem)
        }
        let modeSubmenuItem = NSMenuItem(title: "Change Mode", action: nil, keyEquivalent: "")
        modeSubmenuItem.submenu = modesMenu
        menu.addItem(modeSubmenuItem)
        
        // Menu Bar Icon Disguise Submenu
        let disguiseMenu = NSMenu()
        for disguise in MenuBarDisguise.allCases {
            let dItem = NSMenuItem(title: disguise.displayName, action: #selector(didSelectDisguise(_:)), keyEquivalent: "")
            dItem.target = self
            dItem.representedObject = disguise
            if let img = NSImage(systemSymbolName: disguise.systemSymbolName, accessibilityDescription: nil) {
                img.isTemplate = true
                dItem.image = img
            }
            dItem.state = (AppSettings.shared.menuBarDisguise == disguise) ? .on : .off
            disguiseMenu.addItem(dItem)
        }
        let disguiseSubmenuItem = NSMenuItem(title: "Disguise Icon (\(AppSettings.shared.menuBarDisguise.displayName.components(separatedBy: " ").first ?? ""))", action: nil, keyEquivalent: "")
        disguiseSubmenuItem.submenu = disguiseMenu
        menu.addItem(disguiseSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Actions
        let solveItem = NSMenuItem(title: "Solve Under Cursor (\(AppSettings.shared.triggerShortcutText))", action: #selector(didTriggerSolve), keyEquivalent: "")
        solveItem.target = self
        menu.addItem(solveItem)
        
        let toggleHudItem = NSMenuItem(title: "Toggle Invisible HUD (\(AppSettings.shared.toggleHUDShortcutText))", action: #selector(didToggleHUD), keyEquivalent: "")
        toggleHudItem.target = self
        menu.addItem(toggleHudItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings & AI Engine / API...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let restartItem = NSMenuItem(title: "Restart NOX WHISHPER RED", action: #selector(didRestart), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit NOX WHISHPER RED", action: #selector(didQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func didRestart() {
        SettingsWindowController.shared.restartApp()
    }
    
    @objc private func didSelectMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? ExamMode {
            AppSettings.shared.mode = mode
            rebuildMenu()
        }
    }
    
    @objc private func didSelectDisguise(_ sender: NSMenuItem) {
        if let disguise = sender.representedObject as? MenuBarDisguise {
            AppSettings.shared.menuBarDisguise = disguise
            updateIcon()
            rebuildMenu()
        }
    }
    
    @objc private func didTriggerSolve() {
        // When clicked from menu, give user 1.2s to hover cursor over question
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            SolverCoordinator.shared.triggerSolve()
        }
    }
    
    @objc private func didToggleHUD() {
        OverlayController.shared.toggle()
    }
    
    @objc public func openSettings() {
        SettingsWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func didQuit() {
        NSApplication.shared.terminate(nil)
    }
}
