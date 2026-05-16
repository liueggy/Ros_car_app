import SwiftUI

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
                }
                .padding()
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
