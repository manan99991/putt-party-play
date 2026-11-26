package com.handytools.app.tools.studio

import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Funny moments — the iPhone's FunnyMoment, rule for rule, in pure Kotlin: one moment of a video gets a classic comedy
 * beat (record-scratch freeze, dramatic zoom, crickets, air horns, boing, ba-dum-tss), found for you as the loudest
 * laugh or shout, with Tenzy's own sound (Synth). The timings are tested on the JVM.
 */
object FunnyPlan {
    data class Kind(val id: String, val name: String, val emoji: String, val line: String, val sound: String, val freeze: Double, val words: String)

    val kinds = listOf(
        Kind("scratch", "Record scratch", "💿", "Freeze! \"Yep. That's me.\"", "scratch", 2.6, "Yep. That's me."),
        Kind("dramatic", "Dramatic zoom", "😱", "Zooms in on a face — dun dun dun", "sting", 0.0, ""),
        Kind("crickets", "Awkward silence", "🦗", "Everything stops. Crickets.", "crickets", 2.4, "…"),
        Kind("horn", "Air horns", "📯", "Horns, a flash and a shake", "horn", 0.0, ""),
        Kind("boing", "Boing", "🪀", "The picture bounces like a spring", "boing", 0.0, ""),
        Kind("rimshot", "Ba-dum-tss", "🥁", "The ending freezes on a drum hit", "rimshot", 1.8, ""),
    )
    fun kind(id: String) = kinds.firstOrNull { it.id == id } ?: kinds[0]

    /** The loudest stretch between a quarter and 85% of the way (a laugh, a shout), else 60% in; ba-dum-tss at the end. */
    fun moment(loudness: List<Double>, hop: Double, duration: Double, kind: String): Double {
        if (kind == "rimshot") return max(0.0, duration - 0.05)
        val lo = (duration * 0.25 / hop).toInt(); val hi = min(loudness.size, (duration * 0.85 / hop).toInt())
        if (hi <= lo + 2) return duration * 0.6
        var best = lo; var bestV = -1.0
        for (i in lo until hi) {
            val a = max(0, i - 2); val b = min(loudness.size - 1, i + 2)
            var s = 0.0; for (j in a..b) s += loudness[j]
            val v = s / (b - a + 1)
            if (v > bestV) { bestV = v; best = i }
        }
        return if (bestV > 0.01) best * hop else duration * 0.6
    }

    /** Loudness (RMS) every [hop] seconds of mono samples at [rate]. */
    fun loudness(x: FloatArray, rate: Int, hop: Double = 0.05): List<Double> {
        val per = max(1, (rate * hop).toInt())
        return (0 until x.size / per).map { k -> var s = 0.0; for (i in k * per until (k + 1) * per) s += x[i].toDouble() * x[i]; sqrt(s / per) }
    }

    /** What happens to the frame dt seconds after the moment: zoom, shake, flash, grey, squash and the words. */
    data class Look(val zoom: Double = 1.0, val dx: Double = 0.0, val dy: Double = 0.0, val flash: Double = 0.0, val grey: Double = 0.0, val squash: Double = 1.0, val words: Double = 0.0)

    fun look(kind: String, dt: Double, freeze: Double): Look {
        if (dt < 0) return Look()
        return when (kind) {
            "scratch", "crickets", "rimshot" -> {
                if (dt > freeze + 0.05) return Look()
                val p = min(1.0, dt / max(0.1, freeze))
                Look(zoom = 1 + (if (kind == "rimshot") -0.06 else 0.12) * p,
                    grey = if (kind == "rimshot") 0.0 else min(1.0, dt / 0.25) * 0.85,
                    flash = if (dt < 0.12) 0.55 * (1 - dt / 0.12) else 0.0,
                    words = if (dt > 0.35) min(1.0, (dt - 0.35) / 0.25) else 0.0)
            }
            "dramatic" -> {
                if (dt > 2.6) return Look()
                var z = 1.0
                for ((at, zz) in listOf(0.0 to 1.25, 0.5 to 1.55, 1.0 to 1.95)) if (dt >= at) z = zz
                if (dt > 2.3) z = 1 + (z - 1) * max(0.0, (2.6 - dt) / 0.3)
                Look(zoom = z)
            }
            "horn" -> {
                if (dt > 1.6) return Look()
                val amp = 0.03 * max(0.0, 1 - dt / 1.6)
                var f = 0.0
                for (at in listOf(0.0, 0.24, 0.48)) if (dt >= at && dt < at + 0.1) f = 0.6 * (1 - (dt - at) / 0.1)
                Look(zoom = 1.06, dx = amp * sin(dt * 90), dy = amp * cos(dt * 77), flash = f)
            }
            "boing" -> if (dt > 0.8) Look() else Look(squash = 1 + 0.22 * sin(dt * 2 * Math.PI * 5.5) * exp(-dt * 4.5))
            else -> Look()
        }
    }
}
