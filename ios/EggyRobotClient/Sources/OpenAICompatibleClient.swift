import Foundation

final class OpenAICompatibleClient {
    enum ClientError: LocalizedError {
        case invalidURL
        case missingAPIKey
        case missingModel
        case emptyResponse
        case badStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "API Base URL 无效"
            case .missingAPIKey: return "请先填写 API Key"
            case .missingModel: return "请先选择或填写模型"
            case .emptyResponse: return "模型没有返回内容"
            case .badStatus(let code, let body): return "API 请求失败 HTTP \(code)：\(body.prefix(160))"
            }
        }
    }

    func fetchModels(config: AgentConfig) async throws -> [String] {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClientError.missingAPIKey }
        guard let url = URL(string: config.normalizedBaseURL + "/models") else { throw ClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }

    func complete(config: AgentConfig, messages: [OpenAIChatRequest.Message]) async throws -> String {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClientError.missingAPIKey }
        guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClientError.missingModel }
        guard let url = URL(string: config.normalizedBaseURL + "/chat/completions") else { throw ClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = OpenAIChatRequest(model: config.model, messages: messages, temperature: config.temperature, responseFormat: .init(type: "json_object"))
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else { throw ClientError.emptyResponse }
        return content
    }

    private func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.badStatus(http.statusCode, body)
        }
    }
}
