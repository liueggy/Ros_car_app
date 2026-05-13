import Foundation
import SwiftUI

@MainActor
enum ConnectionPhase: Equatable {
    case idle
    case connecting
    case waitingFirstState
    case online
    case robotOffline
    case stale
    case disconnected
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "未连接"
        case .connecting: return "连接中"
        case .waitingFirstState: return "等待数据"
        case .online: return "在线"
        case .robotOffline: return "小车离线"
        case .stale: return "数据延迟"
        case .disconnected: return "已断开"
        case .failed: return "连接失败"
        }
    }

    var canSend: Bool {
        switch self {
        case .online, .stale: return true
        default: return false
        }
    }
}

@MainActor
final class RobotViewModel: ObservableObject {
    static let defaultServerURL = "wss://liueggy.live/ws"

    @Published var serverURLString = RobotViewModel.defaultServerURL
    @Published var state: NavViewMessage?
    @Published var connected = false
    @Published var phase: ConnectionPhase = .idle
    @Published var connectionStatus = "未连接"
    @Published var log: [String] = []
    @Published var lastMessageAt: Date?
    @Published var lastStateAt: Date?

    private var task: URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?
    private var watchdogTimer: Timer?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var intentionalDisconnect = false

    var robotOnline: Bool { state?.system.robotConnected == true }
    var dataAge: TimeInterval? { lastStateAt.map { Date().timeIntervalSince($0) } }
    var serverHost: String { URL(string: serverURLString)?.host ?? serverURLString }

    func connect(resetBackoff: Bool = true) {
        intentionalDisconnect = false
        if resetBackoff { reconnectAttempt = 0 }
        disconnectInternal(markIntentional: false)

        guard let url = normalizedWebSocketURL(from: serverURLString) else {
            phase = .failed("服务器地址无效")
            syncStatus()
            appendLog("服务器地址无效")
            return
        }
        serverURLString = url.absoluteString

        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()

        connected = false
        phase = .connecting
        syncStatus()
        appendLog("连接中转服务器：\(url.absoluteString)")

        receiveLoop()
        startTimers()
    }

    func disconnect() {
        intentionalDisconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        disconnectInternal(markIntentional: true)
        phase = .disconnected
        syncStatus()
    }

    private func disconnectInternal(markIntentional: Bool) {
        stopTimers()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connected = false
        if markIntentional { intentionalDisconnect = true }
    }

    private func normalizedWebSocketURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return URL(string: Self.defaultServerURL) }

        if trimmed == "default" || trimmed == "liueggy.live" {
            return URL(string: Self.defaultServerURL)
        }

        if trimmed.hasPrefix("http://") {
            return URL(string: trimmed.replacingOccurrences(of: "http://", with: "ws://"))
        }
        if trimmed.hasPrefix("https://") {
            return URL(string: trimmed.replacingOccurrences(of: "https://", with: "wss://"))
        }
        if trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return URL(string: trimmed)
        }
        return URL(string: "wss://\(trimmed.hasSuffix("/ws") ? trimmed : trimmed + "/ws")")
    }

    private func startTimers() {
        stopTimers()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sendPing() }
        }
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchdogTick() }
        }
    }

    private func stopTimers() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func receiveLoop() {
        guard let task else { return }
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.connected = false
                    self.phase = .failed(error.localizedDescription)
                    self.syncStatus()
                    self.appendLog("连接断开：\(error.localizedDescription)")
                    if !self.intentionalDisconnect { self.scheduleReconnect() }
                case .success(let message):
                    self.lastMessageAt = Date()
                    self.connected = true
                    self.handle(message)
                    self.receiveLoop()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String?
        switch message {
        case .string(let value): text = value
        case .data(let data): text = String(data: data, encoding: .utf8)
        @unknown default: text = nil
        }
        guard let text, let data = text.data(using: .utf8) else { return }

        let envelope = try? JSONDecoder().decode(RelayEnvelope.self, from: data)
        switch envelope?.type {
        case "nav_view":
            do {
                let decoded = try JSONDecoder().decode(NavViewMessage.self, from: data)
                state = decoded
                lastStateAt = Date()
                reconnectAttempt = 0
                if decoded.system.robotConnected == true {
                    phase = .online
                } else {
                    phase = .robotOffline
                }
                syncStatus()
            } catch {
                appendLog("状态解析失败：\(error.localizedDescription)")
            }
        case "ack":
            if let ack = try? JSONDecoder().decode(RelayAck.self, from: data) {
                appendLog(ack.robotForwarded == true ? "命令已转发到小车" : "命令已到云端，但小车未在线")
            }
        case "error":
            appendLog("服务器返回错误")
        case "pong":
            break
        default:
            // The relay may send compact full-state data without a type in future.
            if let decoded = try? JSONDecoder().decode(NavViewMessage.self, from: data) {
                state = decoded
                lastStateAt = Date()
                phase = decoded.system.robotConnected == true ? .online : .robotOffline
                syncStatus()
            }
        }
    }

    private func sendPing() {
        guard task != nil else { return }
        sendRaw(["type": "ping", "client": "ios"])
    }

    private func watchdogTick() {
        guard !intentionalDisconnect else { return }
        if let lastMessageAt, Date().timeIntervalSince(lastMessageAt) > 15 {
            appendLog("超过 15 秒未收到服务器消息，自动重连")
            scheduleReconnect()
            return
        }
        if case .online = phase, let lastStateAt, Date().timeIntervalSince(lastStateAt) > 8 {
            phase = .stale
            syncStatus()
        }
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil else { return }
        stopTimers()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connected = false
        syncStatus()

        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(max(0, reconnectAttempt - 1))), 15.0)
        appendLog(String(format: "%.0f 秒后自动重连", delay))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self?.reconnectTask = nil
                if self?.intentionalDisconnect == false { self?.connect(resetBackoff: false) }
            }
        }
    }

    private func syncStatus() {
        connectionStatus = phase.title
    }

    private func sendRaw(_ object: [String: Any]) {
        guard let task,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { [weak self] error in
            if let error {
                Task { @MainActor in self?.appendLog("发送失败：\(error.localizedDescription)") }
            }
        }
    }

    func send(_ object: [String: Any]) {
        guard phase.canSend else {
            appendLog("未在线，命令未发送：\(object["type"] ?? "unknown")")
            return
        }
        sendRaw(object)
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
    func setMode(_ mode: String) { send(["type":"set_mode", "mode":mode]) }

    private func appendLog(_ text: String) {
        log.insert("\(Date().formatted(date: .omitted, time: .standard))  \(text)", at: 0)
        log = Array(log.prefix(80))
    }
}
