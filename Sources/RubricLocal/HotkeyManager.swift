import Foundation
import Cocoa
import Carbon

public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    // Carbon Event HotKeys
    private var solveChordSpaceRef: EventHotKeyRef?
    private var solveChordReturnRef: EventHotKeyRef?
    private var solveOptCmdSpaceRef: EventHotKeyRef?
    private var solveOptCmdReturnRef: EventHotKeyRef?
    private var toggleHUDRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    // Event Monitors for Modifier Chord (Option + Command + Control)
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    
    private var isModifierChordActive: Bool = false
    private var lastTriggerTime: Date = Date.distantPast
    
    private init() {}
    
    public func start() {
        // 1. Request Accessibility if not already trusted (needed for global modifier monitor)
        checkAccessibility()
        
        // 2. Register Carbon Global Hotkeys on GetEventDispatcherTarget() (system-wide, no Accessibility needed)
        registerCarbonHotkeys()
        
        // 3. Register Global Flags Monitor for pure Option + Command + Control chord
        setupFlagsChangedMonitors()
        
        // 4. Local Escape monitor to dismiss overlay
        setupLocalKeyMonitor()
        
        print("[HotkeyManager] Global hotkeys and modifier monitor started successfully.")
    }
    
    public func stop() {
        if let ref = solveChordSpaceRef { UnregisterEventHotKey(ref); solveChordSpaceRef = nil }
        if let ref = solveChordReturnRef { UnregisterEventHotKey(ref); solveChordReturnRef = nil }
        if let ref = solveOptCmdSpaceRef { UnregisterEventHotKey(ref); solveOptCmdSpaceRef = nil }
        if let ref = solveOptCmdReturnRef { UnregisterEventHotKey(ref); solveOptCmdReturnRef = nil }
        if let ref = toggleHUDRef { UnregisterEventHotKey(ref); toggleHUDRef = nil }
        
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        if let g = globalFlagsMonitor {
            NSEvent.removeMonitor(g)
            globalFlagsMonitor = nil
        }
        if let l = localFlagsMonitor {
            NSEvent.removeMonitor(l)
            localFlagsMonitor = nil
        }
        if let k = localKeyMonitor {
            NSEvent.removeMonitor(k)
            localKeyMonitor = nil
        }
    }
    
    private func checkAccessibility() {
        if !AXIsProcessTrusted() {
            print("[HotkeyManager] Accessibility permission not yet granted. Prompting system dialog...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            print("[HotkeyManager] Accessibility permission is verified.")
        }
    }
    
    // MARK: - 1. Pure Modifier Chord (Option + Command + Control)
    private func setupFlagsChangedMonitors() {
        let handleFlags: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Check if Option + Command + Control are ALL pressed
            let hasOpt = flags.contains(.option)
            let hasCmd = flags.contains(.command)
            let hasCtrl = flags.contains(.control)
            
            if hasOpt && hasCmd && hasCtrl {
                let now = Date()
                if !self.isModifierChordActive && now.timeIntervalSince(self.lastTriggerTime) > 0.6 {
                    self.isModifierChordActive = true
                    self.lastTriggerTime = now
                    print("[HotkeyManager] Option + Command + Control modifier chord triggered!")
                    DispatchQueue.main.async {
                        SolverCoordinator.shared.triggerSolve()
                    }
                }
            } else {
                // When any modifier is released, allow next trigger
                self.isModifierChordActive = false
            }
        }
        
        // Listen globally across all apps
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlags)
        
        // Listen locally if app is active
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlags(event)
            return event
        }
    }
    
    // MARK: - 2. Local Key Monitor (Escape to dismiss)
    private func setupLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    OverlayController.shared.hide()
                }
                return nil
            }
            return event
        }
    }
    
    // MARK: - 3. Carbon Global Hotkeys (Dispatch to entire macOS desktop)
    private func registerCarbonHotkeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerBlock: EventHandlerUPP = { (handler, event, userData) -> OSStatus in
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            
            if status == noErr {
                print("[HotkeyManager] Carbon hotkey event received: id=\(hkID.id)")
                if hkID.id == 1 || hkID.id == 2 || hkID.id == 4 || hkID.id == 5 {
                    // Option + Command + Control (+ Space / Return) -> Solve
                    DispatchQueue.main.async {
                        SolverCoordinator.shared.triggerSolve()
                    }
                } else if hkID.id == 3 {
                    // Option + Command + H -> Toggle HUD
                    DispatchQueue.main.async {
                        OverlayController.shared.toggle()
                    }
                }
            }
            return noErr
        }
        
        // CRITICAL: Install handler on GetEventDispatcherTarget() for system-wide dispatch
        let dispatcher = GetEventDispatcherTarget()
        let err = InstallEventHandler(
            dispatcher,
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        if err != noErr {
            print("[HotkeyManager] Error installing Carbon event handler: \(err)")
        }
        
        let optCmdCtrl = UInt32(cmdKey | optionKey | controlKey)
        let optCmd = UInt32(cmdKey | optionKey)
        
        // Hotkey 1: Option + Command + Control + Space (keyCode: 49)
        let id1 = EventHotKeyID(signature: 0x52554252, id: 1)
        _ = RegisterEventHotKey(UInt32(49), optCmdCtrl, id1, dispatcher, 0, &solveChordSpaceRef)
        
        // Hotkey 2: Option + Command + Control + Return (keyCode: 36)
        let id2 = EventHotKeyID(signature: 0x52554252, id: 2)
        _ = RegisterEventHotKey(UInt32(36), optCmdCtrl, id2, dispatcher, 0, &solveChordReturnRef)
        
        // Hotkey 3: Option + Command + H (toggle HUD, keyCode: 4)
        let id3 = EventHotKeyID(signature: 0x52554252, id: 3)
        _ = RegisterEventHotKey(UInt32(4), optCmd, id3, dispatcher, 0, &toggleHUDRef)
        
        // Hotkey 4: Option + Command + Space (keyCode: 49)
        let id4 = EventHotKeyID(signature: 0x52554252, id: 4)
        _ = RegisterEventHotKey(UInt32(49), optCmd, id4, dispatcher, 0, &solveOptCmdSpaceRef)
        
        // Hotkey 5: Option + Command + Return (keyCode: 36)
        let id5 = EventHotKeyID(signature: 0x52554252, id: 5)
        _ = RegisterEventHotKey(UInt32(36), optCmd, id5, dispatcher, 0, &solveOptCmdReturnRef)
    }
}
