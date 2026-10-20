package com.handytools.app.tools.sorted

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern

/** Pulls the key date and amount out of a scanned everyday document, and makes a plain summary.
 *  Pure on-device text work — no model needed, so it runs on every phone. */
object SortedEngine {

    fun parse(text: String): Parsed {
        val due = keyDate(text)
        val amount = amount(text)
        val summary = when {
            due != null && amount != null -> "Looks like something to pay by the date below — check the amount and the deadline."
            due != null -> "There's a date on this — add it to your calendar below."
            else -> "Pulled the key details from the scan."
        }
        return Parsed(guessKind(text), titleGuess(text), amount, due, summary)
    }

    private val amountRe = Pattern.compile("[\\$£€]\\s?\\d[\\d,]*(?:\\.\\d{2})?")
    fun amount(text: String): String? {
        val m = amountRe.matcher(text)
        var best: String? = null
        var bestVal = -1.0
        while (m.find()) {
            val s = m.group()
            val v = s.filter { it.isDigit() || it == '.' }.toDoubleOrNull() ?: 0.0
            if (v > bestVal) { bestVal = v; best = s }
        }
        return best
    }

    private val datePatterns = listOf(
        "MMMM d, yyyy", "MMM d, yyyy", "d MMMM yyyy", "d MMM yyyy",
        "MM/dd/yyyy", "dd/MM/yyyy", "M/d/yyyy", "yyyy-MM-dd", "dd-MM-yyyy"
    )
    private val dateFinder = Pattern.compile(
        "(\\d{4}-\\d{1,2}-\\d{1,2})" +
            "|(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})" +
            "|([A-Za-z]{3,9}\\s+\\d{1,2},?\\s+\\d{4})" +
            "|(\\d{1,2}\\s+[A-Za-z]{3,9}\\s+\\d{4})"
    )

    /** Soonest future date found, else the latest date found. */
    fun keyDate(text: String): Date? {
        val found = mutableListOf<Date>()
        val m = dateFinder.matcher(text)
        while (m.find()) {
            val cand = m.group().trim()
            for (p in datePatterns) {
                val fmt = SimpleDateFormat(p, Locale.US).apply { isLenient = false }
                val d = runCatching { fmt.parse(cand) }.getOrNull()
                if (d != null) { found.add(d); break }
            }
        }
        if (found.isEmpty()) return null
        val now = Date()
        return found.filter { it.after(now) }.sorted().firstOrNull() ?: found.maxOrNull()
    }

    fun guessKind(text: String): String {
        val t = text.lowercase()
        return when {
            listOf("appointment", "appt", "visit", "booking").any { t.contains(it) } -> "Appointment"
            listOf("invoice", "amount due", "balance due", "payment due", "bill").any { t.contains(it) } -> "Bill"
            listOf("receipt", "subtotal", "total").any { t.contains(it) } -> "Receipt"
            listOf("renew", "expires", "notice").any { t.contains(it) } -> "Notice"
            listOf("form", "application", "sign").any { t.contains(it) } -> "Form"
            else -> "Document"
        }
    }

    fun titleGuess(text: String): String =
        text.split("\n").map { it.trim() }.firstOrNull { it.length > 2 } ?: "Scanned document"
}
