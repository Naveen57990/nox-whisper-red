import Foundation
import IOKit
import IOKit.hidsystem

public final class CapsLockController {
    public static let shared = CapsLockController()
    
    private var connect: io_connect_t = 0
    private var isBlinking = false
    
    private init() {
        openHIDSystem()
    }
    
    deinit {
        closeHIDSystem()
    }
    
    private func openHIDSystem() {
        let masterPort = kIOMainPortDefault
        let service = IOServiceGetMatchingService(masterPort, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        
        let kr = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        if kr != KERN_SUCCESS {
            connect = 0
        }
    }
    
    private func closeHIDSystem() {
        if connect != 0 {
            IOServiceClose(connect)
            connect = 0
        }
    }
    
    public func setCapsLock(state: Bool) {
        if connect == 0 {
            openHIDSystem()
        }
        guard connect != 0 else { return }
        _ = IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), state)
    }
    
    public func getCapsLock() -> Bool {
        if connect == 0 {
            openHIDSystem()
        }
        guard connect != 0 else { return false }
        var state = false
        _ = IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
        return state
    }
    
    public func blink(times: Int, onDuration: TimeInterval = 0.22, offDuration: TimeInterval = 0.22) {
        guard times > 0, !isBlinking else { return }
        isBlinking = true
        
        Task {
            let initialState = getCapsLock()
            
            for _ in 0..<times {
                setCapsLock(state: true)
                try? await Task.sleep(nanoseconds: UInt64(onDuration * 1_000_000_000))
                setCapsLock(state: false)
                try? await Task.sleep(nanoseconds: UInt64(offDuration * 1_000_000_000))
            }
            
            // Restore initial state
            setCapsLock(state: initialState)
            isBlinking = false
        }
    }
}
