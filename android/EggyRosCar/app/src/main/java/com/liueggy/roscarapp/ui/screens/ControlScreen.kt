package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.liueggy.roscarapp.data.RobotViewModel
import com.liueggy.roscarapp.ui.components.InteractiveRobotMap
import com.liueggy.roscarapp.ui.components.JoystickControl
import com.liueggy.roscarapp.ui.components.SpeedMode

@Composable
fun ControlScreen(viewModel: RobotViewModel) {
    val state by viewModel.state.collectAsState()
    var selectedMode by remember { mutableStateOf(SpeedMode.NORMAL) }
    Column(Modifier.fillMaxSize()) {
        if (state != null) InteractiveRobotMap(state!!, { x, y -> viewModel.setGoal(x, y) }, Modifier.fillMaxWidth().height(250.dp).padding(8.dp)) else Box(Modifier.fillMaxWidth().height(250.dp), contentAlignment = Alignment.Center) { Text("等待地图") }
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SpeedMode.entries.forEach { mode -> if (selectedMode == mode) Button({ selectedMode = mode }, Modifier.weight(1f), contentPadding = PaddingValues(8.dp, 6.dp)) { Text(mode.label) } else OutlinedButton({ selectedMode = mode }, Modifier.weight(1f), contentPadding = PaddingValues(8.dp, 6.dp)) { Text(mode.label) } }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
            JoystickControl(selectedMode.maxSpeed, { x, y, z -> viewModel.cmd(x, y, z) }, { viewModel.stop() })
            Column(verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                OutlinedButton({ viewModel.cmd(0.0, 0.0, 0.45) }) { Text("左转") }
                Button({ viewModel.stop() }, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) { Text("急停") }
                OutlinedButton({ viewModel.cmd(0.0, 0.0, -0.45) }) { Text("右转") }
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 32.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            val isExploring = state?.system?.autoExplore == true
            OutlinedButton({ viewModel.toggleExplore() }, Modifier.weight(1f)) { Text(if (isExploring) "停止探索" else "自动探索") }
            OutlinedButton({ viewModel.reset() }, Modifier.weight(1f)) { Text("重置") }
        }
        Spacer(Modifier.height(6.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 32.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton({ viewModel.cmd(selectedMode.maxSpeed * .45, 0.0, 0.0) }, Modifier.weight(1f), contentPadding = PaddingValues(4.dp, 8.dp)) { Text("微前", maxLines = 1) }
            OutlinedButton({ viewModel.cmd(-selectedMode.maxSpeed * .45, 0.0, 0.0) }, Modifier.weight(1f), contentPadding = PaddingValues(4.dp, 8.dp)) { Text("微后", maxLines = 1) }
            OutlinedButton({ viewModel.cmd(0.0, 0.0, .22) }, Modifier.weight(1f), contentPadding = PaddingValues(4.dp, 8.dp)) { Text("微左", maxLines = 1) }
            OutlinedButton({ viewModel.cmd(0.0, 0.0, -.22) }, Modifier.weight(1f), contentPadding = PaddingValues(4.dp, 8.dp)) { Text("微右", maxLines = 1) }
        }
    }
}
