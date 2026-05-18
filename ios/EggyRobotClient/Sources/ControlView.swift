import SwiftUI

struct ControlView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var mode: SpeedMode = .normal
    @State private var anim = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 14) {
                    if let state = model.state {
                        RobotStatusStrip(state: state, model: model)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        InteractiveRobotMap(state: state) { x, y in model.setGoal(x: x, y: y) }
                            .frame(height: 270)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)

                        controlPanel(state: state)
                    } else {
                        ContentUnavailableView("等待地图", systemImage: "map", description: Text("连接服务器后显示小车位置"))
                            .frame(height: 260)
                            .padding(.top, 20)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("控制")
            .toolbar { EmergencyStopToolbar() }
        }
    }

    private func controlPanel(state: NavViewMessage) -> some View {
        VStack(spacing: 10) {
            Picker("速度模式", selection: $mode) {
                ForEach(SpeedMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 20) {
                JoystickControl(speed: mode.maxSpeed, isEnabled: canDrive, onCommand: { x, y, _ in
                    model.cmd(x: x, y: y, z: 0)
                }, onStop: { model.stop() })
                .frame(maxWidth: 130)

                VStack(spacing: 10) {
                    directionButton("左转") { model.cmd(x: 0, y: 0, z: 0.45) }
                    Button("急停") { model.stop() }
                        .tint(.red)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    directionButton("右转") { model.cmd(x: 0, y: 0, z: -0.45) }
                }
            }

            HStack(spacing: 12) {
                Button(state.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                    .disabled(!canDrive)
                Button("重置") { model.reset() }
                    .disabled(!model.phase.canSend)
                Spacer()
            }
            .buttonStyle(.bordered)

            if !canDrive {
                InlineNotice("小车未在线或连接不可发送，已禁用移动控制。", systemImage: "lock.fill", color: .orange)
            }

            Text("提示：摇杆松手会自动停止；急停按钮始终可用。")
                .font(.caption2).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
        .padding(.horizontal)
    }

    private func directionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .disabled(!canDrive)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }

    private var canDrive: Bool { model.phase.canSend && model.robotOnline }
}

struct RobotStatusStrip: View {
    let state: NavViewMessage
    let model: RobotViewModel

    var body: some View {
        HStack(spacing: 8) {
            StatusPill(title: "连接", value: model.connectionStatus, color: model.robotOnline ? .green : .orange)
            StatusPill(title: "前方", value: state.summary.front.map { String(format: "%.2fm", $0) } ?? "--", color: .cyan)
            StatusPill(title: "电池", value: state.battery.percent.map { "\($0)%" } ?? "--", color: .blue)
        }
    }
}
