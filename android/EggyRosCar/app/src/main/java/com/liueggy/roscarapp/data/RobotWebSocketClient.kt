package com.liueggy.roscarapp.data

import com.google.gson.Gson
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.*
import java.util.concurrent.TimeUnit

class RobotWebSocketClient {
    companion object {
        const val DEFAULT_SERVER_URL = "wss://liueggy.live/ws"
        private const val HEARTBEAT_INTERVAL_MS = 5000L
        private const val WATCHDOG_INTERVAL_MS = 2000L
        private const val MESSAGE_TIMEOUT_MS = 15000L
        private const val STATE_STALE_MS = 8000L
        private const val MAX_LOG_COUNT = 80
    }

    private val gson = Gson()
    private val commandEncoder = RobotCommandEncoder()
    private val client = OkHttpClient.Builder().pingInterval(10, TimeUnit.SECONDS).build()
    private var webSocket: WebSocket? = null
    private var scope: CoroutineScope? = null
    private var heartbeatJob: Job? = null
    private var watchdogJob: Job? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempt = 0
    private var intentionalDisconnect = false

    private val _state = MutableStateFlow<NavViewMessage?>(null)
    val state: StateFlow<NavViewMessage?> = _state.asStateFlow()
    private val _connectionPhase = MutableStateFlow(ConnectionPhase.IDLE)
    val connectionPhase: StateFlow<ConnectionPhase> = _connectionPhase.asStateFlow()
    private val _connectionStatus = MutableStateFlow("未连接")
    val connectionStatus: StateFlow<String> = _connectionStatus.asStateFlow()
    private val _logs = MutableStateFlow<List<String>>(emptyList())
    val logs: StateFlow<List<String>> = _logs.asStateFlow()
    private val _lastMessageAt = MutableStateFlow<Long?>(null)
    private val _lastStateAt = MutableStateFlow<Long?>(null)

    var serverUrlString = DEFAULT_SERVER_URL
        private set

    val serverHost: String get() = try { java.net.URI(serverUrlString).host ?: serverUrlString } catch (_: Exception) { serverUrlString }

    fun connect(resetBackoff: Boolean = true, scope: CoroutineScope) {
        this.scope = scope
        intentionalDisconnect = false
        if (resetBackoff) reconnectAttempt = 0
        disconnectInternal(false)
        val url = normalizeUrl(serverUrlString) ?: DEFAULT_SERVER_URL
        serverUrlString = url
        val request = Request.Builder().url(url).build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _connectionPhase.value = ConnectionPhase.CONNECTING
                syncStatus()
                appendLog("WebSocket 已连接: $url")
            }
            override fun onMessage(webSocket: WebSocket, text: String) {
                _lastMessageAt.value = System.currentTimeMillis()
                handleMessage(text)
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                appendLog("连接已关闭: $reason")
                handleDisconnect()
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                appendLog("连接失败：${t.localizedMessage ?: "未知错误"}")
                handleDisconnect()
            }
        })
        _connectionPhase.value = ConnectionPhase.CONNECTING
        syncStatus()
        appendLog("连接中转服务器：$url")
        startTimers(scope)
    }

    fun disconnect() {
        intentionalDisconnect = true
        reconnectJob?.cancel()
        reconnectJob = null
        disconnectInternal(true)
        _connectionPhase.value = ConnectionPhase.DISCONNECTED
        syncStatus()
    }

    fun setServerUrl(url: String) { serverUrlString = url }

    fun cmd(x: Double, y: Double, z: Double) = sendCommand(RobotCommand.Velocity(x, y, z))
    fun stop() = cmd(0.0, 0.0, 0.0)
    fun reset() = sendCommand(RobotCommand.Reset)
    fun setGoal(x: Double, y: Double) = sendCommand(RobotCommand.Goal(x, y))
    fun toggleExplore() = sendCommand(RobotCommand.AutoExplore(!(_state.value?.system?.autoExplore ?: false)))
    fun setScene(id: String) = sendCommand(RobotCommand.SetScene(id))
    fun saveMap(name: String) = sendCommand(RobotCommand.SaveMap(name))
    fun loadMap(id: String) = sendCommand(RobotCommand.LoadMap(id))
    fun deleteMap(id: String) = sendCommand(RobotCommand.DeleteMap(id))
    fun setMode(mode: String) = sendCommand(RobotCommand.SetMode(mode))

    fun sendCommand(command: RobotCommand) = sendCommand(commandEncoder.encode(command))

    fun sendCommand(command: Map<String, Any>) {
        if (_connectionPhase.value != ConnectionPhase.ONLINE && _connectionPhase.value != ConnectionPhase.STALE) {
            appendLog("未在线，命令未发送：${command["type"] ?: "unknown"}")
            return
        }
        webSocket?.send(gson.toJson(command))
    }

    private fun normalizeUrl(raw: String): String? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed == "default" || trimmed == "liueggy.live") return DEFAULT_SERVER_URL
        return when {
            trimmed.startsWith("http://") -> trimmed.replace("http://", "ws://")
            trimmed.startsWith("https://") -> trimmed.replace("https://", "wss://")
            trimmed.startsWith("ws://") || trimmed.startsWith("wss://") -> trimmed
            else -> "wss://$trimmed${if (trimmed.endsWith("/ws")) "" else "/ws"}"
        }
    }

    private fun handleMessage(text: String) {
        try {
            val envelope = runCatching { gson.fromJson(text, RelayEnvelope::class.java) }.getOrNull()
            when (envelope?.type) {
                "nav_view" -> updateState(gson.fromJson(text, NavViewMessage::class.java))
                "ack" -> {
                    val ack = gson.fromJson(text, RelayAck::class.java)
                    appendLog(if (ack.robotForwarded == true) "命令已转发到小车" else "命令已到云端，但小车未在线")
                }
                "error" -> appendLog("服务器返回错误")
                else -> runCatching { updateState(gson.fromJson(text, NavViewMessage::class.java)) }
            }
        } catch (e: Exception) { appendLog("消息解析失败: ${e.localizedMessage}") }
    }

    private fun updateState(msg: NavViewMessage) {
        _state.value = msg
        _lastStateAt.value = System.currentTimeMillis()
        reconnectAttempt = 0
        _connectionPhase.value = if (msg.system.robotConnected == true) ConnectionPhase.ONLINE else ConnectionPhase.ROBOT_OFFLINE
        syncStatus()
    }

    private fun handleDisconnect() {
        if (intentionalDisconnect) return
        _connectionPhase.value = ConnectionPhase.FAILED
        syncStatus()
        scheduleReconnect()
    }

    private fun startTimers(scope: CoroutineScope) {
        heartbeatJob?.cancel(); watchdogJob?.cancel()
        heartbeatJob = scope.launch { while (isActive) { delay(HEARTBEAT_INTERVAL_MS); webSocket?.send(gson.toJson(commandEncoder.encode(RobotCommand.Ping()))) } }
        watchdogJob = scope.launch { while (isActive) { delay(WATCHDOG_INTERVAL_MS); watchdogTick() } }
    }

    private fun watchdogTick() {
        val now = System.currentTimeMillis()
        _lastMessageAt.value?.let { if (now - it > MESSAGE_TIMEOUT_MS) scheduleReconnect() }
        _lastStateAt.value?.let { if (_connectionPhase.value == ConnectionPhase.ONLINE && now - it > STATE_STALE_MS) { _connectionPhase.value = ConnectionPhase.STALE; syncStatus() } }
    }

    private fun scheduleReconnect() {
        if (reconnectJob != null) return
        heartbeatJob?.cancel(); watchdogJob?.cancel(); webSocket?.close(1000, null); webSocket = null
        reconnectAttempt++
        val delaySeconds = minOf(Math.pow(2.0, maxOf(0, reconnectAttempt - 1).toDouble()), 15.0)
        appendLog(String.format("%.0f 秒后自动重连", delaySeconds))
        reconnectJob = scope?.launch { delay((delaySeconds * 1000).toLong()); if (!intentionalDisconnect && scope != null) { reconnectJob = null; connect(false, scope!!) } }
    }

    private fun disconnectInternal(markIntentional: Boolean) {
        heartbeatJob?.cancel(); watchdogJob?.cancel(); webSocket?.close(1000, null); webSocket = null
        if (markIntentional) intentionalDisconnect = true
    }

    private fun syncStatus() {
        _connectionStatus.value = when (_connectionPhase.value) {
            ConnectionPhase.IDLE -> "未连接"
            ConnectionPhase.CONNECTING -> "连接中"
            ConnectionPhase.WAITING_FIRST_STATE -> "等待数据"
            ConnectionPhase.ONLINE -> "在线"
            ConnectionPhase.ROBOT_OFFLINE -> "小车离线"
            ConnectionPhase.STALE -> "数据延迟"
            ConnectionPhase.DISCONNECTED -> "已断开"
            ConnectionPhase.FAILED -> "连接失败"
        }
    }

    private fun appendLog(text: String) {
        val current = _logs.value.toMutableList()
        current.add(0, text)
        _logs.value = current.take(MAX_LOG_COUNT)
    }
}

enum class ConnectionPhase { IDLE, CONNECTING, WAITING_FIRST_STATE, ONLINE, ROBOT_OFFLINE, STALE, DISCONNECTED, FAILED }
