package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.liueggy.roscarapp.data.RobotViewModel
import com.liueggy.roscarapp.data.RobotWebSocketClient

@Composable
fun SettingsScreen(viewModel: RobotViewModel) {
    val state by viewModel.state.collectAsState()
    val connectionStatus by viewModel.connectionStatus.collectAsState()
    val logs by viewModel.logs.collectAsState()
    var urlText by remember { mutableStateOf(RobotWebSocketClient.DEFAULT_SERVER_URL) }
    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("服务器", style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(urlText, { urlText = it }, label = { Text("WebSocket 地址") }, modifier = Modifier.fillMaxWidth(), singleLine = true, keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done))
            Button({ viewModel.connectWithUrl(urlText) }, Modifier.fillMaxWidth()) { Text("重新连接") }
            OutlinedButton({ urlText = RobotWebSocketClient.DEFAULT_SERVER_URL; viewModel.connectWithUrl(urlText) }, Modifier.fillMaxWidth()) { Text("使用默认 wss://liueggy.live/ws") }
            Divider()
            InfoRow("连接状态", connectionStatus)
            InfoRow("服务器", viewModel.client.serverHost)
            InfoRow("机器人", if (state?.system?.robotConnected == true) (state?.system?.robotId ?: "在线") else "离线")
            InfoRow("ROS", if (state?.system?.ros == true) "正常" else "异常/未知")
            InfoRow("流模式", state?.system?.streamMode ?: "--")
        } } }
        item { Text("日志", style = MaterialTheme.typography.titleSmall) }
        items(logs) { log -> Text(log, style = MaterialTheme.typography.bodySmall) }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
