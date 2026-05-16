package com.liueggy.roscarapp.data

import org.junit.Assert.assertEquals
import org.junit.Test

class RobotCommandEncoderTest {
    private val encoder = RobotCommandEncoder()

    @Test
    fun encodesVelocityCommand() {
        val payload = encoder.encode(RobotCommand.Velocity(0.12, -0.03, 0.45))
        assertEquals("cmd_vel", payload["type"])
        assertEquals(0.12, payload["linear_x"])
        assertEquals(-0.03, payload["linear_y"])
        assertEquals(0.45, payload["angular_z"])
    }

    @Test
    fun encodesGoalCommand() {
        val payload = encoder.encode(RobotCommand.Goal(1.2, -0.8))
        assertEquals("goal", payload["type"])
        assertEquals("map", payload["frame_id"])
        assertEquals(1.2, payload["x"])
        assertEquals(-0.8, payload["y"])
        assertEquals(0.0, payload["yaw"])
    }

    @Test
    fun encodesAutoExploreAndPing() {
        assertEquals(true, encoder.encode(RobotCommand.AutoExplore(true))["enabled"])
        assertEquals("android", encoder.encode(RobotCommand.Ping())["client"])
    }
}
