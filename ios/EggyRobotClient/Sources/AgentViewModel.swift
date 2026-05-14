import Foundation

@MainActor
final class AgentViewModel: ObservableObject {
    @Published var config = AgentConfig()
    @Published var availableModels: [String] = []
    @Published var messages: [AgentChatMessage] = [AgentChatMessage(role: .assistant, text: "你好，我是 ROS Car 智能助手。你可以问我小车状态，也可以让我执行短距离移动、停止、探索、保存地图等操作。危险动作会先请求确认。")]
    @Published var input = ""
    @Published var isLoading = false
    @Published var modelFetchStatus = ""
    @Published var pendingAction: AgentAction?

    private let client = OpenAICompatibleClient()
    private var toolExecutor: RobotToolExecutor?
    private weak var robot: RobotViewModel?
    private let configKey = "agent.config.v1"

    init() { loadConfig() }

    func bind(robot: RobotViewModel) {
        self.robot = robot
        self.toolExecutor = RobotToolExecutor(robot: robot)
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) { UserDefaults.standard.set(data, forKey: configKey) }
    }

    func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: configKey), let decoded = try? JSONDecoder().decode(AgentConfig.self, from: data) else { return }
        config = decoded
    }

    func fetchModels() {
        saveConfig()
        isLoading = true
        modelFetchStatus = "正在获取模型列表..."
        Task {
            do {
                let models = try await client.fetchModels(config: config)
                await MainActor.run {
                    self.availableModels = models
                    if self.config.model.isEmpty, let first = models.first { self.config.model = first; self.saveConfig() }
                    self.modelFetchStatus = models.isEmpty ? "没有获取到模型，请手动输入。" : "已获取 \(models.count) 个模型。"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.modelFetchStatus = error.localizedDescription; self.isLoading = false }
            }
        }
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(AgentChatMessage(role: .user, text: text))
        saveConfig()
        isLoading = true
        pendingAction = nil
        let promptMessages = buildMessages(userText: text)
        Task {
            do {
                let content = try await client.complete(config: config, messages: promptMessages)
                let plan = try decodePlan(from: content)
                await MainActor.run {
                    self.messages.append(AgentChatMessage(role: .assistant, text: plan.reply))
                    if let action = plan.action {
                        if action.requiresConfirmation || action.name != "stop" {
                            self.pendingAction = action
                            self.messages.append(AgentChatMessage(role: .system, text: "待确认动作：\(self.describe(action))"))
                        } else {
                            self.execute(action)
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.messages.append(AgentChatMessage(role: .system, text: "请求失败：\(error.localizedDescription)")); self.isLoading = false }
            }
        }
    }

    func confirmPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        execute(action)
    }

    func cancelPendingAction() {
        pendingAction = nil
        messages.append(AgentChatMessage(role: .system, text: "已取消执行。"))
    }

    private func execute(_ action: AgentAction) {
        let result = toolExecutor?.execute(action) ?? "工具执行器未就绪。"
        messages.append(AgentChatMessage(role: .system, text: result))
    }

    private func decodePlan(from content: String) throws -> AgentPlan {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), let plan = try? JSONDecoder().decode(AgentPlan.self, from: data) { return plan }
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            let json = String(trimmed[start...end])
            if let data = json.data(using: .utf8) { return try JSONDecoder().decode(AgentPlan.self, from: data) }
        }
        return AgentPlan(reply: content, action: nil)
    }

    private func buildMessages(userText: String) -> [OpenAIChatRequest.Message] {
        [
            .init(role: "system", content: systemPrompt),
            .init(role: "system", content: "当前机器人状态摘要：\n\(robotSummary())"),
            .init(role: "user", content: userText)
        ]
    }

    private var systemPrompt: String {
        """
        你是 ROS Car App 内的智能助手。你必须只返回 JSON，不要返回 Markdown。
        JSON 格式：{"reply":"给用户看的中文回复","action":{"name":"动作名","requires_confirmation":true,"parameters":{"key":"value"}}}
        如果只需要回答问题，action 为 null。
        可用动作：stop, move_forward_short, move_backward_short, turn_left_short, turn_right_short, start_auto_explore, stop_auto_explore, save_map, reset_map。
        移动动作必须短时低速：speed_mps<=0.15，angular_rps<=0.45，duration_s<=1.5。除 stop 外所有动作 requires_confirmation 必须为 true。
        不要输出底层 WebSocket/ROS 协议。不要编造状态；依据状态摘要回答。
        """
    }

    private func robotSummary() -> String {
        guard let robot else { return "机器人控制器未绑定" }
        guard let s = robot.state else { return "暂无机器人状态。连接状态：\(robot.connectionStatus)" }
        let yaw = s.robot.yaw * 180 / .pi
        return """
        连接状态：\(robot.connectionStatus)
        小车在线：\(s.system.robotConnected == true ? "是" : "否")
        ROS：\(s.system.ros == true ? "正常" : "异常或未知")
        电池：\(s.battery.percent.map { "\($0)%" } ?? "未知") \(s.battery.voltage.map { String(format: "%.2fV", $0) } ?? "")
        位置：x=\(String(format: "%.2f", s.robot.x)), y=\(String(format: "%.2f", s.robot.y)), yaw=\(String(format: "%.0f", yaw))°
        前方距离：\(s.summary.front.map { String(format: "%.2fm", $0) } ?? "未知")
        最近障碍：\(s.summary.nearest.map { String(format: "%.2fm", $0) } ?? "未知")
        建图覆盖：\(String(format: "%.1f%%", s.occupancyGrid?.stats.knownPercent ?? 0))
        导航状态：\(s.navStatus)
        自动探索：\(s.system.autoExplore == true ? "运行中" : "未运行")
        最近日志：\(robot.log.prefix(5).joined(separator: "；"))
        """
    }

    func describe(_ action: AgentAction) -> String {
        if action.parameters.isEmpty { return action.name }
        return action.name + " " + action.parameters.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
    }
}
