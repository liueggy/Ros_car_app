package com.liueggy.roscarapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import okhttp3.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}

data class UiState(
    val url: String = "wss://liueggy.live/ws",
    val status: String = "未连接",
    val nav: JsonObject? = null,
    val logs: List<String> = emptyList()
)

class RobotVm : ViewModel() {
    private val gson = Gson()
    private val client = OkHttpClient.Builder().pingInterval(10, TimeUnit.SECONDS).build()
    private var ws: WebSocket? = null
    private val _ui = MutableStateFlow(UiState())
    val ui = _ui.asStateFlow()

    fun connect(raw: String = _ui.value.url) {
        ws?.close(1000, null)
        val url = normalize(raw)
        _ui.update { it.copy(url = url, status = "连接中") }
        log("连接中转服务器：$url")
        ws = client.newWebSocket(Request.Builder().url(url).build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _ui.update { it.copy(status = "等待数据") }
                log("WebSocket 已连接")
            }
            override fun onMessage(webSocket: WebSocket, text: String) { handle(text) }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _ui.update { it.copy(status = "连接失败") }
                log("连接失败：${t.localizedMessage ?: "未知错误"}")
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _ui.update { it.copy(status = "已断开") }
                log("连接已断开")
            }
        })
    }

    private fun handle(text: String) {
        runCatching { JsonParser.parseString(text).asJsonObject }.onSuccess { obj ->
            when (obj.str("type")) {
                "nav_view" -> {
                    val online = obj.obj("system")?.bool("robot_connected") == true
                    _ui.update { it.copy(nav = obj, status = if (online) "在线" else "小车离线") }
                }
                "ack" -> log(if (obj.bool("robot_forwarded") == true) "命令已转发到小车" else "命令到达云端，小车未在线")
                "error" -> log("服务器返回错误")
            }
        }.onFailure { log("解析失败：${it.localizedMessage}") }
    }

    private fun send(m: Map<String, Any>) {
        if (_ui.value.status != "在线") { log("未在线，命令未发送：${m["type"]}"); return }
        ws?.send(gson.toJson(m))
    }

    fun cmd(x: Double, y: Double, z: Double) = send(mapOf("type" to "cmd_vel", "linear_x" to x, "linear_y" to y, "angular_z" to z))
    fun stop() = cmd(0.0, 0.0, 0.0)
    fun reset() = send(mapOf("type" to "reset"))
    fun explore() = send(mapOf("type" to "auto_explore", "enabled" to !(_ui.value.nav?.obj("system")?.bool("auto_explore") ?: false)))
    fun goal(x: Double, y: Double) = send(mapOf("type" to "goal", "frame_id" to "map", "x" to x, "y" to y, "yaw" to 0))
    fun saveMap(name: String) = send(mapOf("type" to "save_map", "name" to name))

    private fun normalize(s: String): String {
        val t = s.trim()
        return when {
            t.isEmpty() || t == "default" || t == "liueggy.live" -> "wss://liueggy.live/ws"
            t.startsWith("http://") -> t.replaceFirst("http://", "ws://")
            t.startsWith("https://") -> t.replaceFirst("https://", "wss://")
            t.startsWith("ws://") || t.startsWith("wss://") -> t
            else -> "wss://$t${if (t.endsWith("/ws")) "" else "/ws"}"
        }
    }

    private fun log(s: String) {
        val time = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        _ui.update { it.copy(logs = (listOf("$time  $s") + it.logs).take(80)) }
    }

    override fun onCleared() { ws?.close(1000, null); super.onCleared() }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App(vm: RobotVm = viewModel()) {
    val ui by vm.ui.collectAsState()
    var tab by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) { vm.connect() }
    MaterialTheme {
        Scaffold(
            topBar = { TopAppBar(title = { Text(listOf("总览", "控制", "地图", "任务", "设置")[tab]) }, actions = { if (ui.status == "在线") IconButton({ vm.stop() }) { Icon(Icons.Default.Stop, "急停", tint = Color.Red) } }) },
            bottomBar = { NavigationBar { listOf(Icons.Default.Home, Icons.Default.SportsEsports, Icons.Default.Map, Icons.Default.Checklist, Icons.Default.Settings).forEachIndexed { i, icon -> NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = { Icon(icon, null) }, label = { Text(listOf("总览", "控制", "地图", "任务", "设置")[i]) }) } } }
        ) { p -> Box(Modifier.padding(p).fillMaxSize()) { when (tab) { 0 -> Dashboard(ui); 1 -> Control(vm); 2 -> MapPage(ui, vm); 3 -> Tasks(vm); 4 -> Settings(ui, vm) } } }
    }
}

@Composable fun Dashboard(ui: UiState) {
    val n = ui.nav
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { CardItem("连接", ui.status, n?.obj("system")?.str("robot_id") ?: "--", Modifier.weight(1f)); CardItem("电池", n?.obj("battery")?.int("percent")?.let { "$it%" } ?: "--", n?.obj("battery")?.dbl("voltage")?.let { "%.2f V".format(it) } ?: "--", Modifier.weight(1f)) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { CardItem("导航", n?.str("nav_status") ?: "--", n?.obj("system")?.str("stream_mode") ?: "relay", Modifier.weight(1f)); CardItem("建图", "%.1f%%".format(n?.obj("occupancy_grid")?.obj("stats")?.dbl("known_percent") ?: 0.0), "地图进度", Modifier.weight(1f)) }
        CenterText(if (n == null) "等待服务器数据" else "位置：${n.obj("robot")?.dbl("x") ?: 0.0}, ${n.obj("robot")?.dbl("y") ?: 0.0}")
    }
}

@Composable fun Control(vm: RobotVm) {
    Column(Modifier.fillMaxSize().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Button({ vm.cmd(0.22,0.0,0.0) }) { Text("前进") }; Button({ vm.cmd(-0.22,0.0,0.0) }) { Text("后退") } }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Button({ vm.cmd(0.0,0.0,0.45) }) { Text("左转") }; Button({ vm.stop() }, colors = ButtonDefaults.buttonColors(containerColor = Color.Red)) { Text("急停") }; Button({ vm.cmd(0.0,0.0,-0.45) }) { Text("右转") } }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton({ vm.explore() }) { Text("自动探索") }; OutlinedButton({ vm.reset() }) { Text("重置") } }
    }
}

@Composable fun MapPage(ui: UiState, vm: RobotVm) {
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        CenterText("地图视图：已接入 WebSocket 数据，下一版加入 Canvas 栅格渲染")
        ui.nav?.let { Text("前方距离：${it.obj("summary")?.dbl("front") ?: -1.0} m") }
        Button({ vm.goal(0.0,0.0) }) { Text("发送原点目标点测试") }
    }
}

@Composable fun Tasks(vm: RobotVm) {
    var name by remember { mutableStateOf("探索地图") }
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Button({ vm.explore() }, Modifier.fillMaxWidth()) { Text("开始/停止自动探索") }
        OutlinedButton({ vm.reset() }, Modifier.fillMaxWidth()) { Text("重置并重新建图") }
        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("地图名称") })
        Button({ vm.saveMap(name) }, Modifier.fillMaxWidth()) { Text("保存地图") }
    }
}

@Composable fun Settings(ui: UiState, vm: RobotVm) {
    var url by remember { mutableStateOf(ui.url) }
    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { OutlinedTextField(url, { url = it }, Modifier.fillMaxWidth(), label = { Text("WebSocket 地址") }) }
        item { Button({ vm.connect(url) }, Modifier.fillMaxWidth()) { Text("重新连接") } }
        item { Text("状态：${ui.status}") }
        items(ui.logs) { Text(it, style = MaterialTheme.typography.bodySmall) }
    }
}

@Composable fun CardItem(title: String, value: String, sub: String, modifier: Modifier = Modifier) {
    Card(modifier) { Column(Modifier.padding(12.dp)) { Text(title, style = MaterialTheme.typography.labelSmall); Text(value, style = MaterialTheme.typography.titleMedium); Text(sub, style = MaterialTheme.typography.labelSmall) } }
}

@Composable fun CenterText(s: String) { Box(Modifier.fillMaxWidth().height(220.dp), contentAlignment = Alignment.Center) { Text(s) } }

fun JsonObject.str(k: String) = if (has(k) && !get(k).isJsonNull) get(k).asString else null
fun JsonObject.dbl(k: String) = if (has(k) && !get(k).isJsonNull) get(k).asDouble else null
fun JsonObject.int(k: String) = if (has(k) && !get(k).isJsonNull) get(k).asInt else null
fun JsonObject.bool(k: String) = if (has(k) && !get(k).isJsonNull) get(k).asBoolean else null
fun JsonObject.obj(k: String) = if (has(k) && get(k).isJsonObject) getAsJsonObject(k) else null
