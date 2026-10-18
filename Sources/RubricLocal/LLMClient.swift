import Foundation

public final class LLMClient {
    public static let shared = LLMClient()
    
    private init() {}
    
    // MARK: - Fetch Models (Ollama or Cloud API)
    public func fetchAvailableModels(config: LLMConfig = AppSettings.shared.llmConfig) async -> [String] {
        if config.backend == .cloudAPI || (!config.apiKey.isEmpty && !config.endpoint.contains(":11434")) {
            // OpenAI-compatible /models endpoint
            var endpoint = config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            if endpoint.hasSuffix("/chat/completions") {
                endpoint = String(endpoint.dropLast(17))
            }
            if !endpoint.hasSuffix("/v1") && !endpoint.hasSuffix("/models") {
                endpoint += "/v1"
            }
            guard let url = URL(string: "\(endpoint)/models") else { return [] }
            var request = URLRequest(url: url)
            if !config.apiKey.isEmpty {
                request.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            }
            request.timeoutInterval = 10
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
                struct ModelsResponse: Decodable {
                    struct Item: Decodable {
                        let id: String
                    }
                    let data: [Item]
                }
                let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
                return decoded.data.map { $0.id }.sorted()
            } catch {
                return []
            }
        } else {
            // Local Ollama /api/tags
            guard let url = URL(string: "\(config.endpoint)/api/tags") else { return [] }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
                struct TagResponse: Decodable {
                    struct ModelItem: Decodable {
                        let name: String
                    }
                    let models: [ModelItem]
                }
                let decoded = try JSONDecoder().decode(TagResponse.self, from: data)
                return decoded.models.map { $0.name }
            } catch {
                return []
            }
        }
    }
    
    // Backward-compatible overload
    public func fetchAvailableModels(endpoint: String) async -> [String] {
        var cfg = LLMConfig()
        cfg.endpoint = endpoint
        return await fetchAvailableModels(config: cfg)
    }
    
    // MARK: - Unified Solve Method
    public func solve(
        image: Data?,
        ocrContext: String,
        pointerCoordinates: (xPct: Double, yPct: Double)?,
        config: LLMConfig,
        onToken: @escaping (String) -> Void
    ) async throws -> SolveResult {
        let isCloud = config.backend == .cloudAPI || (!config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !config.endpoint.contains(":11434"))
        if isCloud {
            return try await solveWithCloudAPI(
                image: image,
                ocrContext: ocrContext,
                pointerCoordinates: pointerCoordinates,
                config: config,
                onToken: onToken
            )
        } else {
            return try await solveWithOllama(
                image: image,
                ocrContext: ocrContext,
                pointerCoordinates: pointerCoordinates,
                config: config,
                onToken: onToken
            )
        }
    }
    
    // MARK: - 1. Local Ollama Streaming
    private func solveWithOllama(
        image: Data?,
        ocrContext: String,
        pointerCoordinates: (xPct: Double, yPct: Double)?,
        config: LLMConfig,
        onToken: @escaping (String) -> Void
    ) async throws -> SolveResult {
        let startTime = Date()
        guard let url = URL(string: "\(config.endpoint)/api/generate") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        
        var promptText = """
You are an expert exam solver. Solve the question presented below.

Question and Options:
\"\"\"
\(ocrContext)
\"\"\"

CRITICAL INSTRUCTIONS:
1. On the very FIRST line, write the correct multiple-choice answer number and letter:
ANSWER: [Option Number] [Option Letter]
(Example: "ANSWER: 2 B" or "ANSWER: 3 C")
2. Follow with a concise, crystal-clear 1-2 sentence explanation.
"""
        if let coords = pointerCoordinates {
            promptText += "\n(Cursor focus was located near x=\(String(format: "%.1f", coords.xPct))%, y=\(String(format: "%.1f", coords.yPct))%)"
        }
        
        var payload: [String: Any] = [
            "model": config.selectedModel,
            "prompt": promptText,
            "stream": true,
            "options": [
                "temperature": config.temperature
            ]
        ]
        
        if config.preferVision, let imageData = image {
            let base64 = imageData.base64EncodedString()
            payload["images"] = [base64]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        var fullText = ""
        for try await line in bytes.lines {
            guard let lineData = line.data(using: .utf8) else { continue }
            if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
               let token = json["response"] as? String {
                fullText += token
                DispatchQueue.main.async {
                    onToken(token)
                }
            }
        }
        
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        let (choiceNum, choiceLetter) = parseMultipleChoiceAnswer(from: fullText)
        
        return SolveResult(
            questionText: ocrContext,
            fullAnswer: fullText,
            parsedChoice: choiceNum,
            parsedLetter: choiceLetter,
            latencyMs: duration
        )
    }
    
    // MARK: - 2. Cloud API (OpenAI / Groq / OpenRouter / DeepSeek)
    private func solveWithCloudAPI(
        image: Data?,
        ocrContext: String,
        pointerCoordinates: (xPct: Double, yPct: Double)?,
        config: LLMConfig,
        onToken: @escaping (String) -> Void
    ) async throws -> SolveResult {
        let startTime = Date()
        
        var endpoint = config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if endpoint.hasSuffix("/") {
            endpoint.removeLast()
        }
        if !endpoint.hasSuffix("/chat/completions") {
            if endpoint.hasSuffix("/v1") {
                endpoint += "/chat/completions"
            } else {
                endpoint += "/v1/chat/completions"
            }
        }
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 45
        
        var promptText = """
You are an expert exam solver. Solve the question presented below.

Question and Options:
\"\"\"
\(ocrContext)
\"\"\"

CRITICAL INSTRUCTIONS:
1. On the very FIRST line, write the correct multiple-choice answer number and letter:
ANSWER: [Option Number] [Option Letter]
(Example: "ANSWER: 2 B" or "ANSWER: 3 C")
2. Follow with a concise, crystal-clear 1-2 sentence explanation.
"""
        if let coords = pointerCoordinates {
            promptText += "\n(Cursor focus was located near x=\(String(format: "%.1f", coords.xPct))%, y=\(String(format: "%.1f", coords.yPct))%)"
        }
        
        var userContent: [[String: Any]] = [
            ["type": "text", "text": promptText]
        ]
        
        if config.preferVision, let imgData = image {
            let base64 = imgData.base64EncodedString()
            userContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64)"
                ]
            ])
        }
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": config.systemPrompt],
            ["role": "user", "content": userContent]
        ]
        
        let payload: [String: Any] = [
            "model": config.selectedModel,
            "messages": messages,
            "stream": true,
            "temperature": config.temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw NSError(
                domain: "CloudAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Cloud API Error (\(http.statusCode)): \(errorBody.isEmpty ? "Invalid API Key or Model Name" : errorBody)"]
            )
        }
        
        var fullText = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let jsonString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if jsonString == "[DONE]" { break }
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }
            
            fullText += content
            DispatchQueue.main.async {
                onToken(content)
            }
        }
        
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        let (choiceNum, choiceLetter) = parseMultipleChoiceAnswer(from: fullText)
        
        return SolveResult(
            questionText: ocrContext,
            fullAnswer: fullText,
            parsedChoice: choiceNum,
            parsedLetter: choiceLetter,
            latencyMs: duration
        )
    }
    
    // MARK: - Parse Answer Choice
    public func parseMultipleChoiceAnswer(from text: String) -> (choice: Int?, letter: String?) {
        let firstFewLines = text.components(separatedBy: .newlines).prefix(3).joined(separator: " ")
        
        let patterns = [
            #"(?i)answer\s*[:=\-]?\s*\[?\(?([1-5])\)?\]?\s*\(?([A-E])\)?"#,
            #"(?i)answer\s*[:=\-]?\s*\[?\(?([A-E])\)?\]?\s*\(?([1-5])\)?"#,
            #"(?i)answer\s*[:=\-]?\s*\[?\(?([1-5])\)?\]?"#,
            #"(?i)answer\s*[:=\-]?\s*\[?\(?([A-E])\)?\]?"#,
            #"(?i)option\s*[:=\-]?\s*\[?\(?([1-5])\)?\]?"#,
            #"(?i)option\s*[:=\-]?\s*\[?\(?([A-E])\)?\]?"#,
            #"(?i)choice\s*[:=\-]?\s*\[?\(?([1-5])\)?\]?"#,
            #"(?i)choice\s*[:=\-]?\s*\[?\(?([A-E])\)?\]?"#
        ]
        
        let letterMap = ["1": "A", "2": "B", "3": "C", "4": "D", "5": "E"]
        let numMap = ["A": 1, "B": 2, "C": 3, "D": 4, "E": 5]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: firstFewLines, options: [], range: NSRange(location: 0, length: firstFewLines.utf16.count)) {
                if match.numberOfRanges >= 2, let range1 = Range(match.range(at: 1), in: firstFewLines) {
                    let firstCapture = String(firstFewLines[range1]).uppercased()
                    
                    if match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound,
                       let range2 = Range(match.range(at: 2), in: firstFewLines) {
                        let secondCapture = String(firstFewLines[range2]).uppercased()
                        if let n = Int(firstCapture) {
                            return (n, secondCapture)
                        } else if let n = Int(secondCapture) {
                            return (n, firstCapture)
                        }
                    }
                    
                    if let n = Int(firstCapture), n >= 1 && n <= 5 {
                        return (n, letterMap[firstCapture])
                    } else if let n = numMap[firstCapture] {
                        return (n, firstCapture)
                    }
                }
            }
        }
        
        // Fallback: look for [1], (2), etc.
        if let regex = try? NSRegularExpression(pattern: #"[\[\(]([1-5])[\]\)]"#),
           let match = regex.firstMatch(in: firstFewLines, options: [], range: NSRange(location: 0, length: firstFewLines.utf16.count)),
           let r = Range(match.range(at: 1), in: firstFewLines),
           let n = Int(firstFewLines[r]) {
            return (n, letterMap[String(n)])
        }
        
        return (nil, nil)
    }
}
