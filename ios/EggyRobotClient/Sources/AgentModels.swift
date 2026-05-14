import Foundation

struct AgentConfig: Codable, Equatable {
    var baseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var model: String = ""
    var temperature: Double = 0.2

    var normalizedBaseURL: String {
        var value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value.isEmpty ? "https://api.openai.com/v1" : value
    }
}

struct AgentChatMessage: Identifiable, Equatable {
    enum Role: String { case user = "你", assistant = "助手", system = "系统" }
    let id = UUID()
    let role: Role
    let text: String
    let date: Date = Date()
}

struct AgentAction: Codable, Equatable {
    var name: String
    var requiresConfirmation: Bool
    var parameters: [String: String]

    enum CodingKeys: String, CodingKey {
        case name
        case requiresConfirmation = "requires_confirmation"
        case parameters
    }
}

struct AgentPlan: Codable, Equatable {
    var reply: String
    var action: AgentAction?
}

struct OpenAIModel: Codable, Identifiable, Hashable {
    var id: String
}

struct OpenAIModelsResponse: Codable {
    var data: [OpenAIModel]
}

struct OpenAIChatRequest: Codable {
    struct Message: Codable { var role: String; var content: String }
    var model: String
    var messages: [Message]
    var temperature: Double
    var responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey { case model, messages, temperature; case responseFormat = "response_format" }
    struct ResponseFormat: Codable { var type: String }
}

struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { var role: String?; var content: String? }
        var message: Message
    }
    var choices: [Choice]
}
