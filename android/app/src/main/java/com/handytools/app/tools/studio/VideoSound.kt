package com.handytools.app.tools.studio

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * The sound under a video in the Video Studio (the iPhone's VideoSound): the video's own sound, no sound, music Tenzy
 * makes itself (Synth — nothing borrowed, so it can be posted anywhere), or the person's own song — mixed with the
 * video's sound as much or as little as they like, repeated to the video's length and faded out at the end. The mix is
 * made here as one sound file, so what you hear is exactly what's saved.
 */
object VideoSound {
    data class Choice(val id: String, val name: String, val emoji: String)

    val choices: List<Choice> = listOf(Choice("original", "As filmed", "🎙️"), Choice("none", "No sound", "🔇")) +
        Synth.styles.map { Choice("synth:" + it.id, it.name, it.emoji) }

    /** How loud the music and the video's own sound are for a [keep] of 0 (just the music) … 1 (just the video's). */
    fun volumes(keep: Double): Pair<Float, Float> {
        val k = keep.coerceIn(0.0, 1.0)
        return min(1.0, 2 * (1 - k)).toFloat() to min(1.0, 2 * k).toFloat()
    }

    /** [song] repeated (or cut) to [n] samples, with a fade over the last [fade] samples. */
    fun fit(song: FloatArray, n: Int, fade: Int): FloatArray {
        if (song.isEmpty() || n <= 0) return FloatArray(max(0, n))
        val out = FloatArray(n) { song[it % song.size] }
        val f = min(fade, n)
        for (i in 0 until f) out[n - f + i] *= 1f - (i + 1f) / f
        return out
    }

    /** [x] at [from] samples a second, made [to] a second (straight-line in between). */
    fun resample(x: FloatArray, from: Int, to: Int): FloatArray {
        if (from == to || x.isEmpty()) return x
        val n = max(1, (x.size.toLong() * to / from).toInt())
        return FloatArray(n) { i ->
            val p = i.toDouble() * from / to
            val a = p.toInt().coerceAtMost(x.size - 1); val b = min(x.size - 1, a + 1)
            (x[a] + (x[b] - x[a]) * (p - a)).toFloat()
        }
    }

    /** The music and the video's own sound mixed (each at its volume), kept off the ceiling. */
    fun mix(music: FloatArray, video: FloatArray?, vol: Pair<Float, Float>): FloatArray {
        val out = FloatArray(music.size) { i -> music[i] * vol.first + (video?.getOrNull(i) ?: 0f) * vol.second }
        val peak = out.maxOfOrNull { kotlin.math.abs(it) } ?: 0f
        if (peak > 0.98f) for (i in out.indices) out[i] *= 0.98f / peak
        return out
    }

    class Built(val file: File?, val beats: List<Double>, val problem: String?)

    /**
     * The sound to lay under the video for [music] ("synth:<style>" or "file" with [song]), or null file for the
     * video's own ("original") or none. [seconds] is the video's length.
     */
    suspend fun build(ctx: Context, source: Uri, music: String, song: Uri?, keep: Double, seconds: Double): Built = withContext(Dispatchers.Default) {
        if (music == "original" || music == "none") return@withContext Built(null, emptyList(), null)
        val rate = Synth.RATE.toInt()
        val n = (seconds * rate).toInt()
        var beats = emptyList<Double>()
        val tune: FloatArray = if (music.startsWith("synth:")) {
            val t = Synth.track(music.removePrefix("synth:"), seconds)
            beats = t.beats.filter { it < seconds }
            t.samples
        } else {
            val u = song ?: return@withContext Built(null, emptyList(), "Choose a song first.")
            val local = FunnyMaker.local(ctx, u) ?: return@withContext Built(null, emptyList(), "That song can't be used — it may be protected. Try another file.")
            val (pcm, r) = FunnyMaker.sound(local) ?: return@withContext Built(null, emptyList(), "That song can't be used — it may be protected. Try another file.")
            if (local.parentFile?.name == "funny") local.delete()
            resample(pcm, r, rate)
        }
        val vol = volumes(keep)
        val own = if (vol.second > 0.01f) FunnyMaker.local(ctx, source)?.let { f -> FunnyMaker.sound(f)?.let { (x, r) -> resample(x, r, rate) } } else null
        val mixed = mix(fit(tune, n, min(n / 4, (1.5 * rate).toInt())), own, vol)
        val out = File(File(ctx.cacheDir, "studio").also { it.mkdirs() }, "sound-${System.nanoTime()}.wav")
        out.writeBytes(Synth.wav(mixed))
        Built(out, beats, null)
    }
}
