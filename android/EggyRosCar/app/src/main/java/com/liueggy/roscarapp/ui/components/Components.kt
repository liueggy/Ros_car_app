package com.liueggy.roscarapp.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlin.math.sqrt

enum class SpeedMode(val label: String, val maxSpeed: Double) {
    LOW("低速", 0.12),
    NORMAL("普通", 0.22),
    HIGH("高速", 0.35)
}

@Composable
fun JoystickControl(
    speed: Double,
    onCommand: (Double, Double, Double) -> Unit,
    onStop: () -> Unit,
    modifier: Modifier = Modifier
) {
    val radius = 72.dp
    val density = LocalDensity.current
    val radiusPx = with(density) { radius.toPx() }
    var knobOffsetPx by remember { mutableStateOf(Offset.Zero) }
    var isDragging by remember { mutableStateOf(false) }
    var currentX by remember { mutableStateOf(0.0) }
    var currentY by remember { mutableStateOf(0.0) }

    LaunchedEffect(isDragging) {
        if (isDragging) {
            while (true) {
                onCommand(currentX, currentY, 0.0)
                delay(100)
            }
        }
    }

    Box(
        modifier = modifier
            .size(radius * 2)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { startPos ->
                        isDragging = true
                        val dx = startPos.x - radiusPx
                        val dy = startPos.y - radiusPx
                        val len = sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
                        val limited = minOf(radiusPx * 0.85f, len)
                        val nx = dx / len * limited
                        val ny = dy / len * limited
                        knobOffsetPx = Offset(nx, ny)
                        currentX = (-ny / radiusPx).toDouble() * speed
                        currentY = (-nx / radiusPx).toDouble() * speed
                    },
                    onDrag = { change, _ ->
                        change.consume()
                        val dx = change.position.x - radiusPx
                        val dy = change.position.y - radiusPx
                        val len = sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
                        val limited = minOf(radiusPx * 0.85f, len)
                        val nx = dx / len * limited
                        val ny = dy / len * limited
                        knobOffsetPx = Offset(nx, ny)
                        currentX = (-ny / radiusPx).toDouble() * speed
                        currentY = (-nx / radiusPx).toDouble() * speed
                    },
                    onDragEnd = {
                        isDragging = false
                        knobOffsetPx = Offset.Zero
                        currentX = 0.0
                        currentY = 0.0
                        onStop()
                    },
                    onDragCancel = {
                        isDragging = false
                        knobOffsetPx = Offset.Zero
                        currentX = 0.0
                        currentY = 0.0
                        onStop()
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        Box(Modifier.size(radius).clip(CircleShape).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)))
        val offsetXDp = with(density) { knobOffsetPx.x.toDp() }
        val offsetYDp = with(density) { knobOffsetPx.y.toDp() }
        Box(
            modifier = Modifier
                .offset(x = offsetXDp, y = offsetYDp)
                .size(50.dp)
                .shadow(6.dp, CircleShape)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary)
        )
    }
}

@Composable
fun MetricCard(title: String, value: String, subtitle: String, color: Color = MaterialTheme.colorScheme.primary, modifier: Modifier = Modifier) {
    Surface(modifier = modifier, shape = RoundedCornerShape(16.dp), color = color.copy(alpha = 0.10f)) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
            Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
