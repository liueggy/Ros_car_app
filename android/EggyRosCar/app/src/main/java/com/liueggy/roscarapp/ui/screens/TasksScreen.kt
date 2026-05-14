package com.liueggy.roscarapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.liueggy.roscarapp.data.RobotViewModel

@Composable
fun TasksScreen(viewModel: RobotViewModel) {
    val state by viewModel.state.collectAsState()
    var mapName by remember { mutableStateOf("探索地图") }
    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val isExploring = state?.system?.autoExplore == true
            Button({ viewModel.toggleExplore() }, Modifier.fillMaxWidth()) { Text(if (isExploring) "停止自动探索" else "开始自动探索") }
            OutlinedButton({ viewModel.reset() }, Modifier.fillMaxWidth()) { Text("重置并重新建图") }
            OutlinedButton({ viewModel.setGoal(0.0, 0.0) }, Modifier.fillMaxWidth()) { Text("回到地图原点") }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(mapName, { mapName = it }, label = { Text("地图名称") }, modifier = Modifier.weight(1f), singleLine = true)
                Button({ viewModel.saveMap(mapName) }) { Text("保存") }
            }
        } } }
        val scenes = state?.scenes ?: emptyList()
        if (scenes.isNotEmpty()) { item { Text("预设场景", style = MaterialTheme.typography.titleSmall) }; items(scenes) { scene -> ListItem(headlineContent = { Text(scene.name) }, trailingContent = { Button({ viewModel.setScene(scene.id) }) { Text("切换") } }) } }
        val savedMaps = state?.savedMaps ?: emptyList()
        if (savedMaps.isNotEmpty()) { item { Text("已保存地图", style = MaterialTheme.typography.titleSmall) }; items(savedMaps) { mapItem -> Card(Modifier.fillMaxWidth()) { ListItem(headlineContent = { Text(mapItem.name) }, supportingContent = { Text("已探索 ${"%.1f".format(mapItem.stats?.knownPercent ?: 0.0)}%") }, trailingContent = { Button({ viewModel.loadMap(mapItem.id) }) { Text("加载") } }) } } }
    }
}
