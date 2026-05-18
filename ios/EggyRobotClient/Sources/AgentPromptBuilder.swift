import Foundation

struct AgentPromptRobotSnapshot: Equatable {
    var connectionStatus: String
    var robotOnline: Bool?
    var rosOK: Bool?
    var batteryPercent: Int?
    var batteryVoltage: Double?
    var x: Double?
    var y: Double?
    var yawRadians: Double?
    var frontDistance: Double?
    var nearestDistance: Double?
    var knownMapPercent: Double?
    var navStatus: String?
    var autoExplore: Bool?
    var recentLogs: [String]
    var simpleNavStatus: String?
    var healthIssues: [String]

    static func unbound() -> Self {
        .init(connectionStatus: "机器人控制器未绑定", robotOnline: nil, rosOK: nil, batteryPercent: nil, batteryVoltage: nil, x: nil, y: nil, yawRadians: nil, frontDistance: nil, nearestDistance: nil, knownMapPercent: nil, navStatus: nil, autoExplore: nil, recentLogs: [], simpleNavStatus: nil, healthIssues: [])
    }

    static func noState(connectionStatus: String) -> Self {
        .init(connectionStatus: connectionStatus, robotOnline: nil, rosOK: nil, batteryPercent: nil, batteryVoltage: nil, x: nil, y: nil, yawRadians: nil, frontDistance: nil, nearestDistance: nil, knownMapPercent: nil, navStatus: nil, autoExplore: nil, recentLogs: [], simpleNavStatus: nil, healthIssues: [])
    }
}

struct AgentPromptBuilder {
    func buildMessages(userText: String, config: AgentConfig, robot: AgentPromptRobotSnapshot) -> [OpenAIChatRequest.Message] {
        [
            .init(role: "system", content: systemPrompt(config: config)),
            .init(role: "system", content: "当前机器人状态摘要：\n\(robotSummary(robot))"),
            .init(role: "user", content: userText)
        ]
    }

    func systemPrompt(config: AgentConfig) -> String {
        """
        你是 ROS Car App 内的智能助手。你必须只返回 JSON，不要返回 Markdown。
        JSON 格式：{"reply":"给用户看的中文回复","actions":[{"name":"动作名","requires_confirmation":true,"parameters":{"key":"value"}}]}
        如果只需要回答问题，actions 为空数组或省略。兼容旧字段 action，但优先使用 actions。
        可用动作：stop, move_forward_short, move_backward_short, move_front_right_short, move_front_left_short, turn_left_short, turn_right_short, start_auto_explore, stop_auto_explore, save_map, reset_map。
        建图与导航动作（需小车在线）：start_mapping（开始建图）, stop_mapping（停止建图）, save_navigation_map（保存导航地图，参数 name）, start_quick_nav（开启快速直达导航）, simple_goal（导航到坐标点，参数 x,y），stop_navigation（停止导航）, start_move_base（开启 move_base 完整导航）, set_mode_lite/set_mode_map（切换地图模式）。
        当前 Agent 控车开关：\(config.allowRobotControl ? "开启" : "关闭")。如果关闭，不要生成 actions，只做状态解释和建议。
        你可以把复合指令拆成最多 \(config.maxQueueActions) 个短动作。例如“先右转一点再前进一点”返回两个 actions。
        当前只支持短动作近似执行，不支持精确距离/角度闭环。遇到“前进一米/转三圈/移动两米”等长距离长时间指令，应明确说明当前只能拆成安全短动作近似，动作总数不要超过限制。
        移动动作参数：speed_mps<=\(config.maxLinearSpeed)，angular_rps<=\(config.maxAngularSpeed)，duration_s<=\(config.maxActionDuration)。除 stop 外所有动作 requires_confirmation 必须为 true。
        不要输出底层 WebSocket/ROS 协议。不要编造状态；依据状态摘要回答。
        """
    }

    func robotSummary(_ robot: AgentPromptRobotSnapshot) -> String {
        if robot.connectionStatus == "机器人控制器未绑定" { return robot.connectionStatus }
        if robot.robotOnline == nil { return "暂无机器人状态。连接状态：\(robot.connectionStatus)" }
        let yaw = (robot.yawRadians ?? 0) * 180 / .pi
        return """
        连接状态：\(robot.connectionStatus)
        小车在线：\(robot.robotOnline == true ? "是" : "否")
        ROS：\(robot.rosOK == true ? "正常" : "异常或未知")
        电池：\(robot.batteryPercent.map { "\($0)%" } ?? "未知") \(robot.batteryVoltage.map { String(format: "%.2fV", $0) } ?? "")
        位置：x=\(String(format: "%.2f", robot.x ?? 0)), y=\(String(format: "%.2f", robot.y ?? 0)), yaw=\(String(format: "%.0f", yaw))°
        前方距离：\(robot.frontDistance.map { String(format: "%.2fm", $0) } ?? "未知")
        最近障碍：\(robot.nearestDistance.map { String(format: "%.2fm", $0) } ?? "未知")
        建图覆盖：\(String(format: "%.1f%%", robot.knownMapPercent ?? 0))
        导航状态：\(robot.navStatus ?? "未知")
        自动探索：\(robot.autoExplore == true ? "运行中" : "未运行")
        快速导航状态：\(robot.simpleNavStatus ?? "未知")
        异常告警：\(robot.healthIssues.prefix(3).joined(separator: "；"))
        最近日志：\(robot.recentLogs.prefix(5).joined(separator: "；"))
        """
    }
}
