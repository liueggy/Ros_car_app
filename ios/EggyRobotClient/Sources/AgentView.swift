import SwiftUI

struct AgentView: View {
    @EnvironmentObject var robot: RobotViewModel
    @StateObject private var agent = AgentViewModel()
    @State private var showingSettings = false

    private let quickPrompts = ["小车现在状态如何？", "为什么现在不能动？", "向前走一点", "右转一点", "开始自动探索", "保存当前地图"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AgentStatusHeader(agent: agent, robot: robot)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            quickPromptBar
                            ForEach(agent.messages) { message in AgentBubble(message: message).id(message.id) }
                        }
                        .padding()
                    }
                    .onChange(of: agent.messages.count) { _, _ in
                        if let last = agent.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                TextField("和助手对话，例如：先右转一点再前进一点", text: $agent.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
            }
            Button { agent.send() } label: {
                if agent.isLoading { ProgressView().frame(width: 20, height: 20) } else { Image(systemName: "arrow.up") }
            }
            .font(.headline)
            .frame(width: 44, height: 44)
            .background(agent.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agent.isLoading || agent.isExecuting ? Color.gray.opacity(0.25) : Color.blue)
            .foregroundStyle(.white)
            .clipShape(Circle())
            .disabled(agent.isLoading || agent.isExecuting || agent.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
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
            Text(agent.config.model.isEmpty ? "未选择模型" : agent.config.model)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            if agent.isExecuting { Label("执行中", systemImage: "play.circle.fill").foregroundStyle(.blue) }
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
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.caption)
                    Text(message.role.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Text(message.text).font(.body).textSelection(.enabled)
            }
            .padding(12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if message.role != .user { Spacer(minLength: 42) }
        }
    }

    private var icon: String {
        switch message.role { case .user: return "person.fill"; case .assistant: return "sparkles"; case .system: return "gearshape.fill" }
    }

    private var background: Color {
        switch message.role { case .user: return .blue.opacity(0.16); case .assistant: return .gray.opacity(0.12); case .system: return .orange.opacity(0.13) }
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("保存") { agent.saveConfig(); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
