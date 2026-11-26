package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

/** The trailer on Android, held to the iPhone's TrailerTests: the shape, the cuts, the score's held breath and title
 *  hit, the card fades and flashes, the narrator mixed under, and the narrator's file read back. */
class TrailerPlanTest {
    private val ps = TrailerPlan.parts()

    @Test fun theShapeIsWholeBarsWithItsCardsAndHits() {
        assertEquals(0.0, ps.first().start, 0.0)
        ps.zipWithNext().forEach { (a, b) -> assertEquals("parts follow on", a.end, b.start, 0.0001) }
        ps.forEach { assertEquals("${it.kind} starts off a bar", (it.start / TrailerPlan.bar).roundToInt().toDouble(), it.start / TrailerPlan.bar, 0.0001) }
        assertEquals(12 * TrailerPlan.bar + TrailerPlan.RING_OUT, ps.last().end, 0.001)
        assertEquals(listOf(0, 1, 2), ps.filter { it.kind == TrailerPlan.Kind.CARD }.mapNotNull { it.line })
        val hits = TrailerPlan.hits(ps)
        ps.filter { it.isCard }.forEach { assertTrue("${it.kind} doesn't hit", it.start in hits) }
        val montage = ps.first { it.kind == TrailerPlan.Kind.MONTAGE }
        assertEquals(8, hits.count { it >= montage.start && it < montage.end })
        val cues = TrailerPlan.cues(ps)
        assertEquals(listOf(0, 1, 2, 3, 4), cues.map { it.second })
        cues.forEach { (at, line) -> assertTrue("line $line isn't on a card", ps.any { it.isCard && at > it.start && at < it.end }) }
    }

    @Test fun theCutsFillEveryMomentAndSlowShotsAreSlow() {
        val lengths = listOf(6.0, 2.0, 11.0)
        val cuts = TrailerPlan.cuts(ps, lengths)
        assertEquals(ps.last().end, cuts.sumOf { it.lasts }, 0.01)
        assertEquals(lengths.indices.toSet(), cuts.filter { it.length > 0.05 }.map { it.clip }.toSet())
        cuts.forEach { assertTrue("runs past its clip", it.from + it.length <= lengths[it.clip] + 0.001) }
        var i = 0
        for (p in ps) {
            if (p.isCard) { assertEquals(p.length, cuts[i].lasts, 0.001); assertTrue(cuts[i].length < 0.05); i++; continue }
            val n = (p.length / p.cut).roundToInt()
            cuts.subList(i, i + n).forEach { c ->
                if (p.kind == TrailerPlan.Kind.SLOW && lengths[c.clip] >= c.lasts) assertEquals("half speed", c.lasts / 2, c.length, 0.001)
                if (p.kind != TrailerPlan.Kind.SLOW && lengths[c.clip] >= c.lasts) assertEquals(c.lasts, c.length, 0.001)
            }
            i += n
        }
        assertEquals(cuts.size, i)
        assertTrue(TrailerPlan.cuts(ps, emptyList()).isEmpty())
    }

    @Test fun theScoreHoldsItsBreathThenHitsOnTheTitle() {
        val x = TrailerPlan.score(ps); val rate = Synth.RATE
        assertTrue(x.size / rate >= ps.last().end)
        assertTrue("the score clips", x.maxOf { kotlin.math.abs(it) } <= 1f)
        val title = ps.first { it.kind == TrailerPlan.Kind.TITLE }.start
        fun energy(a: Double, b: Double): Double { var s = 0.0; for (j in (a * rate).toInt() until (b * rate).toInt()) s += x[j].toDouble() * x[j]; return s / ((b - a) * rate) }
        assertTrue("half a beat of silence before the title", energy(title - TrailerPlan.beat / 2 + 0.01, title - 0.01) < 1e-6)
        assertTrue("the title lands on a big hit", energy(title, title + 0.3) > 100 * energy(title - 0.3, title - 0.01) + 1e-4)
        val slow = ps.first { it.kind == TrailerPlan.Kind.SLOW }; val montage = ps.first { it.kind == TrailerPlan.Kind.MONTAGE }
        assertTrue("the montage builds", energy(montage.start + TrailerPlan.bar, montage.end - TrailerPlan.beat) > energy(slow.start + 0.5, slow.end))
    }

    @Test fun cardsFadeInGrowAndTheTitleFlashesHardest() {
        val a = TrailerPlan.cardLook(0.0, 2.5, false, false); val b = TrailerPlan.cardLook(1.2, 2.5, false, false); val c = TrailerPlan.cardLook(2.49, 2.5, false, false)
        assertEquals(0.0, a.first, 0.001); assertEquals(1.0, b.first, 0.001); assertTrue(c.first < 0.1); assertTrue(b.second > a.second)
        val hits = listOf(0.0, 5.0)
        assertTrue(TrailerPlan.flash(5.01, hits, 5.0) > TrailerPlan.flash(0.01, hits, 5.0))
        assertEquals(0.0, TrailerPlan.flash(0.5, hits, 5.0), 0.0)
    }

    @Test fun theMusicDipsUnderTheVoice() {
        val music = FloatArray(6000) { 0.5f }
        TrailerPlan.mixVoice(FloatArray(5000) { if (it % 100 == 0) 0.8f else 0f }, music, 0.0)
        assertTrue(music[150] < 0.45f)
    }

    @Test fun theNarratorsFileIsReadBackAndDeepened() {
        val tone = FloatArray(22_050) { (0.5 * sin(2 * PI * 180 * it / 22_050.0)).toFloat() }
        val read = TrailerMaker.readWav(Dsp.wav(tone, 22_050))
        assertNotNull(read)
        assertEquals(22_050, read!!.second); assertEquals(tone.size, read.first.size)
        assertEquals(tone[1000], read.first[1000], 0.001f)
        val deep = TrailerMaker.deepen(read)
        assertTrue("resampled to the music's rate, with the hall's tail", deep.size >= (tone.size * Synth.RATE / 22_050).toInt())
        assertTrue(deep.maxOf { kotlin.math.abs(it) } in 0.5f..1f)
    }
}
