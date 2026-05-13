package com.liueggy.roscarapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.viewmodel.compose.viewModel
import com.liueggy.roscarapp.data.RobotViewModel
import com.liueggy.roscarapp.ui.screens.*
import com.liueggy.roscarapp.ui.theme.EggyRosCarTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            EggyRosCarTheme {
                EggyRosCarApp()
            }
        }
    }
}

data class TabItem(
    val label: String,
    val icon: ImageVector,
    val screen: @Composable (RobotViewModel) -> Unit
)

private val tabs = listOf(
    TabItem("总览", Icons.Default.Home, { DashboardScreen(it) }),
    TabItem("控制", Icons.Default.SportsEsports, { ControlScreen(it) }),
    TabItem("地图", Icons.Default.Map, { MapScreen(it) }),
    TabItem("任务", Icons.Default.Checklist, { TasksScreen(it) }),
    TabItem("设置", Icons.Default.Settings, { SettingsScreen(it) })
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EggyRosCarApp() {
    val viewModel: RobotViewModel = viewModel()
    var selectedTab by remember { mutableStateOf(0) }

    LaunchedEffect(Unit) {
        viewModel.connect()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tabs[selectedTab].label, style = MaterialTheme.typography.titleMedium) },
                actions = {
                    val phase by viewModel.connectionPhase.collectAsState()
                    if (phase.name == "ONLINE" || phase.name == "STALE") {
                        IconButton(onClick = { viewModel.stop() }) {
                            Icon(Icons.Default.Stop, "急停", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { innerPadding ->
        Surface(modifier = Modifier.padding(innerPadding)) {
            when (selectedTab) {
                0 -> tabs[0].screen(viewModel)
                1 -> tabs[1].screen(viewModel)
                2 -> tabs[2].screen(viewModel)
                3 -> tabs[3].screen(viewModel)
                4 -> tabs[4].screen(viewModel)
            }
        }
    }
}
