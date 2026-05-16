package com.liueggy.roscarapp.data

interface RobotControlling {
    val canSendCommands: Boolean
    val isRobotOnline: Boolean
    val frontDistance: Double?
    val isAutoExploreRunning: Boolean

    fun cmd(x: Double, y: Double, z: Double)
    fun stop()
    fun toggleExplore()
    fun saveMap(name: String)
    fun reset()
}

class RobotToolExecutor(private val robot: RobotControlling) {

    suspend fun execute(action: AgentAction, config: AgentConfig): String = when (action.name) {
        "stop" -> {
            robot.stop()
            "已发送急停/停止命令。"
        }
        "move_forward_short" -> move(
            x = limitedDouble(action.parameters["speed_mps"], 0.12, 0.05, config.maxLinearSpeed),
            y = 0.0,
            z = 0.0,
            duration = duration(action, config),
            frontCheck = true,
            config = config
        )
        "move_backward_short" -> move(
            x = -limitedDouble(action.parameters["speed_mps"], 0.10, 0.05, minOf(0.12, config.maxLinearSpeed)),
            y = 0.0,
            z = 0.0,
            duration = minOf(duration(action, config), 1.2),
            frontCheck = false,
            config = config
        )
        "move_front_right_short", "move_diagonal_front_right_short" -> {
            val speed = limitedDouble(action.parameters["speed_mps"], 0.10, 0.04, minOf(0.12, config.maxLinearSpeed))
            move(speed, -speed, 0.0, duration(action, config), true, config)
        }
        "move_front_left_short", "move_diagonal_front_left_short" -> {
            val speed = limitedDouble(action.parameters["speed_mps"], 0.10, 0.04, minOf(0.12, config.maxLinearSpeed))
            move(speed, speed, 0.0, duration(action, config), true, config)
        }
        "turn_left_short" -> move(0.0, 0.0, limitedDouble(action.parameters["angular_rps"], 0.35, 0.15, config.maxAngularSpeed), minOf(duration(action, config), 1.2), false, config)
        "turn_right_short" -> move(0.0, 0.0, -limitedDouble(action.parameters["angular_rps"], 0.35, 0.15, config.maxAngularSpeed), minOf(duration(action, config), 1.2), false, config)
        "start_auto_explore" -> {
            if (robot.isAutoExploreRunning) "自动探索已经在运行。"
            else if (!robot.canSendCommands || !robot.isRobotOnline) "小车未在线，不能开始自动探索。"
            else { robot.toggleExplore(); "已请求开始自动探索。" }
        }
        "stop_auto_explore" -> {
            if (robot.isAutoExploreRunning) { robot.toggleExplore(); "已请求停止自动探索。" } else "自动探索当前未运行。"
        }
        "save_map" -> {
            val raw = action.parameters["name"]?.trim().orEmpty()
            robot.saveMap(if (raw.isNotEmpty()) raw else "Agent保存地图")
            "已请求保存地图。"
        }
        "reset_map" -> {
            robot.reset()
            "已请求重置地图/重新建图。"
        }
        else -> "暂不支持动作：${action.name}"
    }

    private suspend fun move(x: Double, y: Double, z: Double, duration: Double, frontCheck: Boolean, config: AgentConfig): String {
        if (!robot.canSendCommands || !robot.isRobotOnline) return "小车未在线，移动命令未执行。"
        if (frontCheck && (robot.frontDistance ?: Double.MAX_VALUE) < config.obstacleStopDistance) {
            return "前方障碍 ${"%.2f".format(robot.frontDistance)}m，已拒绝前进。"
        }
        robot.cmd(x, y, z)
        kotlinx.coroutines.delay((duration * 1000).toLong())
        robot.stop()
        return "已执行短动作 ${"%.1f".format(duration)}s，并自动停止。"
    }

    private fun duration(action: AgentAction, config: AgentConfig): Double = limitedDouble(action.parameters["duration_s"], 0.8, 0.2, config.maxActionDuration)
    private fun limitedDouble(text: String?, defaultValue: Double, min: Double, max: Double): Double = (text?.toDoubleOrNull() ?: defaultValue).coerceIn(min, max)
}

fun RobotViewModel.asRobotControlling(): RobotControlling = object : RobotControlling {
    override val canSendCommands: Boolean get() = connectionPhase.value == ConnectionPhase.ONLINE || connectionPhase.value == ConnectionPhase.STALE
    override val isRobotOnline: Boolean get() = state.value?.system?.robotConnected == true
    override val frontDistance: Double? get() = state.value?.summary?.front
    override val isAutoExploreRunning: Boolean get() = state.value?.system?.autoExplore == true
    override fun cmd(x: Double, y: Double, z: Double) = this@asRobotControlling.cmd(x, y, z)
    override fun stop() = this@asRobotControlling.stop()
    override fun toggleExplore() = this@asRobotControlling.toggleExplore()
    override fun saveMap(name: String) = this@asRobotControlling.saveMap(name)
    override fun reset() = this@asRobotControlling.reset()
}
