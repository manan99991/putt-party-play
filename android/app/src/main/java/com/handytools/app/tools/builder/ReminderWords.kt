package com.handytools.app.tools.builder

import java.time.ZonedDateTime

/**
 * "Remind me to call Mum at 6", "remind me every Monday to put the bins out", "remind me in 20 minutes to check the
 * oven", "tomorrow at 9 remind me to pay rent" — a remind-me sentence becomes a set reminder in one tap. The iPhone's
 * ReminderWords, rule for rule, so both phones read every sentence the same way. Pure: the sentence and the time now
 * go in, the reminder comes out (null when it isn't a reminder), so every way of saying it is unit-tested.
 */
object ReminderWords {
    /** What was said: the words to show, and when — once at [onceAt], or every [days] (1 = Sunday … 7 = Saturday; empty = every day) at [hour]:[minute]. */
    data class Said(val text: String, val once: Boolean, val onceAt: ZonedDateTime?, val days: List<Int>, val hour: Int, val minute: Int)

    fun isReminder(text: String): Boolean {
        val s = " " + text.lowercase() + " "
        return listOf(" remind me", " reminder to", " reminder for", " set a reminder", " don't let me forget", " dont let me forget").any { s.contains(it) }
    }

    private val dayNames = listOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
    private fun dayNumber(w: String): Int? { dayNames.forEachIndexed { i, n -> if (w.startsWith(n.take(3))) return i + 1 }; return null }
    private fun first(pattern: String, s: String): String? = Regex(pattern).find(s)?.value
    private fun words(m: String): List<String> = m.split(Regex("[^\\p{L}]+")).filter { it.isNotEmpty() }
    private fun at(day: ZonedDateTime, h: Int, m: Int): ZonedDateTime = day.withHour(h).withMinute(m).withSecond(0).withNano(0)
    /** 1 = Sunday … 7 = Saturday, like the iPhone's calendar. */
    fun weekday(d: ZonedDateTime): Int = d.dayOfWeek.value % 7 + 1

    fun parse(text: String, now: ZonedDateTime = ZonedDateTime.now()): Said? {
        if (!isReminder(text)) return null
        // Matched in lower case; what to be reminded of keeps the person's own capitals ("Call Mum").
        val said = (" " + text.replace("’", "'") + " ").replace(Regex("[.!?,;]"), " ")
        val s = said.lowercase()
        val cut = mutableListOf<String>()           // the time words found, taken out of what's left to say

        // Repeats
        var days = listOf<Int>()
        var repeats = false
        val weekdays = first(" (every|each) (week ?days?|weekday)s? ", s) ?: first(" (on )?weekdays ", s)
        val weekends = if (weekdays == null) first(" (every|each|on) weekends? ", s) else null
        val everyDays = if (weekdays == null && weekends == null) first(" (every|each) ((sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)(day)?s?( and |, ?| & )?)+", s) else null
        val onDays = if (weekdays == null && weekends == null && everyDays == null) first(" on ((sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)days( and |, ?| & )?)+", s) else null
        when {
            weekdays != null -> { repeats = true; days = listOf(2, 3, 4, 5, 6); cut += weekdays }
            weekends != null -> { repeats = true; days = listOf(1, 7); cut += weekends }
            everyDays != null -> { repeats = true; cut += everyDays; days = words(everyDays).filter { it !in listOf("every", "each", "and") }.mapNotNull { dayNumber(it) } }
            onDays != null -> { repeats = true; cut += onDays; days = words(onDays).filter { it !in listOf("on", "and") }.mapNotNull { dayNumber(it) } }   // "on Mondays" repeats; "on Monday" is once
            else -> (first(" (every|each) (day|morning|evening|night|afternoon) ", s) ?: first(" daily ", s))?.let { repeats = true; cut += it }
        }

        // In N minutes / hours (a one-off from now)
        var exact: ZonedDateTime? = null
        val inSome = first(" in (an?|one|\\d+|a few|a couple of) ?(half an? )?(minutes?|mins?|hours?|hrs?) ", s)
        if (inSome != null) {
            cut += inSome
            val n = inSome.trim().split(" ").getOrNull(1)?.toDoubleOrNull() ?: if (inSome.contains("few")) 3.0 else if (inSome.contains("couple")) 2.0 else 1.0
            val secs = if (inSome.contains("hour") || inSome.contains("hr")) n * 3600 else n * 60
            exact = now.plusSeconds((if (inSome.contains("half an hour")) 1800.0 else secs).toLong())
        } else first(" in half an hour ", s)?.let { cut += it; exact = now.plusSeconds(1800) }

        // The clock
        var hour: Int? = null; var minute = 0; var meridiem: String? = null
        val clock = first(" at (\\d{1,2})([:.](\\d{2}))? ?(am|pm|a m|p m)? ", s) ?: first(" (\\d{1,2})([:.](\\d{2}))? ?(am|pm) ", s)
        if (clock != null) {
            cut += clock
            val digits = Regex("\\d+").findAll(clock).map { it.value }.toList()
            hour = digits.firstOrNull()?.toIntOrNull()
            if (digits.size > 1) digits[1].toIntOrNull()?.let { minute = it }
            meridiem = if (clock.contains("pm") || clock.contains("p m")) "pm" else if (clock.contains("am") || clock.contains("a m")) "am" else null
        } else first(" at noon | at midday | noon ", s)?.let { cut += it; hour = 12 }
            ?: first(" at midnight ", s)?.let { cut += it; hour = 0 }

        // Which day, for a one-off
        var dayOffset: Int? = null
        var onWeekday: Int? = null
        val tomorrow = first(" tomorrow ", s)
        val today = if (tomorrow == null) first(" (today|tonight) ", s) else null
        if (tomorrow != null) { cut += tomorrow; dayOffset = 1 }
        else if (today != null) { if (today !in cut) cut += today; dayOffset = 0 }
        else if (!repeats) first(" (on |next |this )?(sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)day ", s)?.let { m ->
            cut += m
            onWeekday = m.split(" ").mapNotNull { dayNumber(it) }.firstOrNull()
        }

        // Parts of the day: also say which half of the clock a bare "at 7" means.
        var part: String? = null
        for ((w, p) in listOf(" tonight " to "night", " this evening " to "evening", " in the evening " to "evening", " every evening " to "evening",
            " this morning " to "morning", " in the morning " to "morning", " every morning " to "morning",
            " this afternoon " to "afternoon", " in the afternoon " to "afternoon", " every afternoon " to "afternoon",
            " every night " to "night", " at night " to "night",
            " tomorrow morning " to "morning", " tomorrow afternoon " to "afternoon", " tomorrow evening " to "evening",
            " tomorrow night " to "night")) {
            if (s.contains(w)) { part = p; if (w !in cut) cut += w; break }
        }
        if (part == null) first(" (on |next |this )?(sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)day (morning|afternoon|evening|night) ", s)?.let { m ->
            part = m.trim().split(" ").last(); cut += m    // "Friday evening"
        }
        val clockHour = hour
        if (clockHour != null) {
            var h = clockHour
            if (meridiem == "pm" && h < 12) h += 12
            else if (meridiem == "am" && h == 12) h = 0
            else if (meridiem == null && h in 1..11) {
                if (part == "evening" || part == "night" || part == "afternoon") h += 12
                else if (part != "morning") {
                    // A bare "at 6": the next 6 o'clock that's still ahead — but nobody means 1–6 in the morning.
                    if (h <= 6) h += 12
                    else if (!repeats && exact == null && (dayOffset ?: 0) == 0 && onWeekday == null) {
                        val am = at(now, h, minute); val pm = at(now, h + 12, minute)
                        if (!am.isAfter(now) && pm.isAfter(now)) h += 12
                    }
                }
            }
            hour = minOf(23, h)
        } else part?.let { hour = mapOf("morning" to 8, "afternoon" to 15, "evening" to 19, "night" to 21)[it] }

        // What to be reminded of
        var what = said
        for (c in cut.sortedByDescending { it.length }) what = what.replace(c, " ", ignoreCase = true)
        for (lead in listOf(" please ", " can you ", " could you ", " hey tenzy ", " tenzy ")) what = what.replace(lead, " ", ignoreCase = true)
        what = what.replace(Regex(" +"), " ")
        for (intro in listOf("^ ?(set (a|me a) )?reminder (to|for|about|that) ", "^ ?(don'?t let me forget) (to )?", "^ ?remind me (to|about|that|of|i need to|i have to) ",
            "^ ?remind me ", " (and )?remind me (to|about|that|of) ", " (and )?remind me ")) {
            what = what.replace(Regex(intro, RegexOption.IGNORE_CASE), " ")
        }
        what = what.replace(Regex("^ ?(to|about|that) ", RegexOption.IGNORE_CASE), " ")
        what = what.replace(Regex(" (at|on|in|by)$", RegexOption.IGNORE_CASE), "")
        what = what.replace(Regex(" +"), " ").trim()
        if (what.isEmpty()) what = "Reminder"       // "remind me at 7": the time was the whole of it
        what = what.take(1).uppercase() + what.drop(1)

        // Put it together
        exact?.let { return Said(what, true, it, emptyList(), it.hour, it.minute) }
        val h = hour ?: 9
        if (repeats) return Said(what, false, null, days, h, minute)
        val wd = onWeekday
        val whenAt: ZonedDateTime = when {
            dayOffset != null -> {
                var w = at(now.plusDays(dayOffset.toLong()), h, minute)
                if (!w.isAfter(now)) w = w.plusDays(1)    // "today at 9" said at 10 means tomorrow — never a reminder in the past
                w
            }
            wd != null -> {
                var ahead = (wd - weekday(now) + 7) % 7
                if (ahead == 0 && !at(now, h, minute).isAfter(now)) ahead = 7
                at(now.plusDays(ahead.toLong()), h, minute)
            }
            else -> next(h, minute, now)
        }
        return Said(what, true, whenAt, emptyList(), h, minute)
    }

    /** The next time [hour]:[minute] comes round after [now]. */
    fun next(hour: Int, minute: Int, now: ZonedDateTime): ZonedDateTime {
        val today = at(now, hour, minute)
        return if (today.isAfter(now)) today else today.plusDays(1)
    }
}
