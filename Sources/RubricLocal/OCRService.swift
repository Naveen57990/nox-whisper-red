import Foundation
import Vision
import Cocoa

public struct OCRBlock {
    public let text: String
    public let boundingBox: CGRect // normalized [0,1], Vision coordinates (origin bottom-left)
    public let distanceToCursor: CGFloat
}

public final class OCRService {
    public static let shared = OCRService()
    
    private init() {}
    
    public func recognizeText(from image: NSImage, cursorPercent: (xPct: Double, yPct: Double)) async throws -> (anchorText: String, focusedContext: String) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ("", "")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", ""))
                    return
                }
                
                // Cursor in Vision normalized coords:
                // Vision X is [0, 1] left-to-right
                // Vision Y is [0, 1] bottom-to-top
                let cursorVisionX = CGFloat(cursorPercent.xPct / 100.0)
                let cursorVisionY = CGFloat(1.0 - (cursorPercent.yPct / 100.0))
                let cursorPoint = CGPoint(x: cursorVisionX, y: cursorVisionY)
                
                var blocks: [OCRBlock] = []
                
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    let midX = box.midX
                    let midY = box.midY
                    let dist = hypot(midX - cursorPoint.x, midY - cursorPoint.y)
                    blocks.append(OCRBlock(text: candidate.string, boundingBox: box, distanceToCursor: dist))
                }
                
                // Find block closest to cursor as anchor
                let closest = blocks.min(by: { $0.distanceToCursor < $1.distanceToCursor })
                let anchorText = closest?.text ?? ""
                
                // Filter blocks near cursor vertically:
                // Typically questions start slightly above or at cursor, and options continue downwards.
                // In Vision coords (larger Y is higher up):
                // Look from (cursor - 0.25) to (cursor + 0.15)
                let nearbyBlocks = blocks.filter { block in
                    let yDiff = block.boundingBox.midY - cursorPoint.y
                    return yDiff > -0.35 && yDiff < 0.20
                }
                
                let selectedBlocks = nearbyBlocks.count >= 2 ? nearbyBlocks : blocks
                
                // Sort blocks top-to-bottom, left-to-right
                let sortedByPosition = selectedBlocks.sorted { b1, b2 in
                    if abs(b1.boundingBox.midY - b2.boundingBox.midY) > 0.025 {
                        return b1.boundingBox.midY > b2.boundingBox.midY
                    }
                    return b1.boundingBox.minX < b2.boundingBox.minX
                }
                
                let focusedContext = sortedByPosition.map { $0.text }.joined(separator: "\n")
                continuation.resume(returning: (anchorText, focusedContext))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
