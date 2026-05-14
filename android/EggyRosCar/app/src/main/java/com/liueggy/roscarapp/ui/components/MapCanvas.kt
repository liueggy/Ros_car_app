package com.liueggy.roscarapp.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.liueggy.roscarapp.data.NavViewMessage
import kotlin.math.PI

data class MapTransform(val scale: Float = 1f, val offsetX: Float = 0f, val offsetY: Float = 0f)

@Composable
fun InteractiveRobotMap(state: NavViewMessage, onGoal: (Double, Double) -> Unit, modifier: Modifier = Modifier, showOverlay: Boolean = true) {
    var transform by remember { mutableStateOf(MapTransform()) }
    val transformState = rememberUpdatedState(transform)
    Box(modifier = modifier) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(18.dp))
                .pointerInput(Unit) { detectTransformGestures { _, pan, zoom, _ -> val c = transformState.value; transform = c.copy(scale = (c.scale * zoom).coerceIn(0.6f, 5f), offsetX = c.offsetX + pan.x, offsetY = c.offsetY + pan.y) } }
                .pointerInput(state) { detectTapGestures { pos ->
                    val c = transformState.value
                    val w = size.width.toFloat().coerceAtLeast(1f); val h = size.height.toFloat().coerceAtLeast(1f)
                    val x0 = (pos.x - c.offsetX - w * (1 - c.scale) / 2) / c.scale
                    val y0 = (pos.y - c.offsetY - h * (1 - c.scale) / 2) / c.scale
                    onGoal(state.map.originX + x0 / w * state.map.widthM, state.map.originY + (h - y0) / h * state.map.heightM)
                } }
        ) {
            val w = size.width; val h = size.height
            translate(transform.offsetX + w * (1 - transform.scale) / 2, transform.offsetY + h * (1 - transform.scale) / 2) {
                scale(transform.scale, transform.scale, Offset.Zero) {
                    state.occupancyGrid?.let { grid ->
                        val cw = w / grid.width.coerceAtLeast(1); val ch = h / grid.height.coerceAtLeast(1)
                        for (gy in 0 until grid.height step 2) for (gx in 0 until grid.width step 2) {
                            val idx = gy * grid.width + gx
                            if (idx < grid.data.size) drawRect(if (grid.data[idx] > 50) Color.Black else Color.White, Offset(gx * cw, h - (gy + 1) * ch), androidx.compose.ui.geometry.Size(cw + 0.5f, ch + 0.5f))
                        }
                    }
                    fun world(x: Double, y: Double) = Offset(((x - state.map.originX) / state.map.widthM * w).toFloat(), h - ((y - state.map.originY) / state.map.heightM * h).toFloat())
                    if (state.globalPlan.size > 1) { val p = Path(); state.globalPlan.forEachIndexed { i, pt -> val q = world(pt.x, pt.y); if (i == 0) p.moveTo(q.x, q.y) else p.lineTo(q.x, q.y) }; drawPath(p, Color.Blue, style = Stroke(3f)) }
                    val goal = world(state.goal.x, state.goal.y); drawCircle(Color.Green, 10f, goal, style = Stroke(3f))
                    val robot = world(state.robot.x, state.robot.y); drawCircle(Color.Red, 8f, robot)
                    drawLine(Color.Red, robot, Offset(robot.x + kotlin.math.cos(-state.robot.yaw + 0.0).toFloat() * 20f, robot.y + kotlin.math.sin(-state.robot.yaw).toFloat() * 20f), strokeWidth = 3f)
                }
            }
        }
        if (showOverlay) Surface(modifier = Modifier.align(Alignment.TopStart).padding(8.dp), shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.surface.copy(alpha = .85f)) { Text("已探索 ${"%.1f".format(state.occupancyGrid?.stats?.knownPercent ?: 0.0)}%", modifier = Modifier.padding(6.dp), style = MaterialTheme.typography.labelSmall) }
        Button(onClick = { transform = MapTransform() }, modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp), contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp), colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = MaterialTheme.colorScheme.onPrimary)) { Text("复位", style = MaterialTheme.typography.labelSmall) }
    }
}
