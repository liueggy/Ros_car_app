package com.liueggy.roscarapp.data

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn

class RobotViewModel : ViewModel() {

    val client = RobotWebSocketClient()

    val state: StateFlow<NavViewMessage?> = client.state
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val connectionPhase: StateFlow<ConnectionPhase> = client.connectionPhase
        .stateIn(viewModelScope, SharingStarted.Eagerly, ConnectionPhase.IDLE)

    val connectionStatus: StateFlow<String> = client.connectionStatus
        .stateIn(viewModelScope, SharingStarted.Eagerly, "未连接")

    val logs: StateFlow<List<String>> = client.logs
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    fun connect() {
        client.connect(scope = viewModelScope)
    }

    fun disconnect() {
        client.disconnect()
    }

    fun setServerUrl(url: String) {
        client.setServerUrl(url)
    }

    fun connectWithUrl(url: String) {
        client.setServerUrl(url)
        client.connect(scope = viewModelScope)
    }

    fun cmd(x: Double, y: Double, z: Double) = client.cmd(x, y, z)
    fun stop() = client.stop()
    fun reset() = client.reset()
    fun setGoal(x: Double, y: Double) = client.setGoal(x, y)
    fun toggleExplore() = client.toggleExplore()
    fun setScene(id: String) = client.setScene(id)
    fun saveMap(name: String) = client.saveMap(name)
    fun loadMap(id: String) = client.loadMap(id)

    override fun onCleared() {
        super.onCleared()
        client.disconnect()
    }
}
