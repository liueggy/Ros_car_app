package com.liueggy.roscarapp.data

import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class OpenAICompatibleClient {
    private val http = OkHttpClient()
    private val gson = Gson()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun fetchModels(config: AgentConfig): List<String> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${config.normalizedBaseURL}/models")
            .addHeader("Authorization", "Bearer ${config.apiKey}")
            .build()
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("获取模型失败：HTTP ${response.code}")
            val body = response.body?.string().orEmpty()
            gson.fromJson(body, OpenAIModelsResponse::class.java).data.map { it.id }.filter { it.isNotBlank() }
        }
    }

    suspend fun complete(config: AgentConfig, messages: List<OpenAIChatRequest.Message>): String = withContext(Dispatchers.IO) {
        val payload = OpenAIChatRequest(model = config.model, messages = messages, temperature = config.temperature, stream = false)
        val request = Request.Builder()
            .url("${config.normalizedBaseURL}/chat/completions")
            .addHeader("Authorization", "Bearer ${config.apiKey}")
            .post(gson.toJson(payload).toRequestBody(jsonMediaType))
            .build()
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("请求失败：HTTP ${response.code}")
            val body = response.body?.string().orEmpty()
            gson.fromJson(body, OpenAIChatResponse::class.java).choices.firstOrNull()?.message?.content ?: ""
        }
    }
}
