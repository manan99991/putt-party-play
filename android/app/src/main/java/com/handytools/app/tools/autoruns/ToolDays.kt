package com.handytools.app.tools.autoruns

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.ZoneId

/**
 * Which days each tool was opened over the last month — the habit an autorun offer is built on (the iPhone's ToolDays).
 * Only tool ids and day numbers; nothing about what was in them. Days are counted at the person's own midnight.
 */
object ToolDays {
    private const val PREFS = "tooldays"
    private const val KEY = "log.v1"
    const val KEEP_DAYS = 30

    /** The day number (days since 1 Jan 1970) of [millis] in [zone]. */
    fun day(millis: Long, zone: ZoneId = ZoneId.systemDefault()): Int =
        java.time.Instant.ofEpochMilli(millis).atZone(zone).toLocalDate().toEpochDay().toInt()

    /** Pure: the log with [today] added for [tool], and anything older than a month gone. */
    fun noted(log: Map<String, List<Int>>, tool: String, today: Int): Map<String, List<Int>> {
        val out = log.mapValues { (_, d) -> d.filter { it > today - KEEP_DAYS } }.filterValues { it.isNotEmpty() }.toMutableMap()
        val days = out[tool].orEmpty()
        if (today !in days) out[tool] = days + today
        return out
    }

    private fun load(ctx: Context): Map<String, List<Int>> = runCatching {
        val o = JSONObject(ctx.getSharedPreferences(PREFS, 0).getString(KEY, "{}") ?: "{}")
        o.keys().asSequence().associateWith { k -> o.getJSONArray(k).let { a -> (0 until a.length()).map { a.getInt(it) } } }
    }.getOrDefault(emptyMap())

    /** Records that a tool was opened today. Cheap: writes only once a day per tool. */
    fun note(ctx: Context, tool: String, now: Long = System.currentTimeMillis()) {
        if (tool.isBlank()) return
        val log = load(ctx); val today = day(now)
        if (today in log[tool].orEmpty()) return
        val o = JSONObject(); noted(log, tool, today).forEach { (k, v) -> o.put(k, JSONArray(v)) }
        ctx.getSharedPreferences(PREFS, 0).edit().putString(KEY, o.toString()).apply()
    }

    /** Every tool's days of use in the last month. */
    fun all(ctx: Context, now: Long = System.currentTimeMillis()): Map<String, Set<Int>> {
        val today = day(now)
        return load(ctx).mapValues { (_, d) -> d.filter { it > today - KEEP_DAYS }.toSet() }.filterValues { it.isNotEmpty() }
    }
}
