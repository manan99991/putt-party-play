package com.handytools.app.tools.autoruns

import java.time.DayOfWeek
import java.time.LocalTime
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Smart autoruns on Android (the iPhone's, 25 Nov): the jobs a personal assistant would do at the end of the day on
 * what the person made that day. Once or twice a day (12 hours apart), or once a week. Everything is read and made on
 * the phone; nothing leaves it, and nothing is deleted, sent or added without the person seeing it first.
 *
 * This file is the pure part — what each autorun is, when it comes due, what it looks at and in what order — the same
 * rules as the iPhone's SmartRuns, so it's unit-tested the same way.
 */
object SmartRuns {
    enum class Section(val title: String) { MONEY("Money & paperwork"), MEDIA("Photos & videos"), CARE("Looking after your phone") }
    enum class Media { PHOTOS, VIDEOS, PHOTOS_AND_PDFS, RECORDS, AUDIO }

    /** One autorun: its id (the iPhone's), title and what it does (the iPhone's words, so they share translations),
     *  where it's listed, what it looks through, its colour, the Android tools whose use by hand suggests it, and how
     *  many of its things in two weeks make it worth offering on their own. */
    enum class Kind(val id: String, val title: String, val line: String, val section: Section, val looksAt: Media, val color: Long,
                    val habitTools: Set<String>, val threshold: Int) {
        RECEIPTS("receipts", "Today's receipts into my expense sheet",
            "Finds the receipts you photographed or saved as PDFs today and adds each one to your expense sheet — shop, date, total, tax — after you look them over.",
            Section.MONEY, Media.PHOTOS_AND_PDFS, 0xFF10B981, setOf("receipts", "sorted"), 8),
        DRIVES("drives", "Today's drives into my mileage log",
            "Lists the drives your phone noticed today — when, from where to where, how far. Tap which were for work and they go into your mileage log with the IRS rate.",
            Section.MONEY, Media.RECORDS, 0xFF0EA5E9, setOf("gpsdash"), 6),
        OVERDUE_INVOICES("overdueInvoices", "Nudge me about overdue invoices",
            "When an invoice passes its pay-by day, a reminder email is ready — the invoice attached, the right tone for how late it is. You read it and tap Send.",
            Section.MONEY, Media.RECORDS, 0xFFEF4444, setOf("invoice"), 2),
        HEAVY_VIDEOS("heavyVideos", "Make today's heavy videos smaller",
            "Re-saves today's big videos in a smaller format that looks the same, checks every one frame by frame, and shows how much space you'd get back.",
            Section.MEDIA, Media.VIDEOS, 0xFF8B5CF6, setOf("media", "converter"), 4),
        TIDY_PHOTOS("tidyPhotos", "Tidy up screenshots, duplicates and bursts",
            "Finds old screenshots you won't need, copies of the same photo and the hidden extra frames of bursts — keeping receipts, tickets, codes, favourites and the best copy — and shows how much space they'd free.",
            Section.CARE, Media.PHOTOS, 0xFF14B8A6, setOf("cleanup", "storage"), 200),
        READY_TO_POST("readyToPost", "Get today's best videos ready to post",
            "Picks today's best clips, gives them your look and the tall size Reels, TikTok and Shorts want, ready for you to watch and post.",
            Section.MEDIA, Media.VIDEOS, 0xFFEC4899, setOf("videofx", "beatreel"), 10),
        DAY_COLLAGE("dayCollage", "Today's photos as one collage",
            "Picks the best photos of the people you took today — sharp, no repeats — and lays them out as one beautiful picture to keep or send.",
            Section.MEDIA, Media.PHOTOS, 0xFFF59E0B, setOf("stitch", "memory"), 30),
        BUSINESS_CARDS("businessCards", "Business cards into my contacts",
            "Reads the business cards you photographed today and turns each into a contact, skipping anyone you already have.",
            Section.MONEY, Media.PHOTOS, 0xFF3B82F6, setOf("wallet"), 5),
        PAPER_PDFS("paperPDFs", "Today's paper into searchable PDFs",
            "Turns the letters, bills and forms you photographed today into clean, flat PDFs you can search — pages taken together become one file, named from what it says.",
            Section.MONEY, Media.PHOTOS, 0xFF6366F1, setOf("docs", "pdfconvert"), 6),
        WEEK_FILM("weekFilm", "My week, as one short film",
            "Once a week, picks the best moments — sharp photos of your people, the liveliest seconds of your clips — and cuts them into one tall film, day by day, with a title. Watch it, add your music, keep it.",
            Section.MEDIA, Media.PHOTOS, 0xFFF97316, setOf("beatreel", "trailer", "videofx"), 40),
        CONTACTS_BACKUP("contactsBackup", "Back up my contacts every week",
            "Saves a copy of every contact to Files each week and tells you if anyone has disappeared since the last copy — one tap brings back a contact deleted by mistake.",
            Section.CARE, Media.RECORDS, 0xFF0891B2, setOf("cleanup"), 1000000),
        VOICE_NOTES("voiceNotes", "Voice memos into written notes",
            "Listens to the voice memos you saved today — on your phone, nothing sent anywhere — and writes each one up: what it's about, the key points, and the to-dos with who and when, ready for Reminders.",
            Section.MONEY, Media.AUDIO, 0xFF7C3AED, setOf("voice"), 1000000),
        ;
        /** Comes back once a week, not every day. */
        val weekly: Boolean get() = this == WEEK_FILM || this == CONTACTS_BACKUP

        companion object { fun of(id: String): Kind? = entries.firstOrNull { it.id == id } }
    }

    /** One autorun as the person set it: on, once or twice a day (the second 12 hours after the first), the time, and
     *  for weekly ones the day (1 = Sunday … 7 = Saturday, as the iPhone counts). */
    data class Plan(val on: Boolean = false, val twice: Boolean = false, val hour: Int = 20, val minute: Int = 0, val weekday: Int? = null) {
        /** The times of day it comes back, earliest first. */
        val times: List<Pair<Int, Int>> get() {
            val h = hour.coerceIn(0, 23); val m = minute.coerceIn(0, 59)
            return if (twice && weekday == null) listOf(h to m, (h + 12) % 24 to m).sortedBy { it.first * 60 + it.second } else listOf(h to m)
        }

        companion object {
            /** How a new autorun starts: daily ones at 8 in the evening; the week's film Sunday at 6, the contacts copy Sunday at 9. */
            fun start(k: Kind): Plan = when {
                k == Kind.CONTACTS_BACKUP -> Plan(hour = 21, weekday = 1)
                k.weekly -> Plan(hour = 18, weekday = 1)
                else -> Plan()
            }
        }
    }

    /** What's looked at: everything since the last run, never more than 36 hours back, the last 24 hours on a first run. */
    fun window(lastRun: Long?, now: Long): LongRange {
        val floor = now - 36L * 3600_000
        val start = max(lastRun ?: (now - 24L * 3600_000), floor)
        return min(start, now)..now
    }

    private fun dow(weekday: Int): DayOfWeek = DayOfWeek.of(((weekday.coerceIn(1, 7) + 5) % 7) + 1)   // 1 Sunday → SUNDAY

    /** The next time a plan comes due after [now], in the phone's zone. */
    fun nextDue(p: Plan, now: ZonedDateTime): ZonedDateTime? {
        if (!p.on) return null
        return p.times.map { (h, m) ->
            var c = now.with(LocalTime.of(h, m)).truncatedTo(ChronoUnit.MINUTES)
            if (p.weekday != null) {
                c = c.with(TemporalAdjusters.nextOrSame(dow(p.weekday)))
                if (!c.isAfter(now)) c = c.plusWeeks(1)
            } else if (!c.isAfter(now)) c = c.plusDays(1)
            c
        }.minOrNull()
    }

    /** Whether a run is due: a chosen time has passed since the last one (or, never run, today's first time has passed). */
    fun isDue(p: Plan, lastRun: ZonedDateTime?, now: ZonedDateTime): Boolean {
        if (!p.on) return false
        val since = lastRun ?: now.truncatedTo(ChronoUnit.DAYS)
        val next = nextDue(p, since) ?: return false
        return !next.isAfter(now)
    }

    // ---- picking what to work on ----

    /** What the photo reading found in a photo (labels, its words, how many faces, how sharp 0…1). */
    data class PhotoSeen(val labels: List<String>, val text: String, val faces: Int, val sharpness: Double = 1.0)

    /** A thing found in the window: a photo, a video or a PDF. */
    data class Found(val id: String, val created: Long, val isVideo: Boolean = false, val isScreenshot: Boolean = false,
                     val bytes: Long = 0, val seconds: Double = 0.0, val width: Int = 0, val height: Int = 0, val seen: PhotoSeen? = null)

    /** Heavy videos worth re-saving: at least 60 MB, or at least 25 MB a minute. Biggest first. */
    fun heavy(items: List<Found>, minBytes: Long = 60_000_000, minPerMinute: Double = 25_000_000.0): List<Found> =
        items.filter { it.isVideo && it.bytes > 0 }
            .filter { it.bytes >= minBytes || (it.seconds > 0 && it.bytes / (it.seconds / 60) >= minPerMinute) }
            .sortedByDescending { it.bytes }

    /** Photos for the day's collage: people, not screenshots or documents, sharp enough, one per burst (within 3 s, the
     *  sharpest kept); little ones first, the rest spread across the day. At most [limit]. */
    fun collagePicks(items: List<Found>, limit: Int = 10): List<Found> {
        val people = items.filter { f ->
            val s = f.seen ?: return@filter false
            !f.isVideo && !f.isScreenshot && s.faces > 0 && s.text.split(' ', '\n').count { it.isNotEmpty() } < 20 && s.sharpness >= 0.35
        }.sortedBy { it.created }
        val moments = ArrayList<Found>()
        for (f in people) {
            val last = moments.lastOrNull()
            if (last != null && f.created - last.created < 3000) {
                if ((f.seen?.sharpness ?: 0.0) > (last.seen?.sharpness ?: 0.0)) moments[moments.size - 1] = f
            } else moments += f
        }
        if (moments.size <= limit) return moments
        fun little(f: Found) = f.seen?.labels?.any { it in setOf("baby", "child", "toddler", "kid", "infant") } == true
        fun spread(xs: List<Found>, n: Int): List<Found> = when {
            n <= 0 -> emptyList()
            xs.size <= n -> xs
            n == 1 -> listOf(xs[xs.size / 2])
            else -> (0 until n).map { xs[(it.toDouble() * (xs.size - 1) / (n - 1)).roundToInt()] }
        }
        val kids = moments.filter(::little); val rest = moments.filterNot(::little)
        val k = min(limit, kids.size)
        return (spread(kids, k) + spread(rest, limit - k)).sortedBy { it.created }
    }

    /** Clips worth making ready to post: 4 s to 3 min with a real size, newest first, at most [limit]. */
    fun postPicks(items: List<Found>, limit: Int = 3): List<Found> =
        items.filter { it.isVideo && it.seconds in 4.0..180.0 && it.width > 0 && it.height > 0 }.sortedByDescending { it.created }.take(limit)

    // ---- is the smaller video as good? ----

    /** Peak signal-to-noise ratio between two same-size grey frames, in dB (identical is 99). */
    fun psnr(a: ByteArray, b: ByteArray): Double {
        if (a.size != b.size || a.isEmpty()) return 0.0
        var sum = 0.0
        for (i in a.indices) { val d = (a[i].toInt() and 0xFF) - (b[i].toInt() and 0xFF); sum += (d * d).toDouble() }
        val mse = sum / a.size
        if (mse <= 0) return 99.0
        return 10 * log10(255.0 * 255.0 / mse)
    }

    /** The bar a re-saved video must clear on every checked frame to count as "looks the same". */
    const val SAME_PICTURE_DB = 38.0

    /** A smaller video is offered only when it saves real space: at least 20% and at least 10 MB. */
    fun worthIt(original: Long, smaller: Long): Boolean =
        smaller in 1 until original && (original - smaller).toDouble() >= max(10_000_000.0, original * 0.2)

    // ---- habits ----

    /** The autoruns someone's habits suggest: a matching tool used on 3 or more days lately, or its things showing up
     *  often; strongest first; ones already on or put off left out. */
    fun suggested(toolDays: Map<String, Set<Int>>, found: Map<Kind, Int>, on: Set<Kind>, hidden: Set<Kind>): List<Kind> =
        Kind.entries.mapNotNull { k ->
            if (k in on || k in hidden) return@mapNotNull null
            val days = k.habitTools.flatMap { toolDays[it].orEmpty() }.toSet().size
            val seen = found[k] ?: 0
            if (days >= 3 || seen >= k.threshold) k to days * 2 + seen else null
        }.sortedByDescending { it.second }.map { it.first }
}
