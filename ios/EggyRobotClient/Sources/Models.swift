import Foundation

struct NavViewMessage: Codable {
    let type: String
    let ts: Double
    let robot: RobotPose
    let map: MapInfo
    let occupancyGrid: OccupancyGrid?
    let lidarPoints: [Point2D]
    let globalPlan: [PathPoint]
    let localPlan: [PathPoint]
    let goal: Goal
    let navStatus: String
    let battery: Battery
    let summary: Summary
    let system: SystemState
    let savedMaps: [SavedMap]?
    let scenes: [SceneInfo]?

    enum CodingKeys: String, CodingKey {
        case type, ts, robot, map, goal, battery, summary, system, scenes
        case occupancyGrid = "occupancy_grid"
        case lidarPoints = "lidar_points"
        case globalPlan = "global_plan"
        case localPlan = "local_plan"
        case navStatus = "nav_status"
        case savedMaps = "saved_maps"
    }
}

struct RobotPose: Codable { var x: Double; var y: Double; var yaw: Double; var vx: Double; var wz: Double }
struct MapInfo: Codable { var frameId: String?; var resolution: Double; var originX: Double; var originY: Double; var widthM: Double; var heightM: Double
    enum CodingKeys: String, CodingKey { case frameId = "frame_id"; case resolution; case originX = "origin_x"; case originY = "origin_y"; case widthM = "width_m"; case heightM = "height_m" }
}
struct OccupancyGrid: Codable { var frameId: String?; var resolution: Double; var originX: Double; var originY: Double; var width: Int; var height: Int; var data: [Int]; var stats: MapStats
    enum CodingKeys: String, CodingKey { case frameId = "frame_id"; case resolution; case originX = "origin_x"; case originY = "origin_y"; case width; case height; case data; case stats }
}
struct MapStats: Codable { var known: Int; var free: Int; var occupied: Int; var total: Int; var knownPercent: Double
    enum CodingKeys: String, CodingKey { case known, free, occupied, total; case knownPercent = "known_percent" }
}
struct Point2D: Codable, Identifiable { var id: String { "\(x),\(y)" }; var x: Double; var y: Double; var hit: Bool? }
struct PathPoint: Codable, Identifiable { var id: String { "\(x),\(y)" }; var x: Double; var y: Double; var blocked: Bool? }
struct Goal: Codable { var x: Double; var y: Double; var yaw: Double }
struct Battery: Codable { var voltage: Double; var percent: Int }
struct Summary: Codable { var front: Double; var nearest: Double; var nearestAngle: Double
    enum CodingKeys: String, CodingKey { case front, nearest; case nearestAngle = "nearest_angle" }
}
struct SystemState: Codable { var ros: Bool; var base: Bool; var imu: Bool; var lidar: Bool; var server: String; var autoExplore: Bool?; var scene: String?; var sceneName: String?
    enum CodingKeys: String, CodingKey { case ros, base, imu, lidar, server; case autoExplore = "auto_explore"; case scene; case sceneName = "scene_name" }
}
struct SavedMap: Codable, Identifiable { var id: String; var name: String; var createdAt: String?; var scene: String?; var stats: MapStats?
    enum CodingKeys: String, CodingKey { case id, name, scene, stats; case createdAt = "created_at" }
}
struct SceneInfo: Codable, Identifiable { var id: String; var name: String }
