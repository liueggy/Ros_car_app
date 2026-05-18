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
    let topics: [TopicInfo]?
    let logs: [RelayLog]?
    let alerts: [RelayAlert]?
    let savedMaps: [SavedMap]?
    let scenes: [SceneInfo]?

    enum CodingKeys: String, CodingKey {
        case type, ts, robot, map, goal, battery, summary, system, topics, logs, alerts, scenes
        case occupancyGrid = "occupancy_grid"
        case lidarPoints = "lidar_points"
        case globalPlan = "global_plan"
        case localPlan = "local_plan"
        case navStatus = "nav_status"
        case savedMaps = "saved_maps"
    }
}

struct RobotPose: Codable {
    var x: Double
    var y: Double
    var yaw: Double
    var vx: Double
    var wz: Double
    var poseAgeSec: Double?
    enum CodingKeys: String, CodingKey { case x, y, yaw, vx, wz; case poseAgeSec = "pose_age_sec" }
}

struct MapInfo: Codable {
    var frameId: String?
    var resolution: Double
    var originX: Double
    var originY: Double
    var widthM: Double
    var heightM: Double
    enum CodingKeys: String, CodingKey { case frameId = "frame_id"; case resolution; case originX = "origin_x"; case originY = "origin_y"; case widthM = "width_m"; case heightM = "height_m" }
}

struct OccupancyGrid: Codable {
    var frameId: String?
    var resolution: Double
    var originX: Double
    var originY: Double
    var width: Int
    var height: Int
    var data: [Int]
    var stats: MapStats
    var version: Int?
    var ageSec: Double?
    var stale: Bool?
    enum CodingKeys: String, CodingKey { case frameId = "frame_id"; case resolution; case originX = "origin_x"; case originY = "origin_y"; case width; case height; case data; case stats; case version; case ageSec = "age_sec"; case stale }
}

struct MapStats: Codable {
    var known: Int
    var free: Int
    var occupied: Int
    var total: Int
    var knownPercent: Double
    enum CodingKeys: String, CodingKey { case known, free, occupied, total; case knownPercent = "known_percent" }
}

struct Point2D: Codable, Identifiable { var id: String { "\(x),\(y)" }; var x: Double; var y: Double; var hit: Bool? }
struct PathPoint: Codable, Identifiable { var id: String { "\(x),\(y)" }; var x: Double; var y: Double; var blocked: Bool? }
struct Goal: Codable { var x: Double; var y: Double; var yaw: Double }
struct Battery: Codable { var voltage: Double?; var percent: Int?; var rule: String? }
struct Summary: Codable {
    var front: Double?
    var nearest: Double?
    var nearestAngle: Double?
    var rangeMin: Double?
    var effectiveMin: Double?
    var rangeMax: Double?
    var frontSectorDeg: Double?
    var note: String?
    enum CodingKeys: String, CodingKey { case front, nearest, note; case nearestAngle = "nearest_angle"; case rangeMin = "range_min"; case effectiveMin = "effective_min"; case rangeMax = "range_max"; case frontSectorDeg = "front_sector_deg" }
}

struct SystemState: Codable {
    var ros: Bool?
    var base: Bool?
    var imu: Bool?
    var lidar: Bool?
    var map: Bool?
    var diagnostics: Bool?
    var server: String?
    var robotId: String?
    var robotConnected: Bool?
    var streamMode: String?
    var mode: String?
    var autoExplore: Bool?
    var scene: String?
    var sceneName: String?
    var simpleNavStatus: String?
    enum CodingKeys: String, CodingKey { case ros, base, imu, lidar, map, diagnostics, server, mode; case robotId = "robot_id"; case robotConnected = "robot_connected"; case streamMode = "stream_mode"; case autoExplore = "auto_explore"; case scene; case sceneName = "scene_name"; case simpleNavStatus = "simple_nav_status" }
}

struct TopicInfo: Codable, Identifiable {
    var id: String { name }
    var name: String
    var type: String?
    var description: String?
    var ok: Bool?
    var ageSec: Double?
    var count: Int?
    var expectedHz: Double?
    enum CodingKeys: String, CodingKey { case name, type, description, ok, count; case ageSec = "age_sec"; case expectedHz = "expected_hz" }
}

struct RelayLog: Codable, Identifiable {
    var id: String { "\(time ?? 0)-\(source ?? "")-\(message)" }
    var time: Double?
    var level: String?
    var source: String?
    var message: String
}

struct RelayAlert: Codable, Identifiable {
    var id: String { "\(time ?? 0)-\(name ?? "")-\(message)" }
    var level: String
    var name: String?
    var message: String
    var time: Double?
}

struct SavedMap: Codable, Identifiable { var id: String; var name: String; var createdAt: String?; var scene: String?; var stats: MapStats?
    enum CodingKeys: String, CodingKey { case id, name, scene, stats; case createdAt = "created_at" }
}
struct SceneInfo: Codable, Identifiable { var id: String; var name: String }

struct RelayEnvelope: Codable { let type: String? }
struct RelayAck: Codable { let type: String?; let robotForwarded: Bool?; let ts: Double?; enum CodingKeys: String, CodingKey { case type, ts; case robotForwarded = "robot_forwarded" } }
