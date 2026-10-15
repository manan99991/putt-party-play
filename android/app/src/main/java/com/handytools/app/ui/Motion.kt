package com.handytools.app.ui

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Motion tokens (single source of truth; mirrors HandyMotion on iOS).
 * fast 120 / base 200 / slow 280. Enter eases out, exit eases in. Press scale 0.98.
 * Nothing bounces — the only spring in the app is the floating bubble snap.
 */
object HandyMotion {
    const val FAST_MS = 120
    const val BASE_MS = 200
    const val SLOW_MS = 280
    const val PRESS_SCALE = 0.98f
    val EnterEasing = FastOutLinearInEasing          // ease-out for enter
    val ExitEasing = androidx.compose.animation.core.LinearOutSlowInEasing // ease-in for exit

    const val LIST_SLIDE_DP = 8
    const val LIST_STAGGER_MS = 30
    const val MAX_STAGGER = 6

    // Floating bubbles: snap-to-edge spring, damping 0.8, no overshoot beyond 2dp,
    // dim to 70% after 3s idle.
    const val BUBBLE_DAMPING_RATIO = 0.8f
    const val BUBBLE_MAX_OVERSHOOT_DP = 2
    const val BUBBLE_IDLE_DIM_MS = 3000L
    const val BUBBLE_DIM_ALPHA = 0.7f
}

/** True when the user disabled animations (animator duration scale == 0). Everything becomes a crossfade. */
@Composable
fun rememberReduceMotion(): Boolean {
    val ctx = LocalContext.current
    return remember {
        Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}

/**
 * List item entrance: fade + 8dp slide over base, staggered 30ms, max 6 staggered.
 * Under Reduce Motion this is a crossfade only.
 */
fun Modifier.handyListEnter(index: Int, reduceMotion: Boolean): Modifier = composed {
    val density = LocalDensity.current
    val alpha = remember { Animatable(0f) }
    val startDy = with(density) { if (reduceMotion) 0f else HandyMotion.LIST_SLIDE_DP.dp.toPx() }
    val dy = remember { Animatable(startDy) }
    LaunchedEffect(Unit) {
        delay((min(index, HandyMotion.MAX_STAGGER - 1) * HandyMotion.LIST_STAGGER_MS).toLong())
        launch { alpha.animateTo(1f, tween(HandyMotion.BASE_MS, easing = HandyMotion.EnterEasing)) }
        if (!reduceMotion) launch { dy.animateTo(0f, tween(HandyMotion.BASE_MS, easing = HandyMotion.EnterEasing)) }
    }
    this.alpha(alpha.value).offset { IntOffset(0, dy.value.roundToInt()) }
}

/**
 * Haptics map: light on chip select / toggle, medium on screenshot captured / clip saved,
 * success on "Added to home screen". Nothing on navigation.
 */
object HandyHaptics {
    fun light(ctx: Context) = buzz(ctx, VibrationEffect.EFFECT_TICK, 15)
    fun medium(ctx: Context) = buzz(ctx, VibrationEffect.EFFECT_CLICK, 30)
    fun success(ctx: Context) = buzz(ctx, VibrationEffect.EFFECT_HEAVY_CLICK, 45)

    private fun buzz(ctx: Context, predefined: Int, fallbackMs: Long) {
        val v = ctx.getSystemService(Vibrator::class.java) ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= 29) {
            v.vibrate(VibrationEffect.createPredefined(predefined))
        } else {
            @Suppress("DEPRECATION") v.vibrate(fallbackMs)
        }
    }
}
