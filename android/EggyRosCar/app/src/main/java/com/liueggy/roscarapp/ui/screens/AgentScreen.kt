package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.liueggy.roscarapp.data.AgentMessage
import com.liueggy.roscarapp.data.AgentViewModel
import com.liueggy.roscarapp.data.RobotViewModel

@Composable
fun AgentScreen(robotViewModel: RobotViewModel) {
    val agent: AgentViewModel = viewModel()
    val context = LocalContext.current
    val config by agent.config.collectAsState()
    val messages by agent.messages.collectAsState()
    val pendingActions by agent.pendingActions.collectAsState()
    val status by agent.status.collectAsState()
    val isLoading by agent.isLoading.collectAsState()
    val isExecuting by agent.isExecuting.collectAsState()
    var input by remember { mutableStateOf("") }
    var showSettings by remember { mutableStateOf(false) }

    LaunchedEffect(robotViewModel) {
        agent.bind(robotViewModel)
        agent.loadConfig(context)
    }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(if (config.model.isBlank()) "未选择模型" else config.model, style = MaterialTheme.typography.labelMedium, modifier = Modifier.weight(1f))
            if (!config.allowRobotControl) AssistChip(onClick = {}, label = { Text("只读") })
            TextButton(onClick = { showSettings = true }) { Text("设置") }
        }
        if (config.apiKey.isBlank() || config.model.isBlank()) {
            Card(Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("先完成模型设置，填写 Base URL/API Key 并选择模型。", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                    Button(onClick = { showSettings = true }) { Text("设置") }
                }
            }
        }
        LazyColumn(Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { QuickPromptRow(enabled = !isLoading && !isExecuting) { agent.send(it) } }
            items(messages) { MessageBubble(it) }
        }
        if (pendingActions.isNotEmpty()) {
            Card(Modifier.fillMaxWidth().padding(12.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (pendingActions.size == 1) "待确认动作" else "待确认动作队列（${pendingActions.size} 步）", style = MaterialTheme.typography.titleSmall)
                    pendingActions.forEachIndexed { index, action -> Text("${index + 1}. ${agent.describe(action)}", style = MaterialTheme.typography.bodySmall) }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { agent.cancelPending() }, modifier = Modifier.weight(1f)) { Text("取消") }
                        Button(onClick = { agent.confirmPending() }, modifier = Modifier.weight(1f)) { Text("确认执行") }
                    }
                }
            }
        }
        if (isExecuting) {
            Button(onClick = { agent.stopExecutionQueue() }, modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp), colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) { Text("停止队列") }
        }
        Row(Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(value = input, onValueChange = { input = it }, placeholder = { Text("问问小车状态，或输入安全短动作…") }, modifier = Modifier.weight(1f), singleLine = true)
            Button(enabled = input.isNotBlank() && !isLoading && !isExecuting, onClick = { val text = input; input = ""; agent.send(text) }) { Text(if (isLoading) "..." else "发送") }
        }
    }

    if (showSettings) {
        AgentSettingsDialog(
            config = config,
            status = status,
            onDismiss = { showSettings = false; agent.saveConfig(context) },
            onSave = { agent.saveConfig(context, it); showSettings = false },
            onFetchModels = { agent.fetchModels() }
        )
    }
}

@Composable
private fun QuickPromptRow(enabled: Boolean, onPrompt: (String) -> Unit) {
    val prompts = listOf("小车现在状态如何？", "为什么现在不能动？", "向前走一点", "右转一点", "开始自动探索", "保存当前地图")
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        prompts.take(3).forEach { prompt -> AssistChip(enabled = enabled, onClick = { onPrompt(prompt) }, label = { Text(prompt) }) }
    }
}

@Composable
private fun MessageBubble(message: AgentMessage) {
    val color = when (message.role) {
        "user" -> MaterialTheme.colorScheme.primaryContainer
        "system" -> MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.45f)
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    val title = when (message.role) { "user" -> "你"; "system" -> "系统"; else -> "助手" }
    Surface(shape = MaterialTheme.shapes.medium, color = color, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp)) {
            Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(message.text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun AgentSettingsDialog(config: com.liueggy.roscarapp.data.AgentConfig, status: String, onDismiss: () -> Unit, onSave: (com.liueggy.roscarapp.data.AgentConfig) -> Unit, onFetchModels: () -> Unit) {
    var draft by remember(config) { mutableStateOf(config) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Agent 设置") },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                item { OutlinedTextField(draft.baseURL, { draft = draft.copy(baseURL = it) }, label = { Text("Base URL") }, singleLine = true) }
                item { OutlinedTextField(draft.apiKey, { draft = draft.copy(apiKey = it) }, label = { Text("API Key") }, visualTransformation = PasswordVisualTransformation(), singleLine = true) }
                item { OutlinedTextField(draft.model, { draft = draft.copy(model = it) }, label = { Text("模型名") }, singleLine = true) }
                item { Button(onClick = onFetchModels) { Text("自动获取模型列表") } }
                if (status.isNotBlank()) item { Text(status, style = MaterialTheme.typography.bodySmall) }
                item { Row(verticalAlignment = Alignment.CenterVertically) { Text("允许 Agent 控制小车", Modifier.weight(1f)); Switch(draft.allowRobotControl, { draft = draft.copy(allowRobotControl = it) }) } }
                item { Row(verticalAlignment = Alignment.CenterVertically) { Text("始终确认动作", Modifier.weight(1f)); Switch(draft.alwaysConfirmActions, { draft = draft.copy(alwaysConfirmActions = it) }) } }
            }
        },
        confirmButton = { Button(onClick = { onSave(draft) }) { Text("保存") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("关闭") } }
    )
}
