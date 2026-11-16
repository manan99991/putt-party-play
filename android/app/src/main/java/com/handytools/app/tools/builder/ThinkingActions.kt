package com.handytools.app.tools.builder

/**
 * The spine of the thinking tools' "Act on it" layer: given a single task line, work out which of the
 * phone's apps it belongs to — Reminders, Calendar, Maps, a phone call — and pull out the bits each needs
 * (the place, the number). Pure and deterministic so it is unit-tested off-device; the iOS twin
 * (`ThinkingActions.swift`) uses the SAME rules, so both platforms agree on every task.
 *
 * Deliberately self-contained (its own date/place/phone detection, not each platform's different parser)
 * so the two platforms never disagree, and conservative + additive: a task only picks up Calendar when it
 * has a date, Maps when it names a real place, Call when it has a number or a call cue. It never
 * dead-ends — every task is at least a reminder.
 */
object ThinkingActions {
    /** A built-in app a task can flow into. */
    enum class Kind { CALENDAR, REMINDER, MAPS, CALL }

    data class Plan(
        val kinds: List<Kind>,   // apps this task flows into, in UI order; always contains REMINDER
        val isDated: Boolean,    // task carries a date/deadline → flag it (Calendar + dated reminder)
        val place: String?,      // a confident place, for a Maps hand-off; null when there is none
        val phone: String?,      // a phone number, for a one-tap call; null when there is none
        val isCall: Boolean,     // reads like a call/text even without a number ("call the dentist")
    )

    private val callCues = setOf("call", "phone", "ring", "dial", "text", "callback")

    private val placeWords = setOf(
        "street", "st", "ave", "avenue", "road", "rd", "blvd", "boulevard", "lane", "ln", "drive", "dr",
        "court", "ct", "way", "place", "plaza", "square", "clinic", "hospital", "center", "centre", "mall",
        "park", "station", "airport", "hotel", "motel", "cafe", "restaurant", "store", "shop", "market",
        "gym", "school", "college", "university", "library", "church", "temple", "office", "bank",
        "pharmacy", "dmv", "salon", "studio", "arena", "stadium", "theater", "theatre", "museum", "gallery",
    )
    private val knownPlaces = listOf(
        "costco", "target", "walmart", "aldi", "kroger", "safeway", "cvs", "walgreens", "ikea",
        "starbucks", "jewel", "jewel-osco", "trader joe's", "whole foods", "home depot", "lowe's", "lowes",
        "best buy", "sam's club", "the gym", "the office", "the airport", "the bank", "the pharmacy",
        "the dmv", "the post office", "the library", "the park",
    )

    private val DATE_CUE = Regex(
        """(\b\d{1,2}(:\d{2})?\s?(am|pm)\b)""" +
            """|(\b\d{1,2}:\d{2}\b)""" +
            """|(\b(mon|tues?|wed(nes)?|thur?s?|fri|sat(ur)?|sun)(day)?\b)""" +
            """|(\b(today|tonight|tomorrow|tmrw|tmr)\b)""" +
            """|(\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\b)""" +
            """|(\b\d{1,2}/\d{1,2}\b)""" +
            """|(\b(in|by|within|next)\s+\d*\s*(day|week|month|hour)s?\b)""",
        RegexOption.IGNORE_CASE,
    )
    private val LOCATIVE = Regex("""\b(?:at|to|from|in)\s+(?:the\s+)?([A-Z][\p{L}'&.\-]*(?:\s+[A-Z][\p{L}'&.\-]*){0,3})""")
    private val PHONE = Regex("""(?<!\d)(?:\+?\d{1,3}[\s.\-]?)?(?:\(\d{3}\)|\d{3})[\s.\-]?\d{3}[\s.\-]?\d{4}(?!\d)""")

    /** Same date/deadline cue as the iOS twin. */
    fun hasDateCue(s: String): Boolean = DATE_CUE.containsMatchIn(s)

    /** A confident place in a task, or null — a capitalised phrase after a locative word that names a place
     * type, else a known everyday place. */
    fun placeIn(task: String): String? {
        val m = LOCATIVE.find(task)?.groupValues?.get(1)
        if (m != null) {
            val tokens = m.lowercase().split(Regex("[^a-z]+")).filter { it.isNotEmpty() }.toSet()
            if (tokens.any { it in placeWords }) return m.trim()
        }
        val low = task.lowercase()
        for (k in knownPlaces) {
            if (Regex("""\b""" + Regex.escape(k) + """\b""").containsMatchIn(low)) {
                return k.split(" ").joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
            }
        }
        return null
    }

    /** The first phone number in a task (10 digits, optional country code), or null. */
    fun phoneIn(task: String): String? = PHONE.find(task)?.value?.trim()

    /** A `tel:` URL for a one-tap dial, or null — digits (and a leading +) only. */
    fun telURL(phone: String): String? {
        val keep = phone.filter { it.isDigit() || it == '+' }
        return if (keep.count { it.isDigit() } >= 7) "tel:$keep" else null
    }

    // Weekday words → Calendar.DAY_OF_WEEK numbers (Sunday = 1 … Saturday = 7), matching the iOS twin.
    private val weekdays = mapOf(
        "sunday" to 1, "sun" to 1, "monday" to 2, "mon" to 2, "tuesday" to 3, "tues" to 3, "tue" to 3,
        "wednesday" to 4, "weds" to 4, "wed" to 4, "thursday" to 5, "thurs" to 5, "thur" to 5, "thu" to 5,
        "friday" to 6, "fri" to 6, "saturday" to 7, "sat" to 7,
    )

    /** Turn a task into the concrete moment it is due (epoch millis), or null when it carries no date.
     * Deterministic given [nowMs] and [zone] (the tests pin both). Same rules as the iOS twin: a clock time,
     * a day anchor (today/tonight/tomorrow, a weekday → next occurrence, "in N days/weeks", "next week"),
     * a day with no time defaults to 9am (tonight → 8pm), and a time today already past rolls to tomorrow. */
    fun dueDateMs(task: String, nowMs: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Long? {
        val t = task.lowercase()
        var hour: Int? = null; var minute = 0
        val ap = Regex("""\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b""").find(t)
        if (ap != null) {
            hour = (ap.groupValues[1].toInt() % 12) + (if (ap.groupValues[3] == "pm") 12 else 0)
            minute = ap.groupValues[2].toIntOrNull() ?: 0
        } else {
            Regex("""\b(\d{1,2}):(\d{2})\b""").find(t)?.let { hour = it.groupValues[1].toInt(); minute = it.groupValues[2].toIntOrNull() ?: 0 }
        }
        fun has(p: String) = Regex(p).containsMatchIn(t)
        var off: Int? = null; var tonight = false
        when {
            has("""\btonight\b""") -> { off = 0; tonight = true }
            has("""\btoday\b""") -> off = 0
            has("""\b(tomorrow|tmrw|tmr)\b""") -> off = 1
            else -> {
                val inN = Regex("""\bin\s+(\d+)\s+(day|week)s?\b""").find(t)
                when {
                    inN != null -> off = inN.groupValues[1].toInt() * (if (inN.groupValues[2] == "week") 7 else 1)
                    has("""\bnext week\b""") -> off = 7
                    else -> weekdays.entries.firstOrNull { has("""\b""" + it.key + """\b""") }?.let { e ->
                        val cur = java.util.Calendar.getInstance(zone).apply { timeInMillis = nowMs }.get(java.util.Calendar.DAY_OF_WEEK)
                        val d = ((e.value - cur) % 7 + 7) % 7
                        off = if (d == 0) 7 else d
                    }
                }
            }
        }
        val o = off ?: (if (hour != null) 0 else return null)
        val cal = java.util.Calendar.getInstance(zone).apply {
            timeInMillis = nowMs
            add(java.util.Calendar.DAY_OF_MONTH, o)
            set(java.util.Calendar.HOUR_OF_DAY, hour ?: if (tonight) 20 else 9)
            set(java.util.Calendar.MINUTE, if (hour == null) 0 else minute)
            set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
        }
        if (o == 0 && hour != null && cal.timeInMillis < nowMs && !has("""\btoday\b|\btonight\b""")) {
            cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
        }
        return cal.timeInMillis
    }

    /** Read one task line into the apps it belongs to. Order: Calendar (if dated), Reminder (always),
     * Maps (if a place), Call (if a number or a call cue) — deduped, so each app appears once. */
    fun plan(task: String): Plan {
        val trimmed = task.trim()
        val isDated = hasDateCue(trimmed)
        val place = placeIn(trimmed)
        val phone = phoneIn(trimmed)
        val words = trimmed.lowercase().split(Regex("[^a-z]+")).filter { it.isNotEmpty() }.toSet()
        val isCall = phone != null || words.any { it in callCues }

        val kinds = ArrayList<Kind>()
        if (isDated) kinds.add(Kind.CALENDAR)
        kinds.add(Kind.REMINDER)                 // never a dead end — a task is always at least a reminder
        if (place != null) kinds.add(Kind.MAPS)
        if (isCall) kinds.add(Kind.CALL)
        return Plan(kinds.distinct(), isDated, place, phone, isCall)
    }
}
