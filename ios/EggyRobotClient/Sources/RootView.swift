import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var tab = 0
    @State private var showingSettings = false
    var body: some View {
        TabView(selection: $tab) {
            DashboardView(showingSettings: $showingSettings).tabItem { Label("总览", systemImage: "square.grid.2x2") }.tag(0)
            ControlView().tabItem { Label("控制", systemImage: "gamecontroller") }.tag(1)
            TasksView().tabItem { Label("任务", systemImage: "checklist") }.tag(2)
            AgentView().tabItem { Label("助手", systemImage: "sparkles") }.tag(3)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
}

struct DashboardView: View {
    @EnvironmentObject var model: RobotViewModel
    @Binding var showingSettings: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let s = model.state {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            MetricCard(title: "连接", value: model.connectionStatus, subtitle: s.system.robotConnected == true ? (s.system.robotId ?? "eggy-001") : "robot offline", color: model.robotOnline ? .green : .orange)
                            MetricCard(title: "电池", value: s.battery.percent.map { "\($0)%" } ?? "--", subtitle: s.battery.voltage.map { String(format: "%.2f V", $0) } ?? "--", color: .blue)
                            MetricCard(title: "导航", value: s.navStatus, subtitle: s.system.streamMode ?? s.system.mode ?? "relay", color: .purple)
                            MetricCard(title: "前方", value: s.summary.front.map { String(format: "%.2f m", $0) } ?? "--", subtitle: "最近障碍 " + (s.summary.nearest.map { String(format: "%.2f m", $0) } ?? "--"), color: .cyan)
                            MetricCard(title: "建图", value: String(format: "%.1f%%", s.occupancyGrid?.stats.knownPercent ?? 0), subtitle: "空闲 \(s.occupancyGrid?.stats.free ?? 0) / 障碍 \(s.occupancyGrid?.stats.occupied ?? 0)", color: .indigo)
                            MetricCard(title: "位置", value: String(format: "%.1f, %.1f", s.robot.x, s.robot.y), subtitle: String(format: "yaw %.0f°", s.robot.yaw * 180 / .pi), color: .teal)
                        }
                        InteractiveRobotMap(state: s) { x, y in model.setGoal(x: x, y: y) }
                            .frame(height: 260)
                    } else {
                        ContentUnavailableView("等待服务器数据", systemImage: "wifi", description: Text(model.connectionStatus))
                    }
                }.padding()
            }
            .navigationTitle("ROS Car")
            .toolbar {
                EmergencyStopToolbar()
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mode: SpeedMode = .normal
    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                controlContent
                ScrollView { controlContent }
            }
            .navigationTitle("控制")
            .toolbar { EmergencyStopToolbar() }
        }
    }

    @ViewBuilder
    private var controlContent: some View {
        VStack(spacing: 14) {
            if let state = model.state {
                RobotStatusStrip(state: state, model: model)
                    .padding(.horizontal)
                    .padding(.top, 12)
                InteractiveRobotMap(state: state) { x, y in model.setGoal(x: x, y: y) }
                    .frame(height: 285)
                    .padding(.horizontal)
            } else {
                ContentUnavailableView("等待地图", systemImage: "map", description: Text("连接服务器后显示小车位置"))
                    .frame(height: 285)
                    .padding(.top, 12)
            }
            Picker("速度模式", selection: $mode) { ForEach(SpeedMode.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            HStack(spacing: 24) {
                JoystickControl(speed: mode.maxSpeed, onCommand: { x, y, _ in model.cmd(x: x, y: y, z: 0) }, onStop: { model.stop() })
                VStack(spacing: 12) {
                    Button("左转") { model.cmd(x: 0, y: 0, z: 0.45) }
                    Button("急停") { model.stop() }.tint(.red).buttonStyle(.borderedProminent)
                    Button("右转") { model.cmd(x: 0, y: 0, z: -0.45) }
                }.buttonStyle(.bordered).controlSize(.large)
            }.padding(.horizontal)
            HStack(spacing: 14) {
                Button(model.state?.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                Button("重置") { model.reset() }
            }.buttonStyle(.bordered)
            Text("提示：摇杆松手会自动停止；急停按钮始终可用。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }
}

struct RobotStatusStrip: View {
    let state: NavViewMessage
    @ObservedObject var model: RobotViewModel

    var body: some View {
        HStack(spacing: 8) {
            statusItem("连接", model.connectionStatus, model.robotOnline ? .green : .orange)
            statusItem("前方", state.summary.front.map { String(format: "%.2fm", $0) } ?? "--", .cyan)
            statusItem("电池", state.battery.percent.map { "\($0)%" } ?? "--", .blue)
        }
    }

    private func statusItem(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TasksView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mapName = "探索地图"
    var body: some View {
        NavigationStack {
            List {
                Section("任务") {
                    Button(model.state?.system.autoExplore == true ? "停止自动探索" : "开始自动探索") { model.toggleExplore() }
                    Button("重置并重新建图") { model.reset() }
                    HStack { TextField("地图名称", text: $mapName); Button("保存") { model.saveMap(name: mapName) } }
                }
                Section("预设场景") { ForEach(model.state?.scenes ?? []) { scene in Button(scene.name) { model.setScene(scene.id) } } }
                Section("已保存地图") {
                    ForEach(model.state?.savedMaps ?? []) { item in
                        HStack {
                            VStack(alignment: .leading) { Text(item.name); Text(String(format: "已探索 %.1f%%", item.stats?.knownPercent ?? 0)).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Button("加载") { model.loadMap(id: item.id) }
                        }
                    }
                }
            }.navigationTitle("任务")
            .toolbar { EmergencyStopToolbar() }
        }
    }
}

struct LogDetailView: View {
    let logs: [String]
    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(logs, id: \.self) { item in
                    Text(item).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("日志")
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var urlText = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("WebSocket 地址", text: $urlText).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("重新连接") { model.serverURLString = urlText; model.connect() }
                    Button("使用默认 wss://liueggy.live/ws") { urlText = RobotViewModel.defaultServerURL; model.serverURLString = urlText; model.connect() }
                    LabeledContent("连接状态", value: model.connectionStatus)
                    LabeledContent("服务器", value: model.serverHost)
                    LabeledContent("机器人", value: model.state?.system.robotConnected == true ? (model.state?.system.robotId ?? "在线") : "离线")
                    LabeledContent("ROS", value: model.state?.system.ros == true ? "正常" : "异常/未知")
                    LabeledContent("数据延迟", value: model.dataAge.map { String(format: "%.1fs", $0) } ?? "--")
                    LabeledContent("流模式", value: model.state?.system.streamMode ?? "--")
                }
                NavigationLink {
                    LogDetailView(logs: model.log)
                } label: {
                    LabeledContent("日志", value: "\(model.log.count) 条")
                }
            }.navigationTitle("设置").onAppear { urlText = model.serverURLString }
            .toolbar { EmergencyStopToolbar() }
        }
    }
}
