import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            DashboardView().tabItem { Label("总览", systemImage: "square.grid.2x2") }.tag(0)
            ControlView().tabItem { Label("控制", systemImage: "gamecontroller") }.tag(1)
            MapView().tabItem { Label("地图", systemImage: "map") }.tag(2)
            TasksView().tabItem { Label("任务", systemImage: "checklist") }.tag(3)
            AgentView().tabItem { Label("助手", systemImage: "sparkles") }.tag(4)
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(5)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var model: RobotViewModel
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
            .toolbar { EmergencyStopToolbar() }
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
        VStack(spacing: 0) {
            if let state = model.state {
                InteractiveRobotMap(state: state) { x, y in model.setGoal(x: x, y: y) }
                    .frame(height: 285)
                    .padding()
            } else {
                ContentUnavailableView("等待地图", systemImage: "map", description: Text("连接服务器后显示小车位置")).frame(height: 285)
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
            }.padding()
            HStack(spacing: 14) {
                Button(model.state?.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                Button("重置") { model.reset() }
            }.buttonStyle(.bordered)
        }
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
                Section("日志") { ForEach(model.log, id: \.self) { Text($0).font(.caption.monospaced()) } }
            }.navigationTitle("设置").onAppear { urlText = model.serverURLString }
            .toolbar { EmergencyStopToolbar() }
        }
    }
}
