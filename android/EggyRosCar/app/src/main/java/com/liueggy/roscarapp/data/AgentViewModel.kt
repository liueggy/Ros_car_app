package com.liueggy.roscarapp.data

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AgentViewModel : ViewModel() {
    private val client = OpenAICompatibleClient()
    private val promptBuilder = AgentPromptBuilder()
    private val planDecoder = AgentPlanDecoder()
    private val gson = Gson()
    private var robot: RobotViewModel? = null
    private var toolExecutor: RobotToolExecutor? = null

    private val _config = MutableStateFlow(AgentConfig())
    val config: StateFlow<AgentConfig> = _config.asStateFlow()
    private val _availableModels = MutableStateFlow<List<String>>(emptyList())
    val availableModels: StateFlow<List<String>> = _availableModels.asStateFlow()
    private val _messages = MutableStateFlow(listOf(AgentMessage("assistant", "你好，我是 ROS Car 智能助手。你可以问我小车状态，也可以让我执行短距离移动、停止、探索、保存地图等操作。")))
    val messages: StateFlow<List<AgentMessage>> = _messages.asStateFlow()
    private val _pendingActions = MutableStateFlow<List<AgentAction>>(emptyList())
    val pendingActions: StateFlow<List<AgentAction>> = _pendingActions.asStateFlow()
    private val _status = MutableStateFlow("")
    val status: StateFlow<String> = _status.asStateFlow()
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    private val _isExecuting = MutableStateFlow(false)
    val isExecuting: StateFlow<Boolean> = _isExecuting.asStateFlow()

    fun bind(robot: RobotViewModel) {
        this.robot = robot
        this.toolExecutor = RobotToolExecutor(robot.asRobotControlling())
    }

    fun loadConfig(context: Context) {
        val raw = context.getSharedPreferences("agent", Context.MODE_PRIVATE).getString("config", null) ?: return
        runCatching { gson.fromJson(raw, AgentConfig::class.java) }.getOrNull()?.let { _config.value = it }
    }

    fun saveConfig(context: Context, config: AgentConfig = _config.value) {
        _config.value = config
        context.getSharedPreferences("agent", Context.MODE_PRIVATE).edit().putString("config", gson.toJson(config)).apply()
    }

    fun fetchModels() {
        val cfg = _config.value
        viewModelScope.launch {
            _isLoading.value = true
            _status.value = "正在获取模型列表..."
            runCatching { client.fetchModels(cfg) }
                .onSuccess { models ->
                    _availableModels.value = models
                    if (_config.value.model.isBlank() && models.isNotEmpty()) _config.value = _config.value.copy(model = models.first())
                    _status.value = if (models.isEmpty()) "没有获取到模型，请手动输入。" else "已获取 ${models.size} 个模型。"
                }
                .onFailure { _status.value = it.localizedMessage ?: "获取模型失败" }
            _isLoading.value = false
        }
    }

    fun send(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val cfg = _config.value
        val rb = robot
        _messages.value = _messages.value + AgentMessage("user", trimmed)
        if (cfg.apiKey.isBlank() || cfg.model.isBlank()) {
            _messages.value = _messages.value + AgentMessage("system", "请先在设置中填写 API Key 并选择模型。")
            return
        }
        viewModelScope.launch {
            _isLoading.value = true
            val promptMessages = promptBuilder.buildMessages(trimmed, cfg, rb?.state?.value, rb?.connectionStatus?.value ?: "未绑定机器人", rb?.logs?.value ?: emptyList())
            runCatching { client.complete(cfg, promptMessages) }
                .onSuccess { content ->
                    val plan = planDecoder.decodePlan(content)
                    _messages.value = _messages.value + AgentMessage("assistant", plan.reply)
                    handleActions(plan.actionList)
                }
                .onFailure { _messages.value = _messages.value + AgentMessage("system", "请求失败：${it.localizedMessage ?: "未知错误"}") }
            _isLoading.value = false
        }
    }

    private fun handleActions(actions: List<AgentAction>) {
        var items = actions
        if (items.isEmpty()) return
        if (!_config.value.allowActionQueue) items = items.take(1)
        items = items.take(maxOf(1, _config.value.maxQueueActions))
        if (!_config.value.allowRobotControl) {
            _messages.value = _messages.value + AgentMessage("system", "Agent 控车已关闭，仅保留问答能力。")
            return
        }
        val needsConfirm = _config.value.alwaysConfirmActions || items.size > 1 || items.any { it.requiresConfirmation || it.name != "stop" }
        if (needsConfirm) {
            _pendingActions.value = items
            _messages.value = _messages.value + AgentMessage("system", "已生成动作计划：\n${describe(items)}")
        } else execute(items)
    }

    fun confirmPending() {
        val items = _pendingActions.value
        _pendingActions.value = emptyList()
        execute(items)
    }

    fun cancelPending() {
        _pendingActions.value = emptyList()
        _messages.value = _messages.value + AgentMessage("system", "已取消执行。")
    }

    fun stopExecutionQueue() {
        robot?.stop()
        _isExecuting.value = false
        _messages.value = _messages.value + AgentMessage("system", "已停止执行队列，并发送停止命令。")
    }

    private fun execute(actions: List<AgentAction>) {
        if (actions.isEmpty()) return
        viewModelScope.launch {
            _isExecuting.value = true
            for ((index, action) in actions.withIndex()) {
                _messages.value = _messages.value + AgentMessage("system", "执行第 ${index + 1}/${actions.size} 步：${describe(action)}")
                val result = toolExecutor?.execute(action, _config.value) ?: "工具执行器未就绪。"
                _messages.value = _messages.value + AgentMessage("system", result)
                if (result.contains("拒绝") || result.contains("未在线") || result.contains("不支持")) break
            }
            _isExecuting.value = false
        }
    }

    fun describe(action: AgentAction): String = if (action.parameters.isEmpty()) action.name else action.name + " " + action.parameters.toSortedMap().map { "${it.key}=${it.value}" }.joinToString(", ")
    fun describe(actions: List<AgentAction>): String = actions.mapIndexed { index, action -> "${index + 1}. ${describe(action)}" }.joinToString("\n")
}
