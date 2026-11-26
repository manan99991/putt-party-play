package com.handytools.app.tools.studio

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The movie trailer's shape, score and timings — the iPhone's Trailer, rule for rule, in pure Kotlin so it's tested
 * on the JVM: twelve bars of black title cards, slow motion, quicker cuts, a montage on every beat over a riser, half
 * a beat of silence, the title on the biggest hit, then "Coming soon".
 */
object TrailerPlan {
    const val BPM = 96.0
    val beat: Double get() = 60 / BPM
    val bar: Double get() = beat * 4
    /** How long the last card rings after its final bar. */
    const val RING_OUT = 1.2

    enum class Kind { CARD, SLOW, SHOTS, MONTAGE, TITLE, END }

    data class Part(val kind: Kind, val start: Double, val length: Double, val cut: Double = 0.0, val line: Int? = null) {
        val end: Double get() = start + length
        val isCard: Boolean get() = kind == Kind.CARD || kind == Kind.TITLE || kind == Kind.END
    }

    fun parts(): List<Part> {
        val out = mutableListOf<Part>(); var at = 0.0
        fun add(k: Kind, bars: Double, cut: Double = 0.0, line: Int? = null, extra: Double = 0.0) {
            out += Part(k, at, bars * bar + extra, cut, line); at += bars * bar + extra
        }
        add(Kind.CARD, 1.0, line = 0)
        add(Kind.SLOW, 2.0, cut = bar)              // slow motion under the first line
        add(Kind.CARD, 1.0, line = 1)
        add(Kind.SHOTS, 2.0, cut = beat * 2)
        add(Kind.CARD, 1.0, line = 2)
        add(Kind.MONTAGE, 2.0, cut = beat)          // a cut on every beat, building to…
        add(Kind.TITLE, 2.0)                        // …the title, on the big hit
        add(Kind.END, 1.0, extra = RING_OUT)        // "Coming soon"
        return out
    }

    /** The moments that hit: every card, every montage cut, the title. */
    fun hits(parts: List<Part>): List<Double> = parts.flatMap { p ->
        when (p.kind) {
            Kind.CARD, Kind.TITLE, Kind.END -> listOf(p.start)
            Kind.MONTAGE -> generateSequence(p.start) { it + p.cut }.takeWhile { it < p.end - 0.001 }.toList()
            else -> emptyList()
        }
    }

    /** Which clip and piece fills each moment, in order: one-frame placeholders under the cards, slow parts at half speed. */
    fun cuts(parts: List<Part>, lengths: List<Double>): List<Reels.Cut> {
        if (lengths.isEmpty()) return emptyList()
        val counts = parts.map { if (it.isCard) 0 else max(1, (it.length / it.cut).roundToInt()) }
        val uses = IntArray(lengths.size)
        repeat(counts.sum()) { uses[it % lengths.size]++ }
        val seen = IntArray(lengths.size)
        val out = mutableListOf<Reels.Cut>(); var k = 0
        parts.zip(counts).forEach { (p, n) ->
            if (p.isCard) { out += Reels.Cut(0, 0.0, 1.0 / 30, p.length); return@forEach }
            val lasts = p.length / n
            repeat(n) {
                val c = k % lengths.size
                val need = if (p.kind == Kind.SLOW) lasts / 2 else lasts
                val len = min(need, max(0.1, lengths[c]))
                val margin = min(0.4, max(0.0, (lengths[c] - len) / 4))
                val room = max(0.0, lengths[c] - len - 2 * margin)
                val from = margin + room * (seen[c] + 0.5) / max(1, uses[c])
                seen[c]++; k++
                out += Reels.Cut(c, from, len, lasts)
            }
        }
        return out
    }

    /** The score made to the parts: drones and braams on cards, drums under shots, a building montage, the held breath, the title hit. */
    fun score(parts: List<Part>): FloatArray {
        val rate = Synth.RATE
        val out = FloatArray((((parts.lastOrNull()?.end ?: 0.0) + 0.5) * rate).toInt())
        val roots = listOf(33, 41, 36, 43); val chords = listOf(listOf(57, 60, 64), listOf(53, 57, 60), listOf(48, 52, 55), listOf(55, 59, 62))
        val tk = Synth.taiko(); val k = Synth.kick(1.2)
        for (p in parts) {
            val firstBar = (p.start / bar).roundToInt()
            val bars = max(1, (p.length / bar).toInt())
            for (b in 0 until bars) {
                val t0 = p.start + b * bar; val j = (firstBar + b) % 4
                val bright = if (p.kind == Kind.MONTAGE) 2200.0 else if (p.isCard) 800.0 else 1300.0
                Synth.mix(Synth.pad(chords[j].map { it - 12 }, bar, bright), out, t0, if (p.isCard) 0.6f else 0.8f)
                when (p.kind) {
                    Kind.SLOW -> { Synth.mix(tk, out, t0, 0.75f); Synth.mix(tk, out, t0 + 2 * beat, 0.55f) }
                    Kind.SHOTS -> {
                        for (q in 0 until 4) Synth.mix(tk, out, t0 + q * beat, if (q % 2 == 0) 0.8f else 0.55f)
                        Synth.mix(k, out, t0, 0.7f); Synth.mix(k, out, t0 + 2 * beat, 0.6f)
                    }
                    Kind.MONTAGE -> {
                        val lift = (0.6 + 0.4 * b / max(1, bars - 1)).toFloat()
                        for (e in 0 until 8) Synth.mix(tk, out, t0 + e * beat / 2, (if (e % 2 == 0) 0.75f else 0.5f) * lift)
                        for (q in 0 until 4) Synth.mix(k, out, t0 + q * beat, 0.7f * lift)
                    }
                    else -> {}
                }
            }
            when (p.kind) {
                Kind.CARD -> { Synth.mix(Synth.braam(roots[firstBar % 4], bar * 1.2), out, p.start, 0.9f); Synth.mix(tk, out, p.start, 0.8f) }
                Kind.MONTAGE -> Synth.mix(Synth.riser(p.length), out, p.start, 0.9f)
                Kind.TITLE -> {
                    Synth.mix(Synth.braam(33, p.length), out, p.start, 1f)
                    Synth.mix(tk, out, p.start, 1f); Synth.mix(k, out, p.start, 1f); Synth.mix(tk, out, p.start + bar, 0.6f)
                }
                Kind.END -> { Synth.mix(tk, out, p.start, 0.55f); Synth.mix(Synth.pad(chords[0], p.length, 1600.0), out, p.start, 0.7f) }
                else -> {}
            }
        }
        // The held breath: half a beat of nothing right before the title lands.
        parts.firstOrNull { it.kind == Kind.TITLE }?.let { t ->
            for (i in max(0, ((t.start - beat / 2) * rate).toInt()) until min(out.size, (t.start * rate).toInt())) out[i] = 0f
        }
        return Dsp.level(out)
    }

    /** When each spoken line starts: a card's line just after its braam, the title after its hit (3), "Coming soon" (4). */
    fun cues(parts: List<Part>): List<Pair<Double, Int>> = parts.mapNotNull { p ->
        when (p.kind) {
            Kind.CARD -> p.line?.let { (p.start + 0.25) to it }
            Kind.TITLE -> (p.start + 0.7) to 3
            Kind.END -> (p.start + 0.2) to 4
            else -> null
        }
    }

    /** The narrator over the music, the music dipping under the voice so every word is heard. */
    fun mixVoice(voice: FloatArray, music: FloatArray, at: Double) {
        val start = (at * Synth.RATE).toInt()
        if (start >= music.size || voice.isEmpty()) return
        val w = 0.04f * Synth.RATE.toFloat()
        var env = 0f
        for (i in voice.indices) {
            if (start + i >= music.size) break
            val v = abs(voice[i]); env = if (v > env) v else env * (1 - 1 / w)
            music[start + i] = music[start + i] * (1 - 0.55f * min(1f, env * 4)) + voice[i] * 0.9f
        }
    }

    /** How a card shows dt seconds into its length: fading in and out, slowly growing. Pure. */
    fun cardLook(dt: Double, length: Double, title: Boolean, end: Boolean): Pair<Double, Double> {
        val fadeIn = if (title) 0.15 else 0.45; val fadeOut = if (end) 0.6 else 0.3
        val a = (dt / fadeIn).coerceIn(0.0, 1.0) * ((length - dt) / fadeOut).coerceIn(0.0, 1.0)
        val p = (dt / max(0.1, length)).coerceIn(0.0, 1.0)
        return a to 1 + (if (title) 0.1 else 0.06) * p
    }

    /** The flash on a hit (bigger on the title). */
    fun flash(t: Double, hits: List<Double>, title: Double): Double {
        var f = 0.0
        for (h in hits) if (t >= h && t - h < 0.2) f = max(f, (if (abs(h - title) < 0.01) 0.9 else 0.45) * (1 - (t - h) / 0.2))
        return f
    }
}
