package com.handytools.app.tools.alarm

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.handytools.app.data.Alarm
import com.handytools.app.ui.HandyColors
import kotlinx.coroutines.launch
import kotlin.random.Random

class AlarmRingActivity : ComponentActivity() {

    private val finished = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, i: Intent?) { finish() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true); setTurnScreenOn(true)
            getSystemService(KeyguardManager::class.java).requestDismissKeyguard(this, null)
        }
        // Screen stays on for the whole ring.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Status bar hidden.
        if (Build.VERSION.SDK_INT >= 30) {
            WindowCompat.getInsetsController(window, window.decorView).apply {
                hide(WindowInsetsCompat.Type.statusBars())
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
        }
        // Back gesture disabled: a sleepy swipe must not kill the alarm.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { /* intentionally swallowed */ }
        })
        ContextCompat.registerReceiver(this, finished, IntentFilter(AlarmRingService.ACTION_FINISHED), ContextCompat.RECEIVER_NOT_EXPORTED)
        val id = intent.getLongExtra("id", -1)
        val alarm = AlarmRingService.current

        setContent {
            RingScreen(alarm,
                onSnooze = { send(AlarmRingService.ACTION_SNOOZE, id) },
                onDismiss = { send(AlarmRingService.ACTION_DISMISS, id) })
        }
    }

    private fun send(action: String, id: Long) {
        startService(Intent(this, AlarmRingService::class.java).setAction(action).putExtra("id", id))
    }

    override fun onDestroy() { unregisterReceiver(finished); super.onDestroy() }
}

/** CI screenshot route ("ring"): static ring UI, no ringing alarm, no service. Not linked from any UI. */
@Composable
fun AlarmRingPreview() {
    val demo = Alarm(
        id = 0, hour = 7, minute = 30, label = "Morning run",
        snoozeMinutes = 9, maxSnoozes = 3, snoozedCount = 1, mathToDismiss = false
    )
    RingScreen(a = demo, onSnooze = {}, onDismiss = {})
}

private const val HOLD_TO_DISMISS_MS = 400
private const val SWIPE_DISMISS_DP = 120

@Composable
internal fun RingScreen(a: Alarm?, onSnooze: () -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val darkBg = HandyColors.BackgroundDark
    val accent = HandyColors.Accent

    // Math problem for math-to-dismiss; generated once per alarm instance.
    val (x, y) = remember(a?.id) { Random.nextInt(12, 60) to Random.nextInt(12, 60) }
    var mathAnswer by remember { mutableStateOf("") }
    val needMath = a?.mathToDismiss == true
    val dismissEnabled = !needMath || mathAnswer.toIntOrNull() == x + y

    // maxSnoozes == 0 means unlimited.
    val snoozesLeft = a?.let { if (it.maxSnoozes == 0) null else (it.maxSnoozes - it.snoozedCount).coerceAtLeast(0) }
    val showSnooze = snoozesLeft == null || snoozesLeft > 0

    val infinite = rememberInfiniteTransition(label = "ringAmbient")
    val pulse by infinite.animateFloat(
        initialValue = 1f, targetValue = 1.02f,
        animationSpec = infiniteRepeatable(tween(2000), RepeatMode.Reverse), label = "pulse"
    )
    val glowAlpha by infinite.animateFloat(
        initialValue = 0.10f, targetValue = 0.14f,
        animationSpec = infiniteRepeatable(tween(8000), RepeatMode.Reverse), label = "glow"
    )
    val timeScale = if (reduceMotion) 1f else pulse

    val time = a?.let { String.format("%02d:%02d", it.hour, it.minute) } ?: "--:--"

    Box(Modifier.fillMaxSize().background(darkBg)) {
        // Slow 8s radial breathing glow in accent behind the time; off under Reduce Motion.
        if (!reduceMotion) {
            Box(
                Modifier.size(360.dp).align(Alignment.TopCenter).offset(y = 48.dp)
                    .background(
                        Brush.radialGradient(
                            listOf(accent.copy(alpha = glowAlpha), accent.copy(alpha = 0f))
                        ),
                        CircleShape
                    )
            )
        }
        Column(Modifier.fillMaxSize().padding(horizontal = 24.dp)) {
            // Upper 40%: time + label (or math problem).
            Column(
                Modifier.fillMaxWidth().weight(0.4f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    time, color = Color.White, fontSize = 96.sp, fontWeight = FontWeight.ExtraLight,
                    modifier = Modifier.graphicsLayer { scaleX = timeScale; scaleY = timeScale }
                )
                Spacer(Modifier.height(8.dp))
                if (needMath) {
                    Text("$x + $y = $mathAnswer", color = Color.White, fontSize = 40.sp)
                } else {
                    Text(
                        a?.label?.ifBlank { "Alarm" } ?: "Alarm",
                        color = Color.White.copy(alpha = 0.7f), fontSize = 22.sp
                    )
                }
            }
            // Lower 60%: math pad (if needed), snooze, dismiss.
            Column(
                Modifier.fillMaxWidth().weight(0.6f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom
            ) {
                if (needMath) {
                    MathPad(answer = mathAnswer, onKey = { key ->
                        mathAnswer = when (key) {
                            "C" -> ""
                            "⌫" -> mathAnswer.dropLast(1)
                            else -> if (mathAnswer.length < 3) mathAnswer + key else mathAnswer
                        }
                    })
                    Spacer(Modifier.height(16.dp))
                }
                if (showSnooze) {
                    Box(
                        Modifier.fillMaxWidth().height(60.dp)
                            .border(1.5.dp, Color.White.copy(alpha = 0.85f), RoundedCornerShape(50))
                            .clip(RoundedCornerShape(50))
                            .clickable(onClick = onSnooze),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "Snooze ${a?.snoozeMinutes ?: 9} min" + (snoozesLeft?.let { " ($it left)" } ?: ""),
                            color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                }
                DismissPill(enabled = dismissEnabled, onDismiss = onDismiss)
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

/**
 * Full-width 72dp accent pill. Dismisses on a 400ms long-press (progress fill shown during the
 * hold) or a swipe-right across it. A plain tap does nothing, so a sleepy tap can't kill it.
 */
@Composable
private fun DismissPill(enabled: Boolean, onDismiss: () -> Unit) {
    val accent = HandyColors.Accent
    var pressProgress by remember { mutableFloatStateOf(0f) }
    val density = LocalDensity.current
    val swipeThresholdPx = with(density) { SWIPE_DISMISS_DP.dp.toPx() }

    Box(
        Modifier.fillMaxWidth().height(72.dp)
            .clip(RoundedCornerShape(50))
            .background(if (enabled) accent.copy(alpha = 0.35f) else Color.Gray.copy(alpha = 0.25f))
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                val gestureScope = this
                awaitEachGesture {
                    val down = awaitFirstDown()
                    var dismissed = false
                    val holdJob = gestureScope.launch {
                        animate(0f, 1f, tween(HOLD_TO_DISMISS_MS)) { v, _ ->
                            if (!dismissed) pressProgress = v
                        }
                        dismissed = true
                        pressProgress = 1f
                        onDismiss()
                    }
                    try {
                        var dx = 0f
                        while (true) {
                            val ev = awaitPointerEvent()
                            val change = ev.changes.firstOrNull { it.id == down.id } ?: break
                            if (!change.pressed) break
                            dx += change.positionChange().x
                            change.consume()
                            if (dx > swipeThresholdPx) {
                                dismissed = true
                                holdJob.cancel()
                                pressProgress = 1f
                                onDismiss()
                                break
                            }
                        }
                    } finally {
                        if (!dismissed) { holdJob.cancel(); pressProgress = 0f }
                    }
                }
            },
        contentAlignment = Alignment.Center
    ) {
        // Progress fill during the hold.
        Box(
            Modifier.fillMaxWidth(pressProgress).fillMaxHeight()
                .background(if (enabled) accent else Color.Transparent)
        )
        Text("Dismiss", fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
    }
}

/** Custom numeric pad with 64dp keys — never the system keyboard. */
@Composable
private fun MathPad(answer: String, onKey: (String) -> Unit) {
    val rows = listOf(
        listOf("1", "2", "3"), listOf("4", "5", "6"),
        listOf("7", "8", "9"), listOf("C", "0", "⌫")
    )
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { key ->
                    Box(
                        Modifier.size(64.dp).clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.12f))
                            .clickable(onClick = { onKey(key) }),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(key, fontSize = 20.sp, color = Color.White)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}
