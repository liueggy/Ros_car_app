import SwiftUI

struct LogDetailView: View {
    let logs: [String]

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(logs, id: \.self) { item in
                    Text(item)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("日志")
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: RobotViewModel
    @State private var urlText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("WebSocket 地址", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("重新连接") { model.serverURLString = urlText; model.connect() }
                    Button("使用默认 wss://liueggy.live/ws") { urlText = RobotViewModel.defaultServerURL; model.serverURLString = urlText; model.connect() }
                    LabeledContent("连接状态", value: model.connectionStatus)
                    LabeledContent("服务器", value: model.serverHost)
                    LabeledContent("机器人", value: model.state?.system.robotConnected == true ? (model.state?.system.robotId ?? "在线") : "离线")
                    LabeledContent("ROS", value: model.state?.system.ros == true ? "正常" : "异常/未知")
                    LabeledContent("数据延迟", value: model.dataAge.map { String(format: "%.1fs", $0) } ?? "--")
                    LabeledContent("流模式", value: model.state?.system.streamMode ?? "--")
                }
                NavigationLink {
                    LogDetailView(logs: model.log)
                } label: {
                    LabeledContent("日志", value: "\(model.log.count) 条")
                }
            }
            .navigationTitle("设置")
            .onAppear { urlText = model.serverURLString }
            .toolbar {
                EmergencyStopToolbar()
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存并重连") { model.serverURLString = urlText; model.connect() }
                }
            }
        }
    }
}
