import SwiftUI

struct TasksView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mapName = "探索地图"

    var body: some View {
        NavigationStack {
            List {
                if !canDrive {
                    Section { InlineNotice("小车未在线或连接不可发送，任务操作会暂时禁用。", systemImage: "wifi.slash", color: .orange) }
                }
                Section("探索与建图") {
                    Button(model.state?.system.autoExplore == true ? "停止自动探索" : "开始自动探索") { model.toggleExplore() }
                        .disabled(!canDrive)
                    Button("重置并重新建图", role: .destructive) { model.reset() }
                        .disabled(!model.phase.canSend)
                    HStack {
                        TextField("地图名称", text: $mapName)
                        Button("保存") { model.saveMap(name: mapName) }
                            .disabled(!model.phase.canSend || mapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("预设场景") {
                    if (model.state?.scenes ?? []).isEmpty {
                        Text("暂无预设场景").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.state?.scenes ?? []) { scene in
                            Button(scene.name) { model.setScene(scene.id) }
                                .disabled(!model.phase.canSend)
                        }
                    }
                }
                Section("已保存地图") {
                    if (model.state?.savedMaps ?? []).isEmpty {
                        Text("暂无已保存地图").foregroundStyle(.secondary)
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

    private var canDrive: Bool { model.phase.canSend && model.robotOnline }
}
