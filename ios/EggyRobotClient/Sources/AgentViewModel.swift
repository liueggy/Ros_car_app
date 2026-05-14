import Foundation

@MainActor
final class AgentViewModel: ObservableObject {
    @Published var config = AgentConfig()
    @Published var availableModels: [String] = []
    @Published var messages: [AgentChatMessage] = [AgentChatMessage(role: .assistant, text: "你好，我是 ROS Car 智能助手。你可以问我小车状态，也可以让我执行短距离移动、停止、探索、保存地图等操作。复杂指令会拆成动作队列，执行前需要确认。")]
    @Published var input = ""
    @Published var isLoading = false
    @Published var isExecuting = false
    @Published var modelFetchStatus = ""
    @Published var pendingQueue: AgentActionQueue?
    @Published var toolEvents: [AgentToolCallEvent] = []
    @Published var streamingPreview = ""
    @Published var scrollAnchor: UUID?

    var pendingAction: AgentAction? { pendingQueue?.actions.first }

    private let client = OpenAICompatibleClient()
    private var toolExecutor: RobotToolExecutor?
    private weak var robot: RobotViewModel?
    private var requestTask: Task<Void, Never>?
    private var executionTask: Task<Void, Never>?
    private let configKey = "agent.config.v2"

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

    func useQuickPrompt(_ text: String) {
        input = text
        send()
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(AgentChatMessage(role: .user, text: text))
        scrollAnchor = UUID()
        saveConfig()
        isLoading = true
        streamingPreview = ""
        pendingQueue = nil
        let promptMessages = buildMessages(userText: text)
        requestTask?.cancel()
        requestTask = Task {
            do {
                let content: String
                if config.streamResponses {
                    var previewBuffer = ""
                    var lastPreviewUpdate = Date.distantPast
                    var lastScroll = Date.distantPast
                    content = try await client.streamComplete(config: config, messages: promptMessages) { delta in
                        previewBuffer += delta
                        let now = Date()
                        guard now.timeIntervalSince(lastPreviewUpdate) > 0.12 else { return }
                        lastPreviewUpdate = now
                        let clean = self.visibleStreamingText(previewBuffer)
                        if !clean.isEmpty {
                            await MainActor.run { self.streamingPreview = clean }
                        }
                        if now.timeIntervalSince(lastScroll) > 0.5 {
                            lastScroll = now
                            await MainActor.run { self.scrollAnchor = UUID() }
                        }
                    }
                } else {
                    content = try await client.complete(config: config, messages: promptMessages)
                }
                let plan = try decodePlan(from: content)
                await MainActor.run {
                    self.streamingPreview = ""
                    self.messages.append(AgentChatMessage(role: .assistant, text: plan.reply))
                    self.handleActions(plan.actionList)
                    self.isLoading = false
                    self.requestTask = nil
                    self.scrollAnchor = UUID()
                }
            } catch is CancellationError {
                await MainActor.run {
                    if self.requestTask != nil {
                        self.messages.append(AgentChatMessage(role: .system, text: "已停止生成。"))
                    }
                    self.streamingPreview = ""
                    self.isLoading = false
                    self.requestTask = nil
                }
            } catch {
                await MainActor.run { self.streamingPreview = ""; self.messages.append(AgentChatMessage(role: .system, text: "请求失败：\(error.localizedDescription)")); self.isLoading = false; self.requestTask = nil }
            }
        }
    }

    func stopGenerating() {
        requestTask?.cancel()
        requestTask = nil
        streamingPreview = ""
        isLoading = false
        messages.append(AgentChatMessage(role: .system, text: "已停止生成。"))
    }

    private func handleActions(_ actions: [AgentAction]) {
        var items = actions
        if items.isEmpty { return }
        if !config.allowActionQueue { items = Array(items.prefix(1)) }
        items = Array(items.prefix(max(1, config.maxQueueActions)))
        if !config.allowRobotControl {
            messages.append(AgentChatMessage(role: .system, text: "Agent 控车已关闭，仅保留问答能力。"))
            return
        }
        let needsConfirm = config.alwaysConfirmActions || items.count > 1 || items.contains { $0.requiresConfirmation || $0.name != "stop" }
        if needsConfirm {
            pendingQueue = AgentActionQueue(actions: items, requiresConfirmation: true)
            toolEvents = items.map { AgentToolCallEvent(id: $0.id, actionName: $0.name, detail: describe($0), status: .planned, result: nil) }
            messages.append(AgentChatMessage(role: .system, text: "已生成动作计划：\n\(describe(items))"))
        } else {
            execute(items)
        }
    }

    func confirmPendingAction() { confirmPendingQueue() }

    func confirmPendingQueue() {
        guard let queue = pendingQueue else { return }
        pendingQueue = nil
        execute(queue.actions)
    }

    func cancelPendingAction() { cancelPendingQueue() }

    func cancelPendingQueue() {
        for event in toolEvents where event.status == .planned { updateToolEvent(event.id, status: .skipped, result: "用户取消执行。") }
        pendingQueue = nil
        messages.append(AgentChatMessage(role: .system, text: "已取消执行。"))
    }

    private func execute(_ actions: [AgentAction]) {
        guard !actions.isEmpty else { return }
        isExecuting = true
        if toolEvents.map(\.id) != actions.map(\.id) {
            toolEvents = actions.map { AgentToolCallEvent(id: $0.id, actionName: $0.name, detail: describe($0), status: .planned, result: nil) }
        }
        executionTask?.cancel()
        executionTask = Task {
            for (index, action) in actions.enumerated() {
                await MainActor.run {
                    let idx = index + 1
                    self.updateToolEvent(action.id, status: .running, result: nil)
                    self.messages.append(AgentChatMessage(role: .system, text: "执行第 \(idx)/\(actions.count) 步：\(self.describe(action))"))
                }
                if Task.isCancelled { break }
                let result = await toolExecutor?.execute(action, config: config) ?? "工具执行器未就绪。"
                let shouldStop = result.contains("拒绝") || result.contains("未在线") || result.contains("不支持")
                await MainActor.run {
                    self.updateToolEvent(action.id, status: shouldStop ? .skipped : .succeeded, result: result)
                    self.messages.append(AgentChatMessage(role: .system, text: result))
                    if shouldStop {
                        let remaining = actions.dropFirst(index + 1)
                        for item in remaining { self.updateToolEvent(item.id, status: .skipped, result: "前序步骤中止，未执行。") }
                    }
                }
                if shouldStop { break }
                if index < actions.count - 1 { try? await Task.sleep(nanoseconds: 250_000_000) }
            }
            await MainActor.run { self.isExecuting = false; self.executionTask = nil }
        }
    }

    func stopExecutionQueue() {
        executionTask?.cancel()
        executionTask = nil
        isExecuting = false
        robot?.stop()
        for event in toolEvents where event.status == .planned || event.status == .running {
            updateToolEvent(event.id, status: .skipped, result: "用户停止执行队列。")
        }
        messages.append(AgentChatMessage(role: .system, text: "已停止执行队列，并发送停止命令。"))
    }

    private func updateToolEvent(_ id: UUID, status: AgentToolCallEvent.Status, result: String?) {
        guard let idx = toolEvents.firstIndex(where: { $0.id == id }) else { return }
        var updated = toolEvents[idx]
        updated.status = status
        if let result { updated.result = result }
        toolEvents[idx] = updated
    }

    private func visibleStreamingText(_ raw: String) -> String {
        if let replyRange = raw.range(of: "\"reply\"") ?? raw.range(of: "'reply'") {
            let tail = raw[replyRange.upperBound...]
            if let colon = tail.firstIndex(of: ":") {
                var value = String(tail[tail.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("\"") || value.hasPrefix("'") { value.removeFirst() }
                if let end = value.firstIndex(where: { $0 == "\"" || $0 == "'" }) { value = String(value[..<end]) }
                return value.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\"", with: "\"")
            }
        }
        if raw.contains("{") || raw.contains("\"actions\"") || raw.contains("\"action\"") { return "正在思考并规划动作…" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodePlan(from content: String) throws -> AgentPlan {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), let plan = try? JSONDecoder().decode(AgentPlan.self, from: data) { return plan }
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            let json = String(trimmed[start...end])
            if let data = json.data(using: .utf8) { return try JSONDecoder().decode(AgentPlan.self, from: data) }
        }
        return AgentPlan(reply: content, action: nil, actions: nil)
    }

    private func buildMessages(userText: String) -> [OpenAIChatRequest.Message] {
        [.init(role: "system", content: systemPrompt), .init(role: "system", content: "当前机器人状态摘要：\n\(robotSummary())"), .init(role: "user", content: userText)]
    }

    private var systemPrompt: String {
        """
        你是 ROS Car App 内的智能助手。你必须只返回 JSON，不要返回 Markdown。
        JSON 格式：{"reply":"给用户看的中文回复","actions":[{"name":"动作名","requires_confirmation":true,"parameters":{"key":"value"}}]}
        如果只需要回答问题，actions 为空数组或省略。兼容旧字段 action，但优先使用 actions。
        可用动作：stop, move_forward_short, move_backward_short, move_front_right_short, move_front_left_short, turn_left_short, turn_right_short, start_auto_explore, stop_auto_explore, save_map, reset_map。
        当前 Agent 控车开关：\(config.allowRobotControl ? "开启" : "关闭")。如果关闭，不要生成 actions，只做状态解释和建议。
        你可以把复合指令拆成最多 \(config.maxQueueActions) 个短动作。例如“先右转一点再前进一点”返回两个 actions。
        当前只支持短动作近似执行，不支持精确距离/角度闭环。遇到“前进一米/转三圈/移动两米”等长距离长时间指令，应明确说明当前只能拆成安全短动作近似，动作总数不要超过限制。
        移动动作参数：speed_mps<=\(config.maxLinearSpeed)，angular_rps<=\(config.maxAngularSpeed)，duration_s<=\(config.maxActionDuration)。除 stop 外所有动作 requires_confirmation 必须为 true。
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

    func describe(_ actions: [AgentAction]) -> String {
        actions.enumerated().map { "\($0.offset + 1). \(describe($0.element))" }.joined(separator: "\n")
    }

    var statusLine: String {
        guard let robot else { return "未绑定机器人" }
        return "\(robot.connectionStatus) · \(robot.robotOnline ? "小车在线" : "小车离线") · \(config.model.isEmpty ? "未选模型" : config.model)"
    }
}
