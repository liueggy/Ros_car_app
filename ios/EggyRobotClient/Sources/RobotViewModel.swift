import Foundation
import SwiftUI

@MainActor
final class RobotViewModel: ObservableObject {
    @Published var serverURLString = "ws://167.71.221.110:8088/ws"
    @Published var state: NavViewMessage?
    @Published var connected = false
    @Published var connectionStatus = "未连接"
    @Published var log: [String] = []

    private var task: URLSessionWebSocketTask?

    func connect() {
        disconnect()
        guard let url = URL(string: serverURLString) else { appendLog("服务器地址无效"); return }
        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()
        connected = false
        connectionStatus = "连接中"
        appendLog("连接中转服务器")
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connected = false
        connectionStatus = "未连接"
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self.connected = false
                    self.connectionStatus = "连接失败"
                    self.appendLog("连接断开：\(error.localizedDescription)")
                }
            case .success(let message):
                var decoded: NavViewMessage?
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    decoded = try? JSONDecoder().decode(NavViewMessage.self, from: data)
                }
                Task { @MainActor in
                    if let decoded, decoded.type == "nav_view" {
                        self.state = decoded
                        self.connected = true
                        self.connectionStatus = "已连接"
                    }
                    self.receiveLoop()
                }
            }
        }
    }

    func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object), let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error { Task { @MainActor in self?.appendLog("发送失败：\(error.localizedDescription)") } }
        }
    }

    func cmd(x: Double, y: Double, z: Double) { send(["type":"cmd_vel", "linear_x":x, "linear_y":y, "angular_z":z]) }
    func stop() { cmd(x: 0, y: 0, z: 0) }
    func reset() { send(["type":"reset"]) }
    func setGoal(x: Double, y: Double) { send(["type":"goal", "frame_id":"map", "x":x, "y":y, "yaw":0]) }
    func toggleExplore() { send(["type":"auto_explore", "enabled": !(state?.system.autoExplore ?? false)]) }
    func setScene(_ id: String) { send(["type":"set_scene", "scene":id]) }
    func saveMap(name: String) { send(["type":"save_map", "name":name]) }
    func loadMap(id: String) { send(["type":"load_map", "id":id]) }
    func deleteMap(id: String) { send(["type":"delete_map", "id":id]) }

    private func appendLog(_ text: String) {
        log.insert("\(Date().formatted(date: .omitted, time: .standard))  \(text)", at: 0)
        log = Array(log.prefix(50))
    }
}
