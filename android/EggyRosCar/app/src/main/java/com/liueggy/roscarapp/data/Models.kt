package com.liueggy.roscarapp.data

import com.google.gson.annotations.SerializedName

data class NavViewMessage(
    @SerializedName("type") val type: String = "",
    @SerializedName("ts") val ts: Double = 0.0,
    @SerializedName("robot") val robot: RobotPose = RobotPose(),
    @SerializedName("map") val map: MapInfo = MapInfo(),
    @SerializedName("occupancy_grid") val occupancyGrid: OccupancyGrid? = null,
    @SerializedName("lidar_points") val lidarPoints: List<Point2D> = emptyList(),
    @SerializedName("global_plan") val globalPlan: List<PathPoint> = emptyList(),
    @SerializedName("local_plan") val localPlan: List<PathPoint> = emptyList(),
    @SerializedName("goal") val goal: Goal = Goal(),
    @SerializedName("nav_status") val navStatus: String = "",
    @SerializedName("battery") val battery: Battery = Battery(),
    @SerializedName("summary") val summary: Summary = Summary(),
    @SerializedName("system") val system: SystemState = SystemState(),
    @SerializedName("topics") val topics: List<TopicInfo>? = null,
    @SerializedName("logs") val logs: List<RelayLog>? = null,
    @SerializedName("alerts") val alerts: List<RelayAlert>? = null,
    @SerializedName("saved_maps") val savedMaps: List<SavedMap>? = null,
    @SerializedName("scenes") val scenes: List<SceneInfo>? = null
)

data class RobotPose(@SerializedName("x") val x: Double = 0.0, @SerializedName("y") val y: Double = 0.0, @SerializedName("yaw") val yaw: Double = 0.0, @SerializedName("vx") val vx: Double = 0.0, @SerializedName("wz") val wz: Double = 0.0, @SerializedName("pose_age_sec") val poseAgeSec: Double? = null)
data class MapInfo(@SerializedName("frame_id") val frameId: String? = null, @SerializedName("resolution") val resolution: Double = 0.05, @SerializedName("origin_x") val originX: Double = 0.0, @SerializedName("origin_y") val originY: Double = 0.0, @SerializedName("width_m") val widthM: Double = 10.0, @SerializedName("height_m") val heightM: Double = 10.0)
data class OccupancyGrid(@SerializedName("frame_id") val frameId: String? = null, @SerializedName("resolution") val resolution: Double = 0.05, @SerializedName("origin_x") val originX: Double = 0.0, @SerializedName("origin_y") val originY: Double = 0.0, @SerializedName("width") val width: Int = 0, @SerializedName("height") val height: Int = 0, @SerializedName("data") val data: List<Int> = emptyList(), @SerializedName("stats") val stats: MapStats = MapStats(), @SerializedName("version") val version: Int? = null, @SerializedName("age_sec") val ageSec: Double? = null, @SerializedName("stale") val stale: Boolean? = null)
data class MapStats(@SerializedName("known") val known: Int = 0, @SerializedName("free") val free: Int = 0, @SerializedName("occupied") val occupied: Int = 0, @SerializedName("total") val total: Int = 0, @SerializedName("known_percent") val knownPercent: Double = 0.0)
data class Point2D(@SerializedName("x") val x: Double = 0.0, @SerializedName("y") val y: Double = 0.0, @SerializedName("hit") val hit: Boolean? = null)
data class PathPoint(@SerializedName("x") val x: Double = 0.0, @SerializedName("y") val y: Double = 0.0, @SerializedName("blocked") val blocked: Boolean? = null)
data class Goal(@SerializedName("x") val x: Double = 0.0, @SerializedName("y") val y: Double = 0.0, @SerializedName("yaw") val yaw: Double = 0.0)
data class Battery(@SerializedName("voltage") val voltage: Double? = null, @SerializedName("percent") val percent: Int? = null, @SerializedName("rule") val rule: String? = null)
data class Summary(@SerializedName("front") val front: Double? = null, @SerializedName("nearest") val nearest: Double? = null, @SerializedName("nearest_angle") val nearestAngle: Double? = null, @SerializedName("range_min") val rangeMin: Double? = null, @SerializedName("effective_min") val effectiveMin: Double? = null, @SerializedName("range_max") val rangeMax: Double? = null, @SerializedName("front_sector_deg") val frontSectorDeg: Double? = null, @SerializedName("note") val note: String? = null)
data class SystemState(@SerializedName("ros") val ros: Boolean? = null, @SerializedName("base") val base: Boolean? = null, @SerializedName("imu") val imu: Boolean? = null, @SerializedName("lidar") val lidar: Boolean? = null, @SerializedName("map") val map: Boolean? = null, @SerializedName("diagnostics") val diagnostics: Boolean? = null, @SerializedName("server") val server: String? = null, @SerializedName("robot_id") val robotId: String? = null, @SerializedName("robot_connected") val robotConnected: Boolean? = null, @SerializedName("stream_mode") val streamMode: String? = null, @SerializedName("mode") val mode: String? = null, @SerializedName("auto_explore") val autoExplore: Boolean? = null, @SerializedName("scene") val scene: String? = null, @SerializedName("scene_name") val sceneName: String? = null)
data class TopicInfo(@SerializedName("name") val name: String = "", @SerializedName("type") val type: String? = null, @SerializedName("description") val description: String? = null, @SerializedName("ok") val ok: Boolean? = null, @SerializedName("age_sec") val ageSec: Double? = null, @SerializedName("count") val count: Int? = null, @SerializedName("expected_hz") val expectedHz: Double? = null)
data class RelayLog(@SerializedName("time") val time: Double? = null, @SerializedName("level") val level: String? = null, @SerializedName("source") val source: String? = null, @SerializedName("message") val message: String = "")
data class RelayAlert(@SerializedName("level") val level: String = "", @SerializedName("name") val name: String? = null, @SerializedName("message") val message: String = "", @SerializedName("time") val time: Double? = null)
data class SavedMap(@SerializedName("id") val id: String = "", @SerializedName("name") val name: String = "", @SerializedName("created_at") val createdAt: String? = null, @SerializedName("scene") val scene: String? = null, @SerializedName("stats") val stats: MapStats? = null)
data class SceneInfo(@SerializedName("id") val id: String = "", @SerializedName("name") val name: String = "")
data class RelayEnvelope(@SerializedName("type") val type: String? = null)
data class RelayAck(@SerializedName("type") val type: String? = null, @SerializedName("robot_forwarded") val robotForwarded: Boolean? = null, @SerializedName("ts") val ts: Double? = null)
