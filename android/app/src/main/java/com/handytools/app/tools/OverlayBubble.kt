package com.handytools.app.tools

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.dynamicanimation.animation.FloatValueHolder
import androidx.dynamicanimation.animation.SpringAnimation
import androidx.dynamicanimation.animation.SpringForce
import com.handytools.app.ui.HandyMotion
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * A draggable floating button drawn over every app. Shared by the clipboard stack,
 * screenshot tool and scratchpad. Requires SYSTEM_ALERT_WINDOW.
 */
class OverlayBubble(
    private val ctx: Context,
    iconRes: Int,
    tint: Int = Color.WHITE,
    bg: Int = 0xFF1F5EFF.toInt(),
    private val onTap: () -> Unit
) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val size = (56 * ctx.resources.displayMetrics.density).toInt()
    val view: ImageView = ImageView(ctx)
    val params = WindowManager.LayoutParams(
        size, size,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply { gravity = Gravity.TOP or Gravity.START; x = 0; y = 300 }
    private var shown = false

    init {
        view.setImageResource(iconRes)
        view.setColorFilter(tint)
        val pad = size / 4
        view.setPadding(pad, pad, pad, pad)
        view.background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(bg) }
        view.elevation = 12f
        attachDrag()
    }

    private val dimHandler = Handler(Looper.getMainLooper())
    private val dimTask = Runnable {
        // Dim to 70% after 3s idle (fast fade; skipped if the user grabs the bubble).
        ValueAnimator.ofFloat(view.alpha, HandyMotion.BUBBLE_DIM_ALPHA).apply {
            duration = HandyMotion.FAST_MS.toLong()
            addUpdateListener { view.alpha = it.animatedValue as Float }
            start()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachDrag() {
        var startX = 0; var startY = 0; var touchX = 0f; var touchY = 0f; var moved = false
        view.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x; startY = params.y; touchX = e.rawX; touchY = e.rawY; moved = false
                    dimHandler.removeCallbacks(dimTask)
                    view.animate().cancel(); view.alpha = 1f
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - touchX; val dy = e.rawY - touchY
                    if (abs(dx) > 8 || abs(dy) > 8) moved = true
                    params.x = (startX + dx).toInt(); params.y = (startY + dy).toInt()
                    if (shown) wm.updateViewLayout(view, params)
                    true
                }
                MotionEvent.ACTION_UP -> { if (!moved) onTap(); snapToEdge(); true }
                else -> false
            }
        }
    }

    /**
     * Snap to the nearest edge with a spring (damping 0.8). The animated position is clamped
     * so overshoot never exceeds 2dp past the target edge.
     */
    private fun snapToEdge() {
        val w = ctx.resources.displayMetrics.widthPixels
        val target = if (params.x + size / 2 < w / 2) 0 else w - size
        val maxDev = HandyMotion.BUBBLE_MAX_OVERSHOOT_DP * ctx.resources.displayMetrics.density
        val anim = SpringAnimation(FloatValueHolder(params.x.toFloat())).apply {
            spring = SpringForce(target.toFloat())
                .setDampingRatio(HandyMotion.BUBBLE_DAMPING_RATIO)
                .setStiffness(SpringForce.STIFFNESS_MEDIUM)
            addUpdateListener { _, value, _ ->
                params.x = value.coerceIn(target - maxDev, target + maxDev).roundToInt()
                if (shown) wm.updateViewLayout(view, params)
            }
            addEndListener { _, _, _, _ ->
                params.x = target
                if (shown) wm.updateViewLayout(view, params)
                scheduleDim()
            }
        }
        anim.start()
    }

    private fun scheduleDim() {
        dimHandler.removeCallbacks(dimTask)
        dimHandler.postDelayed(dimTask, HandyMotion.BUBBLE_IDLE_DIM_MS)
    }

    fun show() { if (!shown) { wm.addView(view, params); shown = true; scheduleDim() } }
    fun hide() { if (shown) { dimHandler.removeCallbacks(dimTask); runCatching { wm.removeView(view) }; shown = false } }
    fun setVisible(v: Boolean) { view.visibility = if (v) View.VISIBLE else View.GONE }
    val isShown get() = shown
}

/** Full-width panel anchored to the bottom, used for the clipboard list and scratchpad editor. */
/**
 * [focusable] = true lets the panel take keyboard input (scratchpad). The clipboard panel passes
 * false so the app underneath keeps input focus and ACTION_PASTE lands in the right field.
 */
class OverlayPanel(ctx: Context, val content: View, heightDp: Int = 360, focusable: Boolean = false) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val d = ctx.resources.displayMetrics.density
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT, (heightDp * d).toInt(),
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            (if (focusable) 0 else WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
        PixelFormat.TRANSLUCENT
    ).apply { gravity = Gravity.BOTTOM; softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE }
    private var shown = false

    init {
        content.background = GradientDrawable().apply {
            setColor(0xF216161C.toInt()); cornerRadii = floatArrayOf(24 * d, 24 * d, 24 * d, 24 * d, 0f, 0f, 0f, 0f)
        }
        content.elevation = 20f
        content.setOnTouchListener { _, e -> if (e.action == MotionEvent.ACTION_OUTSIDE) { hide(); true } else false }
    }

    fun show() { if (!shown) { wm.addView(content, params); shown = true } }
    fun hide() { if (shown) { runCatching { wm.removeView(content) }; shown = false } }
    fun toggle() = if (shown) hide() else show()
    val isShown get() = shown
}
