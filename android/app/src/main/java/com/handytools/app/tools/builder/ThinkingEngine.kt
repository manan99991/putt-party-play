package com.handytools.app.tools.builder

/**
 * The structuring thinking tools that need no language model, so they deliver the same on every phone
 * (Android has no on-device LLM): Clear My Head and My Day. Both turn a brain-dump into clean, deduped
 * tasks, each already routed to its apps (via [ThinkingActions]) and given a concrete due time where it
 * has one. Pure and deterministic; the iOS twin (`ThinkingEngine.swift`) uses the same rules. The
 * language-model tools (Untangle, Crossroads, Plain, Reword, Prep) sit behind a separate engine.
 */
object ThinkingEngine {
    /** One task pulled from a dump: its words, the apps it flows into, and when it's due (if ever). */
    data class Task(val text: String, val actions: ThinkingActions.Plan, val due: Long?)

    /** Split a brain-dump into candidate task lines — by line first, then by comma/semicolon within a line.
     * Trimmed, blanks dropped. */
    fun split(dump: String): List<String> =
        dump.split('\n', '\r')
            .flatMap { it.split(',', ';') }
            .map { it.trim() }
            .filter { it.isNotEmpty() }

    /** Dump → unique enriched tasks (case-insensitive dedupe, first kept), in the order dumped. */
    fun tasks(dump: String, nowMs: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): List<Task> {
        val seen = HashSet<String>()
        val out = ArrayList<Task>()
        for (line in split(dump)) {
            if (!seen.add(line.lowercase())) continue
            out.add(Task(line, ThinkingActions.plan(line), ThinkingActions.dueDateMs(line, nowMs, zone)))
        }
        return out
    }

    /** Clear My Head: the tasks, deduped, in the order they came out. */
    fun clearMyHead(dump: String, nowMs: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): List<Task> =
        tasks(dump, nowMs, zone)

    /** My Day: the same tasks laid out by time — the ones with a due time in order, then the rest. */
    fun myDay(dump: String, nowMs: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): List<Task> {
        val all = tasks(dump, nowMs, zone)
        val timed = all.filter { it.due != null }.sortedBy { it.due!! }
        return timed + all.filter { it.due == null }
    }
}
