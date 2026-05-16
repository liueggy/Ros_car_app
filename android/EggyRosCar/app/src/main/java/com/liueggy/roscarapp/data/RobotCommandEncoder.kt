package com.liueggy.roscarapp.data

sealed class RobotCommand {
    data class Velocity(val x: Double, val y: Double, val z: Double) : RobotCommand()
    data object Reset : RobotCommand()
    data class Goal(val x: Double, val y: Double, val yaw: Double = 0.0) : RobotCommand()
    data class AutoExplore(val enabled: Boolean) : RobotCommand()
    data class SetScene(val id: String) : RobotCommand()
    data class SaveMap(val name: String) : RobotCommand()
    data class LoadMap(val id: String) : RobotCommand()
    data class DeleteMap(val id: String) : RobotCommand()
    data class SetMode(val mode: String) : RobotCommand()
    data class Ping(val client: String = "android") : RobotCommand()
}

class RobotCommandEncoder {
    fun encode(command: RobotCommand): Map<String, Any> = when (command) {
        is RobotCommand.Velocity -> mapOf("type" to "cmd_vel", "linear_x" to command.x, "linear_y" to command.y, "angular_z" to command.z)
        RobotCommand.Reset -> mapOf("type" to "reset")
        is RobotCommand.Goal -> mapOf("type" to "goal", "frame_id" to "map", "x" to command.x, "y" to command.y, "yaw" to command.yaw)
        is RobotCommand.AutoExplore -> mapOf("type" to "auto_explore", "enabled" to command.enabled)
        is RobotCommand.SetScene -> mapOf("type" to "set_scene", "scene" to command.id)
        is RobotCommand.SaveMap -> mapOf("type" to "save_map", "name" to command.name)
        is RobotCommand.LoadMap -> mapOf("type" to "load_map", "id" to command.id)
        is RobotCommand.DeleteMap -> mapOf("type" to "delete_map", "id" to command.id)
        is RobotCommand.SetMode -> mapOf("type" to "set_mode", "mode" to command.mode)
        is RobotCommand.Ping -> mapOf("type" to "ping", "client" to command.client)
    }
}
