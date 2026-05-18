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
    case startMapping
    case stopMapping
    case saveNavigationMap(name: String)
    case startSimpleNav
    case stopSimpleNav
    case simpleGoal(x: Double, y: Double, yaw: Double = 0)
    case cancelSimpleGoal
    case startNavigation(mapPath: String? = nil)
    case stopNavigation
    case cancelGoal
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
        case .startMapping:
            return ["type": "start_mapping"]
        case .stopMapping:
            return ["type": "stop_mapping"]
        case .saveNavigationMap(let name):
            return ["type": "save_navigation_map", "name": name]
        case .startSimpleNav:
            return ["type": "start_simple_nav"]
        case .stopSimpleNav:
            return ["type": "stop_simple_nav"]
        case .simpleGoal(let x, let y, let yaw):
            return ["type": "simple_goal", "frame_id": "map", "x": x, "y": y, "yaw": yaw]
        case .cancelSimpleGoal:
            return ["type": "cancel_simple_goal"]
        case .startNavigation(let mapPath):
            var payload: [String: Any] = ["type": "start_navigation"]
            if let mapPath, !mapPath.isEmpty { payload["map_path"] = mapPath }
            return payload
        case .stopNavigation:
            return ["type": "stop_navigation"]
        case .cancelGoal:
            return ["type": "cancel_goal"]
        case .ping(let client):
            return ["type": "ping", "client": client]
        }
    }
}
