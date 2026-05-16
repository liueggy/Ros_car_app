package com.liueggy.roscarapp.data

import com.google.gson.annotations.SerializedName
import java.util.UUID

data class AgentConfig(
    val baseURL: String = "https://api.openai.com/v1",
    val apiKey: String = "",
    val model: String = "",
    val temperature: Double = 0.2,
    val alwaysConfirmActions: Boolean = true,
    val allowActionQueue: Boolean = true,
    val maxQueueActions: Int = 6,
    val maxLinearSpeed: Double = 0.15,
    val maxAngularSpeed: Double = 0.45,
    val maxActionDuration: Double = 1.5,
    val obstacleStopDistance: Double = 0.55,
    val streamResponses: Boolean = true,
    val allowRobotControl: Boolean = true
) {
    val normalizedBaseURL: String get() = baseURL.trim().trimEnd('/').ifEmpty { "https://api.openai.com/v1" }
}

data class AgentAction(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    @SerializedName("requires_confirmation") val requiresConfirmation: Boolean = true,
    val parameters: Map<String, String> = emptyMap()
)

data class AgentPlan(
    val reply: String,
    val action: AgentAction? = null,
    val actions: List<AgentAction>? = null
) {
    val actionList: List<AgentAction> get() = actions?.takeIf { it.isNotEmpty() } ?: action?.let { listOf(it) } ?: emptyList()
}

data class AgentMessage(val role: String, val text: String)

data class OpenAIChatRequest(
    val model: String,
    val messages: List<Message>,
    val temperature: Double,
    @SerializedName("response_format") val responseFormat: ResponseFormat? = ResponseFormat("json_object"),
    val stream: Boolean? = false
) {
    data class Message(val role: String, val content: String)
    data class ResponseFormat(val type: String)
}

data class OpenAIChatResponse(val choices: List<Choice> = emptyList()) {
    data class Choice(val message: Message = Message())
    data class Message(val role: String? = null, val content: String? = null)
}

data class OpenAIModelsResponse(val data: List<OpenAIModel> = emptyList())
data class OpenAIModel(val id: String = "")
