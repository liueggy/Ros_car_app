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
                    Menu("模式") {
                        Button("Lite 精简") { model.setMode("lite") }
                        Button("Map 地图") { model.setMode("map") }
                    }
                    if model.phase.canSend {
                        Button(role: .destructive) { model.stop() } label: { Image(systemName: "stop.fill") }
                            .tint(.red)
                    }
                }
            }
        }
    }
}
