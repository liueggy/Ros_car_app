import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            DashboardView().tabItem { Label("总览", systemImage: "gauge.with.dots.needle.bottom.50percent") }.tag(0)
            MapView().tabItem { Label("地图", systemImage: "map") }.tag(1)
            ControlView().tabItem { Label("控制", systemImage: "gamecontroller") }.tag(2)
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(3)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var model: RobotViewModel
    var body: some View {
        NavigationStack {
            List {
                Section("连接") {
                    LabeledContent("状态", value: model.connectionStatus)
                    LabeledContent("服务器", value: model.state?.system.server ?? "-")
                    LabeledContent("场景", value: model.state?.system.sceneName ?? "-")
                }
                Section("机器人") {
                    LabeledContent("导航", value: model.state?.navStatus ?? "-")
                    LabeledContent("电池", value: model.state.map { "\($0.battery.percent)% / " + String(format: "%.2fV", $0.battery.voltage) } ?? "-")
                    LabeledContent("前方距离", value: model.state.map { String(format: "%.2f m", $0.summary.front) } ?? "-")
                    LabeledContent("最近障碍", value: model.state.map { String(format: "%.2f m", $0.summary.nearest) } ?? "-")
                }
                Section("建图") {
                    LabeledContent("已探索", value: model.state?.occupancyGrid.map { String(format: "%.1f%%", $0.stats.knownPercent) } ?? "-")
                    LabeledContent("空闲格", value: model.state?.occupancyGrid.map { "\($0.stats.free)" } ?? "-")
                    LabeledContent("障碍格", value: model.state?.occupancyGrid.map { "\($0.stats.occupied)" } ?? "-")
                }
            }
            .navigationTitle("Eggy 机器人")
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var speed = 0.18
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemBackground))
                    if let state = model.state {
                        InteractiveRobotMap(state: state) { x, y in model.setGoal(x: x, y: y) }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(state.system.sceneName ?? "实时地图")")
                            Text(String(format: "位置 %.2f, %.2f", state.robot.x, state.robot.y))
                            Text(String(format: "已探索 %.1f%%", state.occupancyGrid?.stats.knownPercent ?? 0))
                        }
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(10)
                    } else {
                        ContentUnavailableView("等待地图", systemImage: "map", description: Text("连接服务器后显示小车位置"))
                    }
                }
                .frame(height: 300)
                .padding()

                VStack(spacing: 14) {
                    HStack {
                        Text("速度")
                        Slider(value: $speed, in: 0.06...0.35)
                        Text(String(format: "%.2f", speed)).monospacedDigit().frame(width: 46, alignment: .trailing)
                    }
                    .font(.caption)
                    .padding(.horizontal)

                    HStack(spacing: 24) {
                        JoystickControl(speed: speed, onCommand: { x, y, z in model.cmd(x: x, y: y, z: z) }, onStop: { model.stop() })
                        VStack(spacing: 12) {
                            Button("左转") { model.cmd(x: 0, y: 0, z: 0.45) }
                            Button("停止") { model.stop() }.tint(.red)
                            Button("右转") { model.cmd(x: 0, y: 0, z: -0.45) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    HStack(spacing: 14) {
                        Button(model.state?.system.autoExplore == true ? "停止自动探索" : "自动探索") { model.toggleExplore() }
                        Button("重置") { model.reset() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom)
                Spacer(minLength: 0)
            }
            .navigationTitle("控制小车")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var urlText = ""
    @State private var mapName = "探索地图"
    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("WebSocket 地址", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("重新连接") { model.serverURLString = urlText; model.connect() }
                }
                Section("预设场景") {
                    ForEach(model.state?.scenes ?? []) { scene in
                        Button(scene.name) { model.setScene(scene.id) }
                    }
                }
                Section("地图") {
                    TextField("地图名称", text: $mapName)
                    Button("保存当前地图") { model.saveMap(name: mapName) }
                    ForEach(model.state?.savedMaps ?? []) { item in
                        HStack {
                            VStack(alignment: .leading) { Text(item.name); Text(String(format: "已探索 %.1f%%", item.stats?.knownPercent ?? 0)).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button("加载") { model.loadMap(id: item.id) }
                        }
                    }
                }
                Section("日志") { ForEach(model.log, id: \.self) { Text($0).font(.caption.monospaced()) } }
            }
            .navigationTitle("设置")
            .onAppear { urlText = model.serverURLString }
        }
    }
}
