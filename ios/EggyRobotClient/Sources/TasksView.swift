import SwiftUI

struct TasksView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mapName = "导航地图"

    var body: some View {
        NavigationStack {
            List {
                if !canOperate {
                    Section { InlineNotice("小车未在线或连接不可发送，任务操作会暂时禁用。", systemImage: "wifi.slash", color: .orange) }
                }

                Section("建图 / 保存 / 导航流程") {
                    statusRow
                    Button {
                        model.startMapping()
                    } label: {
                        Label("1. 开始建图", systemImage: "map")
                    }
                    .disabled(!canOperate)

                    HStack {
                        TextField("导航地图名称", text: $mapName)
                        Button("2. 保存导航地图") {
                            model.saveNavigationMap(name: mapName.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        .disabled(!canOperate || mapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button {
                        model.startQuickDirectNavigation()
                    } label: {
                        Label("3. 开启快速直达", systemImage: "location.north.line")
                    }
                    .disabled(!canOperate)

                    Button(role: .destructive) {
                        model.stopNavigation()
                    } label: {
                        Label("4. 停止导航", systemImage: "stop.circle")
                    }
                    .disabled(!model.phase.canSend)

                    Text("开启快速直达后，回到总览/控制地图点击目标点：App 会发送 simple_goal，小车先快速旋转对准，再直行到目标。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("高级") {
                    Button("停止建图") { model.stopMapping() }
                        .disabled(!model.phase.canSend)
                    Button("开启 move_base 导航") { model.startMoveBaseNavigation() }
                        .disabled(!canOperate)
                    Button(model.state?.system.autoExplore == true ? "停止自动探索" : "开始自动探索") { model.toggleExplore() }
                        .disabled(!canOperate)
                    Button("重置", role: .destructive) { model.reset() }
                        .disabled(!model.phase.canSend)
                }

                Section("云端地图快照") {
                    HStack {
                        TextField("快照名称", text: $mapName)
                        Button("保存快照") { model.saveMap(name: mapName) }
                            .disabled(!model.phase.canSend || mapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if (model.state?.savedMaps ?? []).isEmpty {
                        Text("暂无已保存快照").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.state?.savedMaps ?? []) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(String(format: "已探索 %.1f%%", item.stats?.knownPercent ?? 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("加载") { model.loadMap(id: item.id) }
                                    .disabled(!model.phase.canSend)
                            }
                        }
                    }
                }
            }
            .navigationTitle("任务")
            .toolbar { EmergencyStopToolbar() }
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("当前模式：\(model.navigationMode.title)")
                .font(.headline)
            Text("simple_nav：\(model.state?.system.simpleNavStatus ?? "未知")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var canOperate: Bool { model.phase.canSend && model.robotOnline }
}
