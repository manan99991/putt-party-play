package com.handytools.app

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Free-tier limits, in one place. Mirrors iOS. Free users get the full tool with a ceiling that
 *  upsells to Pro — never a dead "Pro only" wall. */
object Limits {
    const val FREE_CLIPS = 15
    const val FREE_ALARMS = 3
    const val FREE_OCR_PER_DAY = 5
    const val FREE_TRANSLATE_PER_DAY = 8
    const val FREE_AI_PER_DAY = 3
    const val FREE_WALLET_CARDS = 2
    const val FREE_VIDEO_PER_DAY = 2
    const val FREE_BG_REMOVE_PER_DAY = 5
    const val FREE_CONVERT_PER_DAY = 3
    const val FREE_AUDIO_PER_DAY = 3
    const val FREE_PDF_OPS_PER_DAY = 3
    const val FREE_SIGN_PER_DAY = 3
}

/** Per-day usage counters that reset at midnight, stored in SharedPreferences. Pro is unlimited. */
object Usage {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences("usage", 0)
    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    private fun key(name: String) = "$name.${today()}"

    private fun premium() = HandyApp.instance.billing.isPremium.value

    fun count(ctx: Context, name: String): Int = prefs(ctx).getInt(key(name), 0)

    fun hasRoom(ctx: Context, name: String, limit: Int): Boolean =
        premium() || count(ctx, name) < limit

    /** Consume one unit. Returns true if allowed. */
    fun use(ctx: Context, name: String, limit: Int): Boolean {
        if (premium()) return true
        val c = count(ctx, name)
        if (c >= limit) return false
        prefs(ctx).edit().putInt(key(name), c + 1).apply()
        return true
    }

    fun remaining(ctx: Context, name: String, limit: Int): Int =
        if (premium()) Int.MAX_VALUE else (limit - count(ctx, name)).coerceAtLeast(0)
}
