import SwiftUI

struct MapView: View {
    @EnvironmentObject var model: RobotViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                if let state = model.state {
                    InteractiveRobotMap(state: state) { x, y in model.setGoal(x: x, y: y) }
                } else {
                    ContentUnavailableView("等待地图数据", systemImage: "wifi", description: Text("请确认服务器 WebSocket 已连接"))
                }
            }
            .navigationTitle("实时地图")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("重置") { model.reset() }
                    Button(model.state?.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                }
            }
        }
    }
}
