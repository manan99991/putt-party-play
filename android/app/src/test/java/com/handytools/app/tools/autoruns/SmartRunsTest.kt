package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

/** Smart autoruns on Android: the iPhone's rules for when they come back, what they look at and what they pick. */
class SmartRunsTest {
    private val zone = ZoneId.of("America/Chicago")
    private fun at(d: Int, h: Int, m: Int = 0) = ZonedDateTime.of(2026, 11, d, h, m, 0, 0, zone)
    private fun ms(z: ZonedDateTime) = z.toInstant().toEpochMilli()

    @Test fun twiceADayIsTwelveHoursApart() {
        val p = SmartRuns.Plan(on = true, twice = true, hour = 20, minute = 30)
        assertEquals(listOf(8 to 30, 20 to 30), p.times)
        assertEquals(1, p.copy(twice = false).times.size)
    }

    @Test fun itComesBackAtTheNextChosenTime() {
        val p = SmartRuns.Plan(on = true, twice = true, hour = 8)
        assertEquals(at(25, 20), SmartRuns.nextDue(p, at(25, 9)))
        assertEquals(at(26, 8), SmartRuns.nextDue(p, at(25, 21)))
        assertNull("an autorun that's off never comes back", SmartRuns.nextDue(SmartRuns.Plan(on = false), at(25, 9)))
        // Weekly: Sunday 29 Nov 2026 at 6 in the evening, then the Sunday after.
        val week = SmartRuns.Plan.start(SmartRuns.Kind.WEEK_FILM).copy(on = true)
        assertEquals(at(29, 18), SmartRuns.nextDue(week, at(25, 9)))
        assertEquals(at(29, 18).plusWeeks(1), SmartRuns.nextDue(week, at(29, 19)))
    }

    @Test fun dueOnlyOncePerChosenTime() {
        val p = SmartRuns.Plan(on = true, hour = 20)
        assertFalse("not before the time", SmartRuns.isDue(p, null, at(25, 19)))
        assertTrue(SmartRuns.isDue(p, null, at(25, 20, 5)))
        assertFalse("already ran tonight", SmartRuns.isDue(p, at(25, 20, 6), at(25, 23)))
        assertTrue("tomorrow night again", SmartRuns.isDue(p, at(25, 20, 6), at(26, 20, 1)))
    }

    @Test fun itLooksAtWhatsNewButNeverAWeekAtOnce() {
        val now = ms(at(25, 20))
        assertEquals("first run: the last 24 hours", 24L * 3600_000, SmartRuns.window(null, now).let { it.last - it.first })
        assertEquals("since the last run", ms(at(25, 8)), SmartRuns.window(ms(at(25, 8)), now).first)
        assertEquals("a phone in a drawer for a week", 36L * 3600_000, SmartRuns.window(ms(at(18, 8)), now).let { it.last - it.first })
    }

    private fun video(id: String, mb: Double, seconds: Double, minute: Int = 0) =
        SmartRuns.Found(id, ms(at(25, 12, minute)), isVideo = true, bytes = (mb * 1_000_000).toLong(), seconds = seconds, width = 1920, height = 1080)

    @Test fun onlyHeavyVideosAreResaved() {
        val picks = SmartRuns.heavy(listOf(video("small", 8.0, 30.0), video("long", 180.0, 240.0), video("dense", 40.0, 50.0)))
        assertEquals("biggest first; a light clip is left alone", listOf("long", "dense"), picks.map { it.id })
    }

    @Test fun aSmallerVideoMustSaveRealSpace() {
        assertTrue(SmartRuns.worthIt(200_000_000, 90_000_000))
        assertFalse("8% isn't worth replacing the original", SmartRuns.worthIt(200_000_000, 185_000_000))
        assertFalse("5 MB isn't worth it", SmartRuns.worthIt(30_000_000, 25_000_000))
        assertFalse(SmartRuns.worthIt(30_000_000, 0))
    }

    @Test fun theSamePictureBar() {
        val a = ByteArray(10_000) { (it % 256).toByte() }
        assertEquals(99.0, SmartRuns.psnr(a, a), 0.0)
        val near = ByteArray(a.size) { i -> val v = a[i].toInt() and 0xFF; (if (v < 255) v + 1 else v).toByte() }
        assertTrue(SmartRuns.psnr(a, near) > SmartRuns.SAME_PICTURE_DB)
        val soft = ByteArray(a.size) { i -> ((a[i].toInt() and 0xFF) + if (i % 2 == 0) 12 else -12).coerceIn(0, 255).toByte() }
        assertTrue(SmartRuns.psnr(a, soft) < SmartRuns.SAME_PICTURE_DB)
        assertEquals("different sizes never pass", 0.0, SmartRuns.psnr(a, a.copyOf(10)), 0.0)
    }

    private fun photo(id: String, second: Double, faces: Int = 1, labels: List<String> = emptyList(), sharp: Double = 0.9, shot: Boolean = false, text: String = "") =
        SmartRuns.Found(id, ms(at(25, 9)) + (second * 1000).toLong(), isScreenshot = shot, seen = SmartRuns.PhotoSeen(labels, text, faces, sharp))

    @Test fun theCollageKeepsOnePerMomentAndOnlyPeople() {
        val picks = SmartRuns.collagePicks(listOf(
            photo("a", 0.0, sharp = 0.5), photo("a-sharper", 1.0, sharp = 0.95),      // one burst: the sharper one
            photo("nobody", 60.0, faces = 0), photo("shot", 120.0, shot = true),
            photo("menu", 180.0, text = (1..30).joinToString(" ") { "word" }), photo("blurry", 240.0, sharp = 0.1),
            photo("b", 300.0),
        ))
        assertEquals(listOf("a-sharper", "b"), picks.map { it.id })
    }

    @Test fun theCollageFavoursLittleOnesAndSpreadsAcrossTheDay() {
        val many = (0 until 30).map { photo("p$it", it * 600.0) } + listOf(photo("baby", 7000.0, labels = listOf("baby")))
        val picks = SmartRuns.collagePicks(many, limit = 5)
        assertEquals(5, picks.size)
        assertTrue(picks.any { it.id == "baby" })
        assertTrue("spread across the day, not the first minutes", picks.last().created - picks.first().created > 3 * 3600_000L)
    }

    @Test fun postPicksAreRealClipsNewestFirst() {
        val picks = SmartRuns.postPicks(listOf(video("old", 20.0, 30.0, 1), video("new", 20.0, 30.0, 50), video("tiny", 5.0, 2.0, 55), video("long", 900.0, 600.0, 56)))
        assertEquals(listOf("new", "old"), picks.map { it.id })
    }

    @Test fun toolDaysCountDaysNotOpens() {
        var log: Map<String, List<Int>> = emptyMap()
        log = ToolDays.noted(log, "receipts", 100); log = ToolDays.noted(log, "receipts", 100); log = ToolDays.noted(log, "receipts", 101)
        assertEquals("two opens on one day is one day", listOf(100, 101), log["receipts"])
        log = ToolDays.noted(log, "wallet", 140)
        assertNull("a month later the old days are gone", log["receipts"])
        assertEquals(listOf(140), log["wallet"])
        val tokyo = ZoneId.of("Asia/Tokyo")
        val late = ZonedDateTime.of(2026, 11, 25, 23, 50, 0, 0, tokyo).toInstant().toEpochMilli()
        assertEquals("the person's own midnight, not London's", ToolDays.day(late, tokyo), ToolDays.day(late - 20 * 3600_000L, tokyo))
    }

    @Test fun habitsSuggestTheRightAutorun() {
        // Receipt tools on 4 separate days; the video tool on two; lots of photos of people. (Ids are Android routes.)
        val days = mapOf("receipts" to setOf(1, 3), "sorted" to setOf(5, 8), "media" to setOf(2, 9))
        val s = SmartRuns.suggested(days, mapOf(SmartRuns.Kind.DAY_COLLAGE to 45, SmartRuns.Kind.BUSINESS_CARDS to 1), emptySet(), emptySet())
        assertEquals(SmartRuns.Kind.DAY_COLLAGE, s.first())
        assertTrue(SmartRuns.Kind.RECEIPTS in s)
        assertFalse("two days isn't a habit", SmartRuns.Kind.HEAVY_VIDEOS in s)
        assertFalse(SmartRuns.Kind.BUSINESS_CARDS in s)
        assertFalse("one put off is never offered again",
            SmartRuns.Kind.RECEIPTS in SmartRuns.suggested(days, mapOf(SmartRuns.Kind.DAY_COLLAGE to 45), setOf(SmartRuns.Kind.DAY_COLLAGE), setOf(SmartRuns.Kind.RECEIPTS)))
        // Every habit tool is a real Android tool route.
        val routes = setOf("receipts", "sorted", "gpsdash", "invoice", "cleanup", "storage", "media", "converter", "videofx", "beatreel",
            "stitch", "memory", "wallet", "docs", "pdfconvert", "trailer", "voice")
        for (k in SmartRuns.Kind.entries) assertTrue(k.id, k.habitTools.all { it in routes })
        assertEquals(3, SmartRuns.Section.entries.size)
        assertTrue(SmartRuns.Kind.entries.all { SmartRuns.Kind.of(it.id) == it })
    }
}
