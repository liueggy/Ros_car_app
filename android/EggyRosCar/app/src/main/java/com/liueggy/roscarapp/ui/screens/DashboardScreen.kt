package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.liueggy.roscarapp.data.RobotViewModel
import com.liueggy.roscarapp.ui.components.InteractiveRobotMap
import com.liueggy.roscarapp.ui.components.MetricCard

@Composable
fun DashboardScreen(viewModel: RobotViewModel) {
    val state by viewModel.state.collectAsState()
    val connectionStatus by viewModel.connectionStatus.collectAsState()

    val msg = state
    if (msg != null) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp)
        ) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        MetricCard(
                            "连接", connectionStatus,
                            if (msg.system.robotConnected == true) (msg.system.robotId ?: "eggy-001")
                            else "robot offline",
                            color = if (msg.system.robotConnected == true) Color.Green else Color(0xFFFFA500),
                            modifier = Modifier.weight(1f)
                        )
                        MetricCard(
                            "电池",
                            msg.battery.percent?.let { "$it%" } ?: "--",
                            msg.battery.voltage?.let { "${"%.2f".format(it)} V" } ?: "--",
                            color = Color.Blue,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        MetricCard(
                            "导航", msg.navStatus.ifEmpty { "--" },
                            msg.system.streamMode ?: msg.system.mode ?: "relay",
                            color = Color(0xFF9C27B0),
                            modifier = Modifier.weight(1f)
                        )
                        MetricCard(
                            "前方",
                            msg.summary.front?.let { "${"%.2f".format(it)} m" } ?: "--",
                            "最近障碍 ${msg.summary.nearest?.let { "${"%.2f".format(it)} m" } ?: "--"}",
                            color = Color.Cyan,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        MetricCard(
                            "建图",
                            "${"%.1f".format(msg.occupancyGrid?.stats?.knownPercent ?: 0.0)}%",
                            "空闲 ${msg.occupancyGrid?.stats?.free ?: 0} / 障碍 ${msg.occupancyGrid?.stats?.occupied ?: 0}",
                            color = Color(0xFF4B0082),
                            modifier = Modifier.weight(1f)
                        )
                        MetricCard(
                            "位置",
                            "${"%.1f".format(msg.robot.x)}, ${"%.1f".format(msg.robot.y)}",
                            "yaw ${"%.0f".format(msg.robot.yaw * 180 / Math.PI)}°",
                            color = Color(0xFF008080),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            item {
                InteractiveRobotMap(
                    state = msg,
                    onGoal = { x, y -> viewModel.setGoal(x, y) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(260.dp)
                )
            }
        }
    } else {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Default.Stop,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(8.dp))
                Text("等待服务器数据", style = MaterialTheme.typography.titleMedium)
                Text(connectionStatus, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
