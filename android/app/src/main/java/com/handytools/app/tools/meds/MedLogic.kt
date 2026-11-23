package com.handytools.app.tools.meds

import java.util.Calendar
import java.util.UUID

/**
 * Medicine Reminders on Android — the iPhone's rules, ported (Manan, 23 Nov: "complete the android"). Each medicine
 * has a schedule (set times every day, set times on chosen weekdays, or every N hours within waking hours), an
 * optional end date and follow-up, and an optional pill count with a refill alert. Pure, so it's JVM-tested with the
 * same cases as the iPhone. A reminder tool, not medical advice: it never suggests a dose.
 */
data class TimeOfDay(val hour: Int, val minute: Int) : Comparable<TimeOfDay> {
    override fun compareTo(other: TimeOfDay) = compareValuesBy(this, other, { it.hour }, { it.minute })
    fun label(is24: Boolean): String =
        if (is24) "%02d:%02d".format(hour, minute)
        else "%d:%02d %s".format(if (hour % 12 == 0) 12 else hour % 12, minute, if (hour < 12) "AM" else "PM")
}

enum class Pattern(val key: String) { DAILY("daily"), WEEKDAYS("weekdays"), EVERY_HOURS("everyHours");
    companion object { fun of(k: String) = values().firstOrNull { it.key == k } ?: DAILY }
}

data class Med(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val dose: String = "",
    val note: String = "",
    val pattern: Pattern = Pattern.DAILY,
    val times: List<TimeOfDay> = listOf(TimeOfDay(8, 0)),
    val weekdays: Set<Int> = setOf(2, 3, 4, 5, 6),           // Calendar.DAY_OF_WEEK: 1 = Sunday … 7 = Saturday
    val everyHours: Int = 8,
    val firstHour: Int = 8,
    val lastHour: Int = 22,
    val start: Long = MedLogic.startOfDay(System.currentTimeMillis()),
    val end: Long? = null,
    val followUp: Long? = null,
    val followUpNote: String = "Refill or check in with your doctor",
    val paused: Boolean = false,
    val supply: Int? = null,
    val perDose: Int? = null,
    val refillAt: Int? = null,
)

data class DoseLog(val medId: String, val scheduled: Long, val taken: Long?)

object MedLogic {
    const val DAY = 86_400_000L

    fun startOfDay(t: Long): Long = Calendar.getInstance().apply {
        timeInMillis = t; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun at(day: Long, t: TimeOfDay): Long = Calendar.getInstance().apply {
        timeInMillis = startOfDay(day); set(Calendar.HOUR_OF_DAY, t.hour); set(Calendar.MINUTE, t.minute)
    }.timeInMillis

    private fun addDays(t: Long, n: Int): Long = Calendar.getInstance().apply { timeInMillis = t; add(Calendar.DAY_OF_YEAR, n) }.timeInMillis

    /** The clock times a medicine is due on any day it's due. */
    fun clockTimes(m: Med): List<TimeOfDay> = when (m.pattern) {
        Pattern.DAILY, Pattern.WEEKDAYS -> m.times.toSet().sorted()
        Pattern.EVERY_HOURS -> {
            val step = m.everyHours.coerceIn(1, 24)
            val last = if (m.lastHour >= m.firstHour) m.lastHour else m.firstHour
            (m.firstHour..last step step).map { TimeOfDay(it % 24, 0) }
        }
    }

    fun isDue(m: Med, day: Long): Boolean {
        if (m.paused) return false
        val d = startOfDay(day)
        if (d < startOfDay(m.start)) return false
        if (m.end != null && d > startOfDay(m.end)) return false
        if (m.pattern == Pattern.WEEKDAYS) return Calendar.getInstance().apply { timeInMillis = d }.get(Calendar.DAY_OF_WEEK) in m.weekdays
        return true
    }

    fun doses(m: Med, day: Long): List<Long> = if (!isDue(m, day)) emptyList() else clockTimes(m).map { at(day, it) }

    fun today(meds: List<Med>, now: Long): List<Pair<Med, Long>> =
        meds.flatMap { m -> doses(m, now).map { m to it } }.sortedBy { it.second }

    /** Every alert to arm from [now] for the next [days] days, soonest first, at most [cap] (Android keeps a few
     *  hundred alarms per app; Tenzy tops the list up every time an alert fires or the app opens). */
    fun upcoming(meds: List<Med>, now: Long, days: Int = 3, cap: Int = 60): List<Pair<Med, Long>> {
        val out = mutableListOf<Pair<Med, Long>>()
        for (offset in 0 until days) {
            val day = addDays(startOfDay(now), offset)
            meds.filter { it.name.isNotBlank() }.forEach { m -> doses(m, day).filter { it > now }.forEach { out += m to it } }
        }
        return out.sortedBy { it.second }.take(cap)
    }

    // ---- pill count ----

    fun dosesPerWeek(m: Med): Int = clockTimes(m).size * (if (m.pattern == Pattern.WEEKDAYS) m.weekdays.size else 7)

    fun daysLeft(m: Med): Int? {
        val left = m.supply ?: return null
        val perDay = dosesPerWeek(m) * maxOf(1, m.perDose ?: 1) / 7.0
        return if (perDay > 0) Math.floor(left / perDay).toInt() else null
    }

    fun counted(m: Med, taken: Boolean): Med {
        val left = m.supply ?: return m
        val n = maxOf(1, m.perDose ?: 1)
        return m.copy(supply = maxOf(0, if (taken) left - n else left + n))
    }

    /** True only on the dose that takes the count down to the refill point, so the alert comes once. */
    fun crossedRefill(old: Med, new: Med): Boolean {
        val a = old.supply ?: return false
        val b = new.supply ?: return false
        val at = old.refillAt ?: 7
        return a > at && b <= at
    }

    fun refillMessage(m: Med): Pair<String, String> {
        val left = m.supply ?: 0
        val days = daysLeft(m)?.let { if (it <= 0) " That's less than a day." else " That's about $it day${if (it == 1) "" else "s"}." } ?: ""
        return "Time to refill ${m.name}" to "$left left.$days Order more or ask your pharmacy, then update the count in Tenzy."
    }

    // ---- plain words ----

    private val dayNames = mapOf(1 to "Sun", 2 to "Mon", 3 to "Tue", 4 to "Wed", 5 to "Thu", 6 to "Fri", 7 to "Sat")

    fun summary(m: Med, is24: Boolean = false): String {
        val times = clockTimes(m).map { it.label(is24) }
        val timeText = if (times.size <= 4) times.joinToString(", ") else "${times.size} times a day"
        var s = when (m.pattern) {
            Pattern.DAILY -> "Every day at $timeText"
            Pattern.EVERY_HOURS -> "Every ${m.everyHours} h, $timeText"
            Pattern.WEEKDAYS -> listOf(2, 3, 4, 5, 6, 7, 1).filter { it in m.weekdays }.joinToString(", ") { dayNames.getValue(it) } + " at $timeText"
        }
        m.supply?.let { left -> s += " · $left left" + (daysLeft(m)?.let { " (about $it d)" } ?: "") }
        return s
    }

    // ---- caregiver ----

    /** Doses whose follow-up nudge is still ahead and not taken, today and tomorrow, soonest first (max 6). */
    fun followUps(meds: List<Med>, taken: (Med, Long) -> Boolean, minutes: Int, now: Long): List<Triple<Med, Long, Long>> {
        if (minutes <= 0) return emptyList()
        return (today(meds, now) + today(meds, addDays(now, 1)))
            .map { (m, at) -> Triple(m, at, at + minutes * 60_000L) }
            .filter { it.third > now && !taken(it.first, it.second) }
            .sortedBy { it.third }.take(6)
    }

    fun weekSummary(taken: Int, due: Int, missed: List<String>): String {
        if (due == 0) return "Reminders are set up — nothing was due yet this week."
        val pct = Math.round(taken * 100.0 / due).toInt()
        var s = "This week: $taken of $due doses taken ($pct%)."
        if (missed.isNotEmpty()) s += " Missed: " + missed.take(4).joinToString(", ") + if (missed.size > 4) " and ${missed.size - 4} more." else "."
        return s
    }

    /** The text a caregiver gets: how the week went, today's doses, and the medicines with their times. */
    fun update(name: String, meds: List<Med>, taken: Int, due: Int, missed: List<String>, today: List<Triple<String, String, Boolean>>): String {
        val first = name.trim().split(" ").firstOrNull().orEmpty()
        val lines = mutableListOf(if (first.isEmpty()) "My medicines — an update from Tenzy:" else "Hi $first — my medicines, from Tenzy:")
        lines += weekSummary(taken, due, missed)
        if (today.isNotEmpty()) lines += "Today: " + today.joinToString(", ") { "${it.first} ${it.second} ${if (it.third) "✓ taken" else "not yet"}" } + "."
        val active = meds.filter { !it.paused }
        if (active.isNotEmpty()) lines += "My medicines:\n" + active.joinToString("\n") { "• ${it.name} — ${summary(it)}" }
        return lines.joinToString("\n")
    }
}
