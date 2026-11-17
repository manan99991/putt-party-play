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

    private val callCues = setOf(
        "call", "phone", "ring", "dial", "text", "callback",
        // Spanish
        "llamar", "llama", "telefonear", "teléfono", "telefono", "marcar", "mensaje", "mensajear",
        "textear", "contactar",
    )

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
            """|(\b(in|by|within|next)\s+\d*\s*(day|week|month|hour)s?\b)""" +
            // Spanish
            """|(\b(hoy|mañana|manana)\b)""" +
            """|(\besta\s+(noche|tarde|mañana|manana)\b)""" +
            """|(\bpasado\s+(mañana|manana)\b)""" +
            """|(\b(lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)\b)""" +
            """|(\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b)""" +
            """|(\ba\s+las?\s+\d{1,2}(:\d{2})?\b)""" +
            """|(\b\d{1,2}\s+de\s+la\s+(tarde|noche|mañana|manana)\b)""" +
            """|(\ben\s+\d+\s+(día|dia|semana)s?\b)""" +
            """|(\b(la\s+)?próxima\s+semana\b)""" +
            """|(\bsemana\s+que\s+viene\b)""",
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

    /** An `sms:` URL to open the messaging app addressed to a number (the person types the message), or null. */
    fun smsURL(phone: String): String? {
        val keep = phone.filter { it.isDigit() || it == '+' }
        return if (keep.count { it.isDigit() } >= 7) "sms:$keep" else null
    }

    private val EMAIL = Regex("""[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}""")

    /** The first email address in a task, or null. */
    fun emailIn(task: String): String? = EMAIL.find(task)?.value

    /** A `mailto:` URL to open the mail composer addressed to an email, or null for a blank address. */
    fun mailtoURL(email: String): String? = if (email.contains("@")) "mailto:$email" else null

    /** A `geo:` Maps URL for a place (opens Maps), or null for a blank place. */
    fun mapsURL(place: String): String? =
        if (place.isBlank()) null else "geo:0,0?q=" + java.net.URLEncoder.encode(place, "UTF-8")

    /** One .ics holding every dated task as its own event, so "Add to Calendar" adds the whole plan at
     * once. Same event format as the rest of the app. Pure and testable (parity with the iOS twin). */
    fun icsCalendar(events: List<Triple<String, Long, String>>): String {
        val f = java.text.SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", java.util.Locale.US)
            .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
        return buildString {
            append("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Tenzy//Thinking//EN\r\n")
            for ((title, dueMs, place) in events) {
                append("BEGIN:VEVENT\r\nUID:").append(dueMs).append("@tenzy\r\n")
                append("DTSTAMP:").append(f.format(java.util.Date())).append("\r\n")
                append("DTSTART:").append(f.format(java.util.Date(dueMs))).append("\r\n")
                append("DTEND:").append(f.format(java.util.Date(dueMs + 3_600_000L))).append("\r\n")
                append("SUMMARY:").append(title).append("\r\n")
                if (place.isNotBlank()) append("LOCATION:").append(place).append("\r\n")
                append("END:VEVENT\r\n")
            }
            append("END:VCALENDAR\r\n")
        }
    }

    /** A one-event .ics calendar payload for a dated task — same format as the rest of the app. */
    fun icsEvent(title: String, dueMs: Long, place: String = ""): String {
        val f = java.text.SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", java.util.Locale.US)
            .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
        return buildString {
            append("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Tenzy//EN\r\nBEGIN:VEVENT\r\n")
            append("UID:").append(dueMs).append("@tenzy\r\n")
            append("DTSTAMP:").append(f.format(java.util.Date())).append("\r\n")
            append("DTSTART:").append(f.format(java.util.Date(dueMs))).append("\r\n")
            append("DTEND:").append(f.format(java.util.Date(dueMs + 3_600_000L))).append("\r\n")
            append("SUMMARY:").append(title).append("\r\n")
            if (place.isNotBlank()) append("LOCATION:").append(place).append("\r\n")
            append("END:VEVENT\r\nEND:VCALENDAR\r\n")
        }
    }

    // Weekday words → Calendar.DAY_OF_WEEK numbers (Sunday = 1 … Saturday = 7), matching the iOS twin.
    private val weekdays = mapOf(
        "sunday" to 1, "sun" to 1, "monday" to 2, "mon" to 2, "tuesday" to 3, "tues" to 3, "tue" to 3,
        "wednesday" to 4, "weds" to 4, "wed" to 4, "thursday" to 5, "thurs" to 5, "thur" to 5, "thu" to 5,
        "friday" to 6, "fri" to 6, "saturday" to 7, "sat" to 7,
        // Spanish
        "domingo" to 1, "lunes" to 2, "martes" to 3, "miércoles" to 4, "miercoles" to 4, "jueves" to 5,
        "viernes" to 6, "sábado" to 7, "sabado" to 7,
    )

    /** Turn a task into the concrete moment it is due (epoch millis), or null when it carries no date.
     * Deterministic given [nowMs] and [zone] (the tests pin both). Same rules as the iOS twin: a clock time,
     * a day anchor (today/tonight/tomorrow, a weekday → next occurrence, "in N days/weeks", "next week"),
     * a day with no time defaults to 9am (tonight → 8pm), and a time today already past rolls to tomorrow. */
    fun dueDateMs(task: String, nowMs: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Long? {
        val t = task.lowercase()
        fun has(p: String) = Regex(p).containsMatchIn(t)
        var hour: Int? = null; var minute = 0
        val ap = Regex("""\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b""").find(t)
        val alas = Regex("""\ba\s+las?\s+(\d{1,2})(?::(\d{2}))?""").find(t)
        val deLa = Regex("""\b(\d{1,2})(?::(\d{2}))?\s+de\s+la\s+(tarde|noche|mañana|manana)""").find(t)
        if (ap != null) {
            hour = (ap.groupValues[1].toInt() % 12) + (if (ap.groupValues[3] == "pm") 12 else 0)
            minute = ap.groupValues[2].toIntOrNull() ?: 0
        } else if (alas != null) {
            val h = alas.groupValues[1].toInt(); minute = alas.groupValues[2].toIntOrNull() ?: 0
            hour = when {
                has("""(?:de|por)\s+la\s+(?:tarde|noche)""") && h < 12 -> h + 12
                has("""(?:de|por)\s+la\s+ma(?:ñ|n)ana""") && h == 12 -> 0
                else -> h
            }
        } else if (deLa != null) {
            val h = deLa.groupValues[1].toInt(); minute = deLa.groupValues[2].toIntOrNull() ?: 0
            val marker = deLa.groupValues[3]
            hour = when {
                (marker == "tarde" || marker == "noche") && h < 12 -> h + 12
                (marker == "mañana" || marker == "manana") && h == 12 -> 0
                else -> h
            }
        } else {
            Regex("""\b(\d{1,2}):(\d{2})\b""").find(t)?.let { hour = it.groupValues[1].toInt(); minute = it.groupValues[2].toIntOrNull() ?: 0 }
        }
        var off: Int? = null; var tonight = false; var estaTarde = false
        when {
            has("""\btonight\b""") || has("""\besta\s+noche\b""") -> { off = 0; tonight = true }
            has("""\btoday\b""") || has("""\bhoy\b""") -> off = 0
            has("""\besta\s+tarde\b""") -> { off = 0; estaTarde = true }
            has("""\besta\s+ma(?:ñ|n)ana\b""") -> off = 0
            has("""\bpasado\s+ma(?:ñ|n)ana\b""") -> off = 2
            has("""\b(tomorrow|tmrw|tmr)\b""") -> off = 1
            has("""(?<!de la )(?<!por la )(?<!esta )\bma(?:ñ|n)ana\b""") -> off = 1
            else -> {
                val inN = Regex("""\b(?:in|en)\s+(\d+)\s+(day|día|dia|week|semana)s?\b""").find(t)
                when {
                    inN != null -> off = inN.groupValues[1].toInt() * (if (inN.groupValues[2].startsWith("week") || inN.groupValues[2].startsWith("seman")) 7 else 1)
                    has("""\bnext week\b""") || has("""\b(?:la\s+)?próxima\s+semana\b""") || has("""\bsemana que viene\b""") -> off = 7
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
            set(java.util.Calendar.HOUR_OF_DAY, hour ?: if (tonight) 20 else if (estaTarde) 15 else 9)
            set(java.util.Calendar.MINUTE, if (hour == null) 0 else minute)
            set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
        }
        if (o == 0 && hour != null && cal.timeInMillis < nowMs && !has("""\btoday\b|\btonight\b|\bhoy\b|\besta\s+noche\b""")) {
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
