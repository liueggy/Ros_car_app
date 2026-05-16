package com.liueggy.roscarapp.data

import com.google.gson.Gson

class AgentPlanDecoder(private val gson: Gson = Gson()) {
    fun decodePlan(content: String): AgentPlan {
        val trimmed = content.trim()
        runCatching { gson.fromJson(trimmed, AgentPlan::class.java) }.getOrNull()?.let { return it }
        extractJsonObject(trimmed)?.let { json ->
            runCatching { gson.fromJson(json, AgentPlan::class.java) }.getOrNull()?.let { return it }
        }
        return AgentPlan(reply = content)
    }

    fun visibleStreamingText(raw: String): String {
        extractPartialReply(raw)?.takeIf { it.isNotBlank() }?.let { return it }
        return if (raw.contains("{") || raw.contains("\"actions\"") || raw.contains("\"action\"")) "正在思考并规划动作…" else raw.trim()
    }

    private fun extractJsonObject(text: String): String? {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        return if (start >= 0 && end >= start) text.substring(start, end + 1) else null
    }

    private fun extractPartialReply(raw: String): String? {
        val keyIndex = listOf(raw.indexOf("\"reply\""), raw.indexOf("'reply'")).filter { it >= 0 }.minOrNull() ?: return null
        val colon = raw.indexOf(':', keyIndex)
        if (colon < 0) return null
        var value = raw.substring(colon + 1).trim()
        if (value.startsWith('"') || value.startsWith('\'')) value = value.drop(1)
        val end = value.indexOfFirst { it == '"' || it == '\'' }
        if (end >= 0) value = value.substring(0, end)
        return value.replace("\\n", "\n").replace("\\\"", "\"").trim()
    }
}
