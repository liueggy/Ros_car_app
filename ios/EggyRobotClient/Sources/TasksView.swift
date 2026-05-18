import SwiftUI

struct TasksView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mapName = "导航地图"

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16) {
                    headerCard

                    if !canOperate {
                        InlineNotice("小车未在线或连接不可发送，任务操作会暂时禁用。", systemImage: "wifi.slash", color: .orange)
                            .padding(.horizontal)
                    }

                    navFlowSection
                    advancedSection
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

    private var headerCard: some View {
        AppSectionCard(
            title: "导航任务中心",
            subtitle: "按步骤完成建图、保存地图，再进入点击目标导航。",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up",
            accent: canOperate ? .green : .orange
        ) {
            HStack(spacing: 8) {
                CapsuleTag(text: canOperate ? "可操作" : "等待连接", color: canOperate ? .green : .orange)
                CapsuleTag(text: model.navigationMode.title, color: .accentColor)
                if let status = model.state?.system.simpleNavStatus, !status.isEmpty, status != "idle" {
                    CapsuleTag(text: statusDisplay(status), color: .purple)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var navFlowSection: some View {
        AppSectionCard(
            title: "建图 / 保存 / 导航流程",
            subtitle: "推荐顺序执行；快速直达开启后，到地图上点击目标点。",
            systemImage: "map",
            accent: .accentColor
        ) {
            VStack(spacing: 0) {
                flowStep(1, icon: "map", title: "开始建图", subtitle: "启动地图流和建图节点，手动开车扫图。") {
                    model.startMapping()
                }
                rowDivider

                HStack(spacing: 12) {
                    TimelineStepBadge(number: 2, isActive: canOperate)
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.accentColor)
                        .frame(width: 28)
                    TextField("保存为导航地图", text: $mapName)
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)
                    Button("保存") {
                        model.saveNavigationMap(name: normalizedMapName)
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(!canOperate || normalizedMapName.isEmpty)
                }
                .padding(.vertical, 10)
                rowDivider

                flowStep(3, icon: "location.north.line", title: "开启快速直达", subtitle: "先快速旋转对准目标，再直行到目标点。") {
                    model.startQuickDirectNavigation()
                }
                rowDivider

                flowStep(4, icon: "stop.circle", title: "停止导航", subtitle: "取消目标、停止导航并清零速度。", role: .destructive) {
                    model.stopNavigation()
                }
            }

            if let status = model.state?.system.simpleNavStatus, !status.isEmpty, status != "idle" {
                navStatusBanner(status)
            }

            InlineNotice("开启快速直达后，回到总览/控制页在地图上点击目标点，App 会发送 simple_goal。", systemImage: "hand.tap", color: .secondary)
        }
    }

    private func flowStep(_ number: Int, icon: String, title: String, subtitle: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            TimelineStepBadge(number: number, isActive: canOperate)
            ActionRowButton(
                title: title,
                subtitle: subtitle,
                systemImage: icon,
                role: role,
                isEnabled: canOperate,
                action: action
            )
        }
    }

    private var advancedSection: some View {
        AppSectionCard(
            title: "高级控制",
            subtitle: "用于调试或切换导航后端，危险动作会以红色标记。",
            systemImage: "gearshape.2",
            accent: .indigo
        ) {
            VStack(spacing: 0) {
                rowButton("停止建图", subtitle: "停止当前建图后端", icon: "mappin.slash") { model.stopMapping() }
                rowDivider
                rowButton("开启 move_base 导航", subtitle: "切换到 ROS move_base 导航流程", icon: "map") { model.startMoveBaseNavigation() }
                rowDivider
                rowButton(model.state?.system.autoExplore == true ? "停止自动探索" : "开始自动探索", subtitle: "自动探索建图区域", icon: "scope") { model.toggleExplore() }
                rowDivider
                rowButton("重置地图", subtitle: "清空当前地图预览数据", icon: "arrow.counterclockwise", role: .destructive) { model.reset() }
            }
        }
    }

    private func rowButton(_ title: String, subtitle: String? = nil, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        ActionRowButton(
            title: title,
            subtitle: subtitle,
            systemImage: icon,
            role: role,
            isEnabled: model.phase.canSend,
            action: action
        )
    }

    private var cloudMapSection: some View {
        AppSectionCard(
            title: "云端地图快照",
            subtitle: "保存或加载云端 relay 中的地图预览快照。",
            systemImage: "icloud",
            accent: .cyan
        ) {
            HStack(spacing: 8) {
                TextField("快照名称", text: $mapName)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                Button("保存快照") { model.saveMap(name: normalizedMapName) }
                    .font(.subheadline.weight(.semibold))
                    .disabled(!model.phase.canSend || normalizedMapName.isEmpty)
            }

            if let maps = model.state?.savedMaps, !maps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(maps) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 30, height: 30)
                                .background(Color.cyan.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline.weight(.semibold))
                                Text(String(format: "已探索 %.1f%%", item.stats?.knownPercent ?? 0))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("加载") { model.loadMap(id: item.id) }
                                .font(.subheadline.weight(.medium))
                                .disabled(!model.phase.canSend)
                        }
                        .padding(.vertical, 10)
                        if item.id != maps.last?.id { rowDivider }
                    }
                }
            } else {
                ContentUnavailableView("暂无已保存快照", systemImage: "icloud.slash", description: Text("保存快照后会显示在这里。"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
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
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.accentColor, in: Capsule())
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

    private var rowDivider: some View {
        Divider().padding(.leading, 54)
    }

    private var normalizedMapName: String {
        mapName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canOperate: Bool { model.phase.canSend && model.robotOnline }
}
