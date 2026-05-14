import Foundation

struct AgentConfig: Codable, Equatable {
    var baseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var model: String = ""
    var temperature: Double = 0.2
    var alwaysConfirmActions: Bool = true
    var allowActionQueue: Bool = true
    var maxQueueActions: Int = 6
    var maxLinearSpeed: Double = 0.15
    var maxAngularSpeed: Double = 0.45
    var maxActionDuration: Double = 1.5
    var obstacleStopDistance: Double = 0.55
    var streamResponses: Bool = true

    var normalizedBaseURL: String {
        var value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value.isEmpty ? "https://api.openai.com/v1" : value
    }
}

struct AgentChatMessage: Identifiable, Equatable {
    enum Role: String { case user = "你", assistant = "助手", system = "系统" }
    let id: UUID
    let role: Role
    var text: String
    let date: Date

    init(id: UUID = UUID(), role: Role, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}

struct AgentAction: Codable, Equatable, Identifiable {
    var id = UUID()
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
    var actions: [AgentAction]?

    var actionList: [AgentAction] {
        if let actions, !actions.isEmpty { return actions }
        if let action { return [action] }
        return []
    }
}

struct AgentActionQueue: Identifiable, Equatable {
    let id = UUID()
    var actions: [AgentAction]
    var requiresConfirmation: Bool

    var title: String { actions.count == 1 ? "待确认动作" : "待确认动作队列（\(actions.count) 步）" }
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
    var stream: Bool?

    enum CodingKeys: String, CodingKey { case model, messages, temperature, stream; case responseFormat = "response_format" }
    struct ResponseFormat: Codable { var type: String }
}

struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { var role: String?; var content: String? }
        var message: Message
    }
    var choices: [Choice]
}
