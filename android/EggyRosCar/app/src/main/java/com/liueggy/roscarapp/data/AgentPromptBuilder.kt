package com.liueggy.roscarapp.data

class AgentPromptBuilder {
    fun buildMessages(userText: String, config: AgentConfig, state: NavViewMessage?, connectionStatus: String, logs: List<String>): List<OpenAIChatRequest.Message> = listOf(
        OpenAIChatRequest.Message("system", systemPrompt(config)),
        OpenAIChatRequest.Message("system", "当前机器人状态摘要：\n${robotSummary(state, connectionStatus, logs)}"),
        OpenAIChatRequest.Message("user", userText)
    )

    fun systemPrompt(config: AgentConfig): String = """
        你是 ROS Car App 内的智能助手。你必须只返回 JSON，不要返回 Markdown。
        JSON 格式：{"reply":"给用户看的中文回复","actions":[{"name":"动作名","requires_confirmation":true,"parameters":{"key":"value"}}]}
        如果只需要回答问题，actions 为空数组或省略。兼容旧字段 action，但优先使用 actions。
        可用动作：stop, move_forward_short, move_backward_short, move_front_right_short, move_front_left_short, turn_left_short, turn_right_short, start_auto_explore, stop_auto_explore, save_map, reset_map。
        当前 Agent 控车开关：${if (config.allowRobotControl) "开启" else "关闭"}。如果关闭，不要生成 actions，只做状态解释和建议。
        你可以把复合指令拆成最多 ${config.maxQueueActions} 个短动作。例如“先右转一点再前进一点”返回两个 actions。
        当前只支持短动作近似执行，不支持精确距离/角度闭环。遇到“前进一米/转三圈/移动两米”等长距离长时间指令，应明确说明当前只能拆成安全短动作近似，动作总数不要超过限制。
        移动动作参数：speed_mps<=${config.maxLinearSpeed}，angular_rps<=${config.maxAngularSpeed}，duration_s<=${config.maxActionDuration}。除 stop 外所有动作 requires_confirmation 必须为 true。
        不要输出底层 WebSocket/ROS 协议。不要编造状态；依据状态摘要回答。
    """.trimIndent()

    fun robotSummary(state: NavViewMessage?, connectionStatus: String, logs: List<String>): String {
        if (state == null) return "暂无机器人状态。连接状态：$connectionStatus"
        val yawDeg = state.robot.yaw * 180 / Math.PI
        return """
            连接状态：$connectionStatus
            小车在线：${if (state.system.robotConnected == true) "是" else "否"}
            ROS：${if (state.system.ros == true) "正常" else "异常或未知"}
            电池：${state.battery.percent?.let { "$it%" } ?: "未知"} ${state.battery.voltage?.let { "%.2fV".format(it) } ?: ""}
            位置：x=${"%.2f".format(state.robot.x)}, y=${"%.2f".format(state.robot.y)}, yaw=${"%.0f".format(yawDeg)}°
            前方距离：${state.summary.front?.let { "%.2fm".format(it) } ?: "未知"}
            最近障碍：${state.summary.nearest?.let { "%.2fm".format(it) } ?: "未知"}
            建图覆盖：${"%.1f%%".format(state.occupancyGrid?.stats?.knownPercent ?: 0.0)}
            导航状态：${state.navStatus}
            自动探索：${if (state.system.autoExplore == true) "运行中" else "未运行"}
            最近日志：${logs.take(5).joinToString("；")}
        """.trimIndent()
    }
}
