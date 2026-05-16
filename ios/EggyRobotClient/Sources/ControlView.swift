import SwiftUI

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
                JoystickControl(speed: mode.maxSpeed, isEnabled: canDrive, onCommand: { x, y, _ in model.cmd(x: x, y: y, z: 0) }, onStop: { model.stop() })
                VStack(spacing: 12) {
                    Button("左转") { model.cmd(x: 0, y: 0, z: 0.45) }
                        .disabled(!canDrive)
                    Button("急停") { model.stop() }
                        .tint(.red)
                        .buttonStyle(.borderedProminent)
                    Button("右转") { model.cmd(x: 0, y: 0, z: -0.45) }
                        .disabled(!canDrive)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            HStack(spacing: 14) {
                Button(model.state?.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                    .disabled(!canDrive)
                Button("重置") { model.reset() }
                    .disabled(!model.phase.canSend)
            }
            .buttonStyle(.bordered)
            if !canDrive {
                InlineNotice("小车未在线或连接不可发送，已禁用移动控制。", systemImage: "lock.fill", color: .orange)
                    .padding(.horizontal)
            }
            Text("提示：摇杆松手会自动停止；急停按钮始终可用。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }

    private var canDrive: Bool { model.phase.canSend && model.robotOnline }
}

struct RobotStatusStrip: View {
    let state: NavViewMessage
    @ObservedObject var model: RobotViewModel

    var body: some View {
        HStack(spacing: 8) {
            StatusPill(title: "连接", value: model.connectionStatus, color: model.robotOnline ? .green : .orange)
            StatusPill(title: "前方", value: state.summary.front.map { String(format: "%.2fm", $0) } ?? "--", color: .cyan)
            StatusPill(title: "电池", value: state.battery.percent.map { "\($0)%" } ?? "--", color: .blue)
        }
    }
}
