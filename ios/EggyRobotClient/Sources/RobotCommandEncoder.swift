import Foundation

enum RobotCommand: Equatable {
    case velocity(x: Double, y: Double, z: Double)
    case reset
    case goal(x: Double, y: Double, yaw: Double = 0)
    case autoExplore(enabled: Bool)
    case setScene(String)
    case saveMap(name: String)
    case loadMap(id: String)
    case deleteMap(id: String)
    case setMode(String)
    case ping(client: String = "ios")
}

struct RobotCommandEncoder {
    func encode(_ command: RobotCommand) -> [String: Any] {
        switch command {
        case .velocity(let x, let y, let z):
            return ["type": "cmd_vel", "linear_x": x, "linear_y": y, "angular_z": z]
        case .reset:
            return ["type": "reset"]
        case .goal(let x, let y, let yaw):
            return ["type": "goal", "frame_id": "map", "x": x, "y": y, "yaw": yaw]
        case .autoExplore(let enabled):
            return ["type": "auto_explore", "enabled": enabled]
        case .setScene(let id):
            return ["type": "set_scene", "scene": id]
        case .saveMap(let name):
            return ["type": "save_map", "name": name]
        case .loadMap(let id):
            return ["type": "load_map", "id": id]
        case .deleteMap(let id):
            return ["type": "delete_map", "id": id]
        case .setMode(let mode):
            return ["type": "set_mode", "mode": mode]
        case .ping(let client):
            return ["type": "ping", "client": client]
        }
    }
}
