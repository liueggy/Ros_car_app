import SwiftUI

struct AgentView: View {
    @EnvironmentObject var robot: RobotViewModel
    @StateObject private var agent = AgentViewModel()
    @State private var showingSettings = false

    private let quickPrompts = ["小车现在状态如何？", "为什么现在不能动？", "向前走一点", "右转一点", "开始自动探索", "保存当前地图"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if agent.isLoading {
                        Button("停止生成") { agent.stopGenerating() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(.orange)
                    }
                    if agent.isExecuting {
                        Button("停止队列") { agent.stopExecutionQueue() }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                AgentStatusHeader(agent: agent, robot: robot)
                if agent.config.apiKey.isEmpty || agent.config.model.isEmpty {
                    AgentSetupHint { showingSettings = true }
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            quickPromptBar
                            ForEach(agent.messages) { message in AgentBubble(message: message).id(message.id) }
                            if !agent.streamingPreview.isEmpty {
                                AgentBubble(message: AgentChatMessage(role: .assistant, text: agent.streamingPreview))
                                    .id("streaming-preview")
                            }
                            if !agent.toolEvents.isEmpty { AgentToolTimelineView(events: agent.toolEvents) }
                        }
                        .padding()
                    }
                    .onChange(of: agent.scrollAnchor) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            if !agent.streamingPreview.isEmpty {
                                proxy.scrollTo("streaming-preview", anchor: .bottom)
                            } else if let last = agent.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                if let queue = agent.pendingQueue { AgentActionPlanCard(agent: agent, queue: queue) }
                inputBar
            }
            .navigationTitle("助手")
            .toolbar {
                EmergencyStopToolbar()
                ToolbarItem(placement: .topBarTrailing) { Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") } }
            }
            .sheet(isPresented: $showingSettings) { AgentSettingsView(agent: agent) }
            .onAppear { agent.bind(robot: robot) }
        }
    }

    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) { agent.useQuickPrompt(prompt) }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .disabled(agent.isLoading || agent.isExecuting)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 6) {
            TextField("问问小车状态，或输入一个安全短动作…", text: $agent.input)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit { if canSend { agent.send() } }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemBackground)))
            Button(action: { agent.send() }) {
                if agent.isLoading {
                    ProgressView().frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(width: 32, height: 32)
            .background(canSend ? Color.blue : Color.gray.opacity(0.25))
            .foregroundStyle(.white)
            .clipShape(Circle())
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !agent.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !agent.isLoading && !agent.isExecuting
    }
}

struct AgentSetupHint: View {
    var openSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("先完成模型设置")
                    .font(.subheadline.weight(.semibold))
                Text("填写 Base URL、API Key 并选择模型后，助手才能回答和规划动作。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("设置", action: openSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.orange.opacity(0.25)))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct AgentToolTimelineView: View {
    let events: [AgentToolCallEvent]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("工具调用", systemImage: "wrench.and.screwdriver")
                .font(.headline)
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(for: event.status))
                        .foregroundStyle(color(for: event.status))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(event.actionName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(event.status.rawValue).font(.caption).foregroundStyle(color(for: event.status))
                        }
                        Text(event.detail).font(.caption).foregroundStyle(.secondary)
                        if let result = event.result { Text(result).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .padding(12)
        .background(.blue.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.blue.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func icon(for status: AgentToolCallEvent.Status) -> String {
        switch status { case .planned: return "circle"; case .running: return "play.circle.fill"; case .succeeded: return "checkmark.circle.fill"; case .skipped: return "exclamationmark.circle.fill" }
    }

    private func color(for status: AgentToolCallEvent.Status) -> Color {
        switch status { case .planned: return .secondary; case .running: return .blue; case .succeeded: return .green; case .skipped: return .orange }
    }
}

struct AgentStatusHeader: View {
    @ObservedObject var agent: AgentViewModel
    @ObservedObject var robot: RobotViewModel
    var body: some View {
        HStack(spacing: 10) {
            Label(robot.connectionStatus, systemImage: robot.robotOnline ? "checkmark.circle.fill" : "wifi.slash")
                .foregroundStyle(robot.robotOnline ? .green : .orange)
            Divider().frame(height: 18)
            Label(agent.config.model.isEmpty ? "未选择模型" : agent.config.model, systemImage: "cpu")
                .lineLimit(1)
                .foregroundStyle(agent.config.model.isEmpty ? .orange : .secondary)
            Spacer()
            if !agent.config.allowRobotControl {
                Label("只读", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            } else if agent.isExecuting {
                Label("执行中", systemImage: "play.circle.fill")
                    .foregroundStyle(.blue)
            } else if agent.pendingQueue != nil {
                Label("待确认", systemImage: "checklist")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

struct AgentActionPlanCard: View {
    @ObservedObject var agent: AgentViewModel
    let queue: AgentActionQueue
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(queue.title, systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Text("需确认").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(queue.actions.enumerated()), id: \.element.id) { index, action in
                    HStack(alignment: .top) {
                        Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
                        Text(agent.describe(action)).font(.footnote).lineLimit(2)
                    }
                }
            }
            HStack {
                Button("取消") { agent.cancelPendingQueue() }.buttonStyle(.bordered)
                Spacer()
                Button("确认执行") { agent.confirmPendingQueue() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.yellow.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.yellow.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct AgentBubble: View {
    let message: AgentChatMessage
    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 42) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.caption)
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(message.text).font(.body).textSelection(.enabled)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(borderColor))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            if message.role != .user { Spacer(minLength: 42) }
        }
    }

    private var title: String {
        switch message.role { case .user: return "你"; case .assistant: return "助手"; case .system: return "系统" }
    }

    private var icon: String {
        switch message.role { case .user: return "person.fill"; case .assistant: return "sparkles"; case .system: return "gearshape.fill" }
    }

    private var background: Color {
        switch message.role { case .user: return .blue.opacity(0.16); case .assistant: return .gray.opacity(0.12); case .system: return .orange.opacity(0.13) }
    }

    private var borderColor: Color {
        switch message.role { case .user: return .blue.opacity(0.10); case .assistant: return .gray.opacity(0.10); case .system: return .orange.opacity(0.18) }
    }
}

struct AgentSettingsView: View {
    @ObservedObject var agent: AgentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI-Compatible API") {
                    TextField("Base URL", text: $agent.config.baseURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    SecureField("API Key", text: $agent.config.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("自动获取模型列表") { agent.fetchModels() }
                    if !agent.modelFetchStatus.isEmpty { Text(agent.modelFetchStatus).font(.caption).foregroundStyle(.secondary) }
                    if !agent.availableModels.isEmpty {
                        Picker("模型", selection: $agent.config.model) {
                            ForEach(agent.availableModels, id: \.self) { Text($0).tag($0) }
                        }
                        .onChange(of: agent.config.model) { _, _ in agent.saveConfig() }
                    }
                    TextField("模型名（可手动输入）", text: $agent.config.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Slider(value: $agent.config.temperature, in: 0...1, step: 0.1) { Text("Temperature") }
                    LabeledContent("Temperature", value: String(format: "%.1f", agent.config.temperature))
                }
                Section("动作与确认") {
                    if agent.config.allowRobotControl {
                        Label("控车已开启：除停止外，移动/探索等动作仍会按确认和安全限制执行。", systemImage: "shield.checkered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("当前是只读助手：只回答状态和建议，不会控制小车。", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("允许 Agent 控制小车", isOn: $agent.config.allowRobotControl)
                    Toggle("流式输出回答", isOn: $agent.config.streamResponses)
                    Toggle("始终确认动作", isOn: $agent.config.alwaysConfirmActions)
                    Toggle("允许动作队列", isOn: $agent.config.allowActionQueue)
                    Stepper("最多 \(agent.config.maxQueueActions) 步", value: $agent.config.maxQueueActions, in: 1...10)
                }
                Section("安全限制") {
                    Slider(value: $agent.config.maxLinearSpeed, in: 0.05...0.25, step: 0.01) { Text("最大线速度") }
                    LabeledContent("最大线速度", value: String(format: "%.2f m/s", agent.config.maxLinearSpeed))
                    Slider(value: $agent.config.maxAngularSpeed, in: 0.15...0.70, step: 0.05) { Text("最大角速度") }
                    LabeledContent("最大角速度", value: String(format: "%.2f rad/s", agent.config.maxAngularSpeed))
                    Slider(value: $agent.config.maxActionDuration, in: 0.3...3.0, step: 0.1) { Text("单步最长时间") }
                    LabeledContent("单步最长时间", value: String(format: "%.1f s", agent.config.maxActionDuration))
                    Slider(value: $agent.config.obstacleStopDistance, in: 0.30...1.20, step: 0.05) { Text("前方避障阈值") }
                    LabeledContent("前方避障阈值", value: String(format: "%.2f m", agent.config.obstacleStopDistance))
                }
                Section("说明") {
                    Text("API Key 仅保存在本机，用于 App 直接请求模型服务商，不会发送到 ROS 中转服务器。当前动作队列是安全短动作近似，不是精确距离/角度闭环。")
                }
            }
            .navigationTitle("Agent 设置")
            .onDisappear { agent.saveConfig() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("保存") { agent.saveConfig(); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
