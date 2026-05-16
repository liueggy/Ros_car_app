import Foundation

@MainActor
final class RobotToolExecutor {
    private weak var robot: (any RobotControlling)?
    private var currentStopTask: Task<Void, Never>?

    init(robot: any RobotControlling) { self.robot = robot }

    func execute(_ action: AgentAction, config: AgentConfig) async -> String {
        guard let robot else { return "机器人控制器不可用" }
        let name = action.name
        switch name {
        case "stop":
            currentStopTask?.cancel()
            robot.stop()
            return "已发送急停/停止命令。"
        case "move_forward_short":
            return await move(robot: robot, x: limitedDouble(action.parameters["speed_mps"], default: 0.12, min: 0.05, max: config.maxLinearSpeed), y: 0, z: 0, duration: duration(action, config), frontCheck: true, config: config)
        case "move_backward_short":
            return await move(robot: robot, x: -limitedDouble(action.parameters["speed_mps"], default: 0.10, min: 0.05, max: min(0.12, config.maxLinearSpeed)), y: 0, z: 0, duration: min(duration(action, config), 1.2), frontCheck: false, config: config)
        case "move_front_right_short", "move_diagonal_front_right_short":
            let speed = limitedDouble(action.parameters["speed_mps"], default: 0.10, min: 0.04, max: min(0.12, config.maxLinearSpeed))
            return await move(robot: robot, x: speed, y: -speed, z: 0, duration: duration(action, config), frontCheck: true, config: config)
        case "move_front_left_short", "move_diagonal_front_left_short":
            let speed = limitedDouble(action.parameters["speed_mps"], default: 0.10, min: 0.04, max: min(0.12, config.maxLinearSpeed))
            return await move(robot: robot, x: speed, y: speed, z: 0, duration: duration(action, config), frontCheck: true, config: config)
        case "turn_left_short":
            return await move(robot: robot, x: 0, y: 0, z: limitedDouble(action.parameters["angular_rps"], default: 0.35, min: 0.15, max: config.maxAngularSpeed), duration: min(duration(action, config), 1.2), frontCheck: false, config: config)
        case "turn_right_short":
            return await move(robot: robot, x: 0, y: 0, z: -limitedDouble(action.parameters["angular_rps"], default: 0.35, min: 0.15, max: config.maxAngularSpeed), duration: min(duration(action, config), 1.2), frontCheck: false, config: config)
        case "start_auto_explore":
            if robot.isAutoExploreRunning { return "自动探索已经在运行。" }
            guard robot.canSendCommands, robot.isRobotOnline else { return "小车未在线，不能开始自动探索。" }
            robot.toggleExplore()
            return "已请求开始自动探索。"
        case "stop_auto_explore":
            if robot.isAutoExploreRunning { robot.toggleExplore(); return "已请求停止自动探索。" }
            return "自动探索当前未运行。"
        case "save_map":
            let raw = action.parameters["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            robot.saveMap(name: raw?.isEmpty == false ? raw! : "Agent保存地图")
            return "已请求保存地图。"
        case "reset_map":
            robot.reset()
            return "已请求重置地图/重新建图。"
        default:
            return "暂不支持动作：\(name)"
        }
    }

    private func move(robot: any RobotControlling, x: Double, y: Double, z: Double, duration: Double, frontCheck: Bool, config: AgentConfig) async -> String {
        guard robot.canSendCommands, robot.isRobotOnline else { return "小车未在线，移动命令未执行。" }
        if frontCheck, let front = robot.frontDistance, front < config.obstacleStopDistance { return String(format: "前方障碍 %.2fm，已拒绝前进。", front) }
        currentStopTask?.cancel()
        robot.cmd(x: x, y: y, z: z)
        currentStopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled { robot.stop() }
        }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        if !Task.isCancelled { robot.stop() }
        return String(format: "已执行短动作 %.1fs，并自动停止。", duration)
    }

    private func duration(_ action: AgentAction, _ config: AgentConfig) -> Double {
        limitedDouble(action.parameters["duration_s"], default: 0.8, min: 0.2, max: config.maxActionDuration)
    }

    private func limitedDouble(_ text: String?, default defaultValue: Double, min: Double, max: Double) -> Double {
        let value = Double(text ?? "") ?? defaultValue
        return Swift.max(min, Swift.min(max, value))
    }
}
