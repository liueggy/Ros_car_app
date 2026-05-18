import SwiftUI

struct TasksView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mapName = "导航地图"

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    if !canOperate {
                        InlineNotice("小车未在线或连接不可发送，任务操作会暂时禁用。", systemImage: "wifi.slash", color: .orange)
                            .padding(.horizontal)
                    }

                    navFlowSection

                    Divider().padding(.horizontal)

                    advancedSection

                    Divider().padding(.horizontal)

                    cloudMapSection
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("任务")
            .toolbar { EmergencyStopToolbar() }
        }
    }

    private var navFlowSection: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(canOperate ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text("建图 / 保存 / 导航流程").font(.headline)
                Spacer()
                Text(model.navigationMode.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if let status = model.state?.system.simpleNavStatus, !status.isEmpty, status != "idle" {
                navStatusBanner(status)
            }

            VStack(spacing: 0) {
                flowButton(icon: "map", label: "1.  开始建图", desc: "启动地图流和建图节点，手动开车扫图。") { model.startMapping() }
                Divider().padding(.leading, 52)
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down").foregroundStyle(.tint).frame(width: 20)
                    TextField("保存为导航地图", text: $mapName)
                        .font(.subheadline)
                    Button("保存") { model.saveNavigationMap(name: mapName.trimmingCharacters(in: .whitespaces)) }
                        .font(.subheadline.weight(.semibold))
                        .disabled(!canOperate || mapName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .padding(.horizontal, 2)
                Divider().padding(.leading, 52)
                flowButton(icon: "location.north.line", label: "3.  开启快速直达", desc: "先快速旋转对准目标，再直行到目标点。") { model.startQuickDirectNavigation() }
                Divider().padding(.leading, 52)
                flowButton(icon: "stop.circle", label: "4.  停止导航", desc: "取消目标、停止导航并清零速度。", role: .destructive) { model.stopNavigation() }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)

            Text("开启快速直达后，回到总览/控制页在地图上点击目标点，App 会发送 simple_goal。")
                .font(.caption2).foregroundStyle(.tertiary).padding(.top, 6).padding(.horizontal, 16)
        }
    }

    private func navStatusBanner(_ status: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond").font(.caption)
            Text("快速导航状态：\(statusDisplay(status))")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.accentColor, in: Capsule())
        .padding(.horizontal, 16).padding(.bottom, 6)
    }

    private func statusDisplay(_ raw: String) -> String {
        let parts = raw.components(separatedBy: " ")
        switch parts.first ?? "" {
        case "idle": return "待机"
        case "rotating": return "正在旋转对准"
        case "driving": return "正在直行"
        case "arrived": return "已到达"
        case "blocked": return "前方障碍暂停"
        case "cancelled": return "已取消"
        default: return raw
        }
    }

    private func flowButton(icon: String, label: String, desc: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).frame(width: 24)
                    .foregroundStyle(role == .destructive ? .red : .accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.subheadline.weight(.semibold))
                    Text(desc).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.quaternary)
            }
            .padding(12)
        }
        .disabled(!canOperate)
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
    }

    private var advancedSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "gearshape.2").font(.caption).foregroundStyle(.secondary)
                Text("高级").font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            VStack(spacing: 0) {
                rowButton("停止建图", icon: "mappin.slash") { model.stopMapping() }
                Divider().padding(.leading, 44)
                rowButton("开启 move_base 导航", icon: "map") { model.startMoveBaseNavigation() }
                Divider().padding(.leading, 44)
                rowButton(model.state?.system.autoExplore == true ? "停止自动探索" : "开始自动探索", icon: "scope") { model.toggleExplore() }
                Divider().padding(.leading, 44)
                rowButton("重置地图", icon: "arrow.counterclockwise", role: .destructive) { model.reset() }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
        }
    }

    private func rowButton(_ label: String, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.subheadline).frame(width: 20)
                    .foregroundStyle(role == .destructive ? .red : .secondary)
                Text(label).font(.subheadline)
                Spacer()
            }
            .padding(10).padding(.leading, 4)
        }
        .disabled(!model.phase.canSend)
        .buttonStyle(.plain)
    }

    private var cloudMapSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "icloud").font(.caption).foregroundStyle(.secondary)
                Text("云端地图快照").font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField("快照名称", text: $mapName).font(.subheadline)
                    Button("保存快照") { model.saveMap(name: mapName.trimmingCharacters(in: .whitespaces)) }
                        .font(.subheadline.weight(.semibold))
                        .disabled(!model.phase.canSend || mapName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(Color(.systemBackground))

                if let maps = model.state?.savedMaps, !maps.isEmpty {
                    Divider().padding(.leading, 12)
                    ForEach(maps) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).font(.subheadline)
                                Text(String(format: "已探索 %.1f%%", item.stats?.knownPercent ?? 0))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("加载") { model.loadMap(id: item.id) }
                                .font(.subheadline.weight(.medium))
                                .disabled(!model.phase.canSend)
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        if item.id != maps.last?.id { Divider().padding(.leading, 12) }
                    }
                } else {
                    Text("暂无已保存快照").font(.subheadline).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
        }
    }

    private var canOperate: Bool { model.phase.canSend && model.robotOnline }
}
