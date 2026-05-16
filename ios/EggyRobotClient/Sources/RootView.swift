import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var tab = 0
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $tab) {
            DashboardView(showingSettings: $showingSettings)
                .tabItem { Label("总览", systemImage: "square.grid.2x2") }
                .tag(0)
            ControlView()
                .tabItem { Label("控制", systemImage: "gamecontroller") }
                .tag(1)
            TasksView()
                .tabItem { Label("任务", systemImage: "checklist") }
                .tag(2)
            AgentView()
                .tabItem { Label("助手", systemImage: "sparkles") }
                .tag(3)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
}
