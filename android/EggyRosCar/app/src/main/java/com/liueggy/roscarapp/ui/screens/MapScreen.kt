package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.liueggy.roscarapp.data.RobotViewModel
import com.liueggy.roscarapp.ui.components.InteractiveRobotMap

@Composable
fun MapScreen(viewModel: RobotViewModel) {
    val state by viewModel.state.collectAsState()

    val msg = state
    if (msg != null) {
        InteractiveRobotMap(
            state = msg,
            onGoal = { x, y -> viewModel.setGoal(x, y) },
            modifier = Modifier.fillMaxSize(),
            showOverlay = true
        )
    } else {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = androidx.compose.ui.Alignment.Center
        ) {
            Text("连接服务器后显示地图", style = MaterialTheme.typography.bodyLarge)
        }
    }
}
