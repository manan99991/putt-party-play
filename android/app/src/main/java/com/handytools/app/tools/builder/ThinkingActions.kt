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
