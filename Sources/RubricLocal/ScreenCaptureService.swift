import Foundation
import Cocoa
import ScreenCaptureKit

public struct ScreenCaptureResult {
    public let image: NSImage
    public let imageData: Data
    public let mousePercent: (xPct: Double, yPct: Double)
    public let screenFrame: NSRect
    public let mouseLocation: NSPoint
}

public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private init() {}
    
    public func captureDisplayAtCursor() async throws -> ScreenCaptureResult {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        
        // Find which screen contains the cursor
        let targetScreen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? screens[0]
        let screenIndex = screens.firstIndex(of: targetScreen) ?? 0
        
        let relX = mouseLoc.x - targetScreen.frame.origin.x
        let relY = targetScreen.frame.size.height - (mouseLoc.y - targetScreen.frame.origin.y)
        
        let xPct = max(0.0, min(100.0, (relX / targetScreen.frame.size.width) * 100.0))
        let yPct = max(0.0, min(100.0, (relY / targetScreen.frame.size.height) * 100.0))
        
        // Check permission and request if needed
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        
        // 1. Try ScreenCaptureKit (Fastest, in-memory, modern macOS 14+)
        do {
            let content = try await SCShareableContent.current
            let targetDisplay = content.displays.first(where: { disp in
                // Match display frame or index
                return abs(CGFloat(disp.width) - targetScreen.frame.width) < 10 &&
                       abs(CGFloat(disp.height) - targetScreen.frame.height) < 10
            }) ?? content.displays.first
            
            if let disp = targetDisplay {
                let filter = SCContentFilter(display: disp, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = disp.width
                config.height = disp.height
                config.showsCursor = false
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let rep = NSBitmapImageRep(cgImage: cgImage)
                let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) ?? Data()
                let nsImage = NSImage(cgImage: cgImage, size: targetScreen.frame.size)
                
                return ScreenCaptureResult(
                    image: nsImage,
                    imageData: data,
                    mousePercent: (xPct, yPct),
                    screenFrame: targetScreen.frame,
                    mouseLocation: mouseLoc
                )
            }
        } catch {
            // ScreenCaptureKit failed, proceed to screencapture fallback
        }
        
        // 2. Fallback to /usr/sbin/screencapture CLI
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("rubric_cap_\(UUID().uuidString).jpg")
        defer {
            try? FileManager.default.removeItem(at: tempUrl)
        }
        
        var displayArgs = ["-x", "-t", "jpg"]
        // -D1 for main display, -D2 for secondary
        displayArgs.append("-D\(screenIndex + 1)")
        displayArgs.append(tempUrl.path)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = displayArgs
        try task.run()
        task.waitUntilExit()
        
        if FileManager.default.fileExists(atPath: tempUrl.path),
           let data = try? Data(contentsOf: tempUrl),
           let nsImage = NSImage(data: data) {
            return ScreenCaptureResult(
                image: nsImage,
                imageData: data,
                mousePercent: (xPct, yPct),
                screenFrame: targetScreen.frame,
                mouseLocation: mouseLoc
            )
        }
        
        throw NSError(
            domain: "ScreenCaptureService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Screen Recording permission is required.\n\nIf you already turned it ON in System Settings -> Privacy & Security -> Screen Recording, please QUIT and REOPEN NOX WHISHPER RED once for macOS to apply the permission."]
        )
    }
}
