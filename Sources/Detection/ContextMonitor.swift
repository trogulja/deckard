import Foundation

/// Reads Claude Code session JSONL files to calculate context usage.
class ContextMonitor {
    static let shared = ContextMonitor()

    private let contextLimits: [String: Int] = [
        "claude-opus-4-6": 1_000_000,
        "claude-sonnet-4-6": 200_000,
        "claude-haiku-4-5": 200_000,
        "claude-haiku-4-5-20251001": 200_000,
    ]
    private let defaultLimit = 200_000

    struct ContextUsage {
        let model: String
        let inputTokens: Int
        let cacheReadTokens: Int
        let contextLimit: Int

        var contextUsed: Int { inputTokens + cacheReadTokens }
        var percentage: Double {
            guard contextLimit > 0 else { return 0 }
            return Double(contextUsed) / Double(contextLimit) * 100
        }

        var displayString: String {
            let usedK = contextUsed / 1000
            let limitK = contextLimit / 1000
            return "\(usedK)k/\(limitK)k (\(Int(percentage))%)"
        }
    }

    /// Get context usage for a session by reading its JSONL file.
    func getUsage(sessionId: String, projectPath: String) -> ContextUsage? {
        let encoded = projectPath.replacingOccurrences(of: "/", with: "-")
        let jsonlPath = NSHomeDirectory() + "/.claude/projects/\(encoded)/\(sessionId).jsonl"

        guard FileManager.default.fileExists(atPath: jsonlPath) else { return nil }

        var lastInput = 0
        var lastCacheRead = 0
        var model = ""

        // Read from the end of the file for efficiency (last usage entry)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonlPath)) else { return nil }
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        // Parse lines from the end to find the last usage
        let lines = content.components(separatedBy: "\n")
        for line in lines.reversed() {
            guard !line.isEmpty else { continue }
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            // Check message.usage (top-level assistant messages)
            if let msg = json["message"] as? [String: Any], let usage = msg["usage"] as? [String: Any] {
                lastInput = usage["input_tokens"] as? Int ?? 0
                lastCacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                model = msg["model"] as? String ?? model
                break
            }

            // Check nested message.message.usage (progress messages)
            if let msg = json["message"] as? [String: Any],
               let inner = msg["message"] as? [String: Any],
               let usage = inner["usage"] as? [String: Any] {
                lastInput = usage["input_tokens"] as? Int ?? 0
                lastCacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                model = inner["model"] as? String ?? model
                break
            }
        }

        guard !model.isEmpty || lastInput > 0 || lastCacheRead > 0 else { return nil }

        let limit = contextLimits[model] ?? defaultLimit

        return ContextUsage(
            model: model,
            inputTokens: lastInput,
            cacheReadTokens: lastCacheRead,
            contextLimit: limit
        )
    }
}
