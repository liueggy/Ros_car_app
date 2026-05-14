import Foundation

@MainActor
final class RobotToolExecutor {
    private weak var robot: RobotViewModel?

    init(robot: RobotViewModel) { self.robot = robot }

    func execute(_ action: AgentAction) -> String {
        guard let robot else { return "机器人控制器不可用" }
        let name = action.name
        switch name {
        case "stop":
            robot.stop()
            return "已发送急停/停止命令。"
        case "move_forward_short":
            return move(robot: robot, x: limitedDouble(action.parameters["speed_mps"], default: 0.12, min: 0.05, max: 0.15), y: 0, z: 0, duration: limitedDouble(action.parameters["duration_s"], default: 0.8, min: 0.2, max: 1.5), frontCheck: true)
        case "move_backward_short":
            return move(robot: robot, x: -limitedDouble(action.parameters["speed_mps"], default: 0.10, min: 0.05, max: 0.12), y: 0, z: 0, duration: limitedDouble(action.parameters["duration_s"], default: 0.6, min: 0.2, max: 1.2), frontCheck: false)
        case "turn_left_short":
            return move(robot: robot, x: 0, y: 0, z: limitedDouble(action.parameters["angular_rps"], default: 0.35, min: 0.15, max: 0.45), duration: limitedDouble(action.parameters["duration_s"], default: 0.6, min: 0.2, max: 1.2), frontCheck: false)
        case "turn_right_short":
            return move(robot: robot, x: 0, y: 0, z: -limitedDouble(action.parameters["angular_rps"], default: 0.35, min: 0.15, max: 0.45), duration: limitedDouble(action.parameters["duration_s"], default: 0.6, min: 0.2, max: 1.2), frontCheck: false)
        case "start_auto_explore":
            if robot.state?.system.autoExplore == true { return "自动探索已经在运行。" }
            guard robot.phase.canSend, robot.robotOnline else { return "小车未在线，不能开始自动探索。" }
            robot.toggleExplore()
            return "已请求开始自动探索。"
        case "stop_auto_explore":
            if robot.state?.system.autoExplore == true { robot.toggleExplore(); return "已请求停止自动探索。" }
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

    private func move(robot: RobotViewModel, x: Double, y: Double, z: Double, duration: Double, frontCheck: Bool) -> String {
        guard robot.phase.canSend, robot.robotOnline else { return "小车未在线，移动命令未执行。" }
        if frontCheck, let front = robot.state?.summary.front, front < 0.55 { return String(format: "前方障碍 %.2fm，已拒绝前进。", front) }
        robot.cmd(x: x, y: y, z: z)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            robot.stop()
        }
        return String(format: "已执行短动作 %.1fs，并会自动停止。", duration)
    }

    private func limitedDouble(_ text: String?, default defaultValue: Double, min: Double, max: Double) -> Double {
        let value = Double(text ?? "") ?? defaultValue
        return Swift.max(min, Swift.min(max, value))
    }
}
