import Foundation

struct AgentPlanDecoder {
    func decodePlan(from content: String) throws -> AgentPlan {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), let plan = try? JSONDecoder().decode(AgentPlan.self, from: data) {
            return plan
        }
        if let json = extractJSONObject(from: trimmed), let data = json.data(using: .utf8) {
            return try JSONDecoder().decode(AgentPlan.self, from: data)
        }
        return AgentPlan(reply: content, action: nil, actions: nil)
    }

    func visibleStreamingText(from raw: String) -> String {
        if let reply = extractPartialReply(from: raw), !reply.isEmpty {
            return reply
        }
        if raw.contains("{") || raw.contains("\"actions\"") || raw.contains("\"action\"") {
            return "正在思考并规划动作…"
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else { return nil }
        return String(text[start...end])
    }

    private func extractPartialReply(from raw: String) -> String? {
        guard let replyRange = raw.range(of: "\"reply\"") ?? raw.range(of: "'reply'") else { return nil }
        let tail = raw[replyRange.upperBound...]
        guard let colon = tail.firstIndex(of: ":") else { return nil }
        var value = String(tail[tail.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\"") || value.hasPrefix("'") { value.removeFirst() }
        if let end = value.firstIndex(where: { $0 == "\"" || $0 == "'" }) { value = String(value[..<end]) }
        return value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
