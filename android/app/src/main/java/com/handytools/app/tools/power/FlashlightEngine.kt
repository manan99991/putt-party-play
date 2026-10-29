package com.handytools.app.tools.power

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.view.WindowManager
import kotlin.math.roundToInt

// ---------------------------------------------------------------------------------------------
// Flashlight+ plumbing: the real torch (with strength levels on Android 13+ where the phone
// supports them), Morse encoding, and window-brightness helpers for the screen lamps.
// ---------------------------------------------------------------------------------------------

/** Thin wrapper over the camera torch. Picks the back flash unit if there is one. */
internal class FlTorch(ctx: Context) {
    private val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    val id: String? = runCatching {
        val ids = cm.cameraIdList
        ids.firstOrNull { c ->
            val ch = cm.getCameraCharacteristics(c)
            ch.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                ch.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: ids.firstOrNull { c -> cm.getCameraCharacteristics(c).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true }
    }.getOrNull()

    val hasFlash: Boolean get() = id != null

    /** Number of torch strength steps (1 = on/off only). */
    val maxLevel: Int = if (Build.VERSION.SDK_INT >= 33 && id != null) {
        runCatching { cm.getCameraCharacteristics(id!!).get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1 }.getOrDefault(1)
    } else 1

    val hasLevels: Boolean get() = maxLevel > 1

    /** Strength used whenever the torch is switched on, 1..maxLevel. */
    @Volatile var level: Int = maxLevel

    fun setStrength(fraction: Float) { level = (fraction * maxLevel).roundToInt().coerceIn(1, maxLevel) }

    /** On/off. When the phone supports strength levels, "on" uses the current level. */
    fun set(on: Boolean) {
        val i = id ?: return
        runCatching {
            if (on && hasLevels && Build.VERSION.SDK_INT >= 33) cm.turnOnTorchWithStrengthLevel(i, level.coerceIn(1, maxLevel))
            else cm.setTorchMode(i, on)
        }
    }

    /** Sets an explicit level 0..1 (0 = off). Falls back to on/off when levels aren't supported. */
    fun setFraction(f: Float) {
        val i = id ?: return
        if (f <= 0f) { runCatching { cm.setTorchMode(i, false) }; return }
        if (hasLevels && Build.VERSION.SDK_INT >= 33) {
            runCatching { cm.turnOnTorchWithStrengthLevel(i, (f * maxLevel).roundToInt().coerceIn(1, maxLevel)) }
        } else runCatching { cm.setTorchMode(i, true) }
    }
}

/** Morse: text -> dot/dash code -> timed on/off steps. */
internal object FlMorse {
    private val TABLE = mapOf(
        'A' to ".-", 'B' to "-...", 'C' to "-.-.", 'D' to "-..", 'E' to ".", 'F' to "..-.", 'G' to "--.", 'H' to "....",
        'I' to "..", 'J' to ".---", 'K' to "-.-", 'L' to ".-..", 'M' to "--", 'N' to "-.", 'O' to "---", 'P' to ".--.",
        'Q' to "--.-", 'R' to ".-.", 'S' to "...", 'T' to "-", 'U' to "..-", 'V' to "...-", 'W' to ".--", 'X' to "-..-",
        'Y' to "-.--", 'Z' to "--..", '1' to ".----", '2' to "..---", '3' to "...--", '4' to "....-", '5' to ".....",
        '6' to "-....", '7' to "--...", '8' to "---..", '9' to "----.", '0' to "-----", ' ' to "/",
        '.' to ".-.-.-", ',' to "--..--", '?' to "..--..", '!' to "-.-.--", '/' to "-..-.", '@' to ".--.-.", '-' to "-....-",
    )

    /** "SOS" -> "... --- ...". Unknown characters are skipped. */
    fun encode(msg: String): String =
        msg.uppercase().map { TABLE[it] ?: "" }.filter { it.isNotEmpty() }.joinToString(" ")

    /** (on, millis) steps for a code string. Dot 200, dash 600, gap 200, letter gap 400, word gap 800. */
    fun sequence(code: String): List<Pair<Boolean, Long>> {
        val seq = ArrayList<Pair<Boolean, Long>>()
        for (ch in code) when (ch) {
            '.' -> { seq.add(true to 200L); seq.add(false to 200L) }
            '-' -> { seq.add(true to 600L); seq.add(false to 200L) }
            ' ' -> seq.add(false to 400L)
            '/' -> seq.add(false to 800L)
        }
        return seq
    }
}

/** Finds the Activity behind a Compose context so we can drive window brightness. */
internal fun Context.flActivity(): Activity? {
    var c: Context = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}

/** Sets the window's screen brightness override (0..1), or clears it with null. */
internal fun flSetWindowBrightness(ctx: Context, value: Float?) {
    val w = ctx.flActivity()?.window ?: return
    val lp = w.attributes
    lp.screenBrightness = value ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
    w.attributes = lp
}
