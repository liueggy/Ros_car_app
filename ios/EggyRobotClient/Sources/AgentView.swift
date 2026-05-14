import SwiftUI

struct AgentView: View {
    @EnvironmentObject var robot: RobotViewModel
    @StateObject private var agent = AgentViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(agent.messages) { message in
                                AgentBubble(message: message).id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: agent.messages.count) { _, _ in
                        if let last = agent.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                if let pending = agent.pendingAction {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("需要确认").font(.caption).foregroundStyle(.secondary)
                            Text(agent.describe(pending)).font(.footnote).lineLimit(2)
                        }
                        Spacer()
                        Button("取消") { agent.cancelPendingAction() }.buttonStyle(.bordered)
                        Button("确认执行") { agent.confirmPendingAction() }.buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.yellow.opacity(0.12))
                }
                HStack(spacing: 10) {
                    TextField("和助手对话，例如：小车现在状态如何？", text: $agent.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button { agent.send() } label: {
                        if agent.isLoading { ProgressView() } else { Image(systemName: "paperplane.fill") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(agent.isLoading || agent.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
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
}

struct AgentBubble: View {
    let message: AgentChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.rawValue).font(.caption).foregroundStyle(.secondary)
                Text(message.text).font(.body)
            }
            .padding(12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if message.role != .user { Spacer(minLength: 42) }
        }
    }

    private var background: Color {
        switch message.role {
        case .user: return .blue.opacity(0.16)
        case .assistant: return .gray.opacity(0.12)
        case .system: return .orange.opacity(0.13)
        }
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
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("API Key", text: $agent.config.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("自动获取模型列表") { agent.fetchModels() }
                    if !agent.modelFetchStatus.isEmpty { Text(agent.modelFetchStatus).font(.caption).foregroundStyle(.secondary) }
                    if !agent.availableModels.isEmpty {
                        Picker("模型", selection: $agent.config.model) {
                        ForEach(agent.availableModels, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: agent.config.model) { _, _ in agent.saveConfig() }
                    }
                    TextField("模型名（可手动输入）", text: $agent.config.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("安全策略") {
                    Label("除急停外，所有动作都会先确认", systemImage: "checkmark.shield")
                    Label("短动作限速、限时，并自动停止", systemImage: "timer")
                    Label("前方障碍过近会拒绝前进", systemImage: "exclamationmark.triangle")
                }
                Section("说明") {
                    Text("API Key 仅保存在本机，用于 App 直接请求模型服务商，不会发送到 ROS 中转服务器。")
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
