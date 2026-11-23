package com.handytools.app.tools.invoice

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.UUID
import kotlin.math.roundToLong

/**
 * Invoices & Quotes, the same rules as the iPhone (Business tab, 23 Nov): totals to the cent, numbers that count up
 * per kind (INV-0001, Q-0001), 3 a month free (counted when made, so deleting one doesn't hand it back), unpaid
 * invoices kept until marked paid, and "overdue" once the pay-by day has passed. Pure, so it's JVM-tested.
 */
object InvoiceLogic {
    enum class Kind { INVOICE, QUOTE }
    data class Line(val what: String, val qty: Double, val price: Double) { val amount get() = round2(qty * price) }
    data class Doc(
        val id: String = UUID.randomUUID().toString(), val kind: Kind, val number: String, val date: Long, val due: Long?,
        val from: String, val to: String, val lines: List<Line>, val taxPercent: Double, val notes: String,
        val currency: String, val paid: Boolean = false,
    ) {
        val subtotal get() = round2(lines.sumOf { it.amount })
        val tax get() = round2(subtotal * taxPercent / 100)
        val total get() = round2(subtotal + tax)
        val who get() = to.lineSequence().firstOrNull()?.trim().orEmpty()
        fun overdue(now: Long): Boolean = kind == Kind.INVOICE && !paid && due != null && startOfDay(due) < startOfDay(now)
    }

    const val FREE_PER_MONTH = 3

    fun round2(v: Double): Double = (v * 100).roundToLong() / 100.0

    fun nextNumber(kind: Kind, after: List<Doc>): String {
        val prefix = if (kind == Kind.INVOICE) "INV-" else "Q-"
        val used = after.filter { it.kind == kind }.mapNotNull { it.number.takeLastWhile(Char::isDigit).toIntOrNull() }
        return prefix + "%04d".format((used.maxOrNull() ?: 0) + 1)
    }

    fun left(made: Int, premium: Boolean): Int? = if (premium) null else (FREE_PER_MONTH - made).coerceAtLeast(0)

    fun sameMonth(a: Long, b: Long): Boolean {
        val x = Calendar.getInstance().apply { timeInMillis = a }; val y = Calendar.getInstance().apply { timeInMillis = b }
        return x.get(Calendar.YEAR) == y.get(Calendar.YEAR) && x.get(Calendar.MONTH) == y.get(Calendar.MONTH)
    }

    fun startOfDay(t: Long): Long = Calendar.getInstance().apply {
        timeInMillis = t; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    /** Unpaid invoices, soonest due first (quotes are never waiting to be paid). */
    fun unpaid(docs: List<Doc>): List<Doc> = docs.filter { it.kind == Kind.INVOICE && !it.paid }.sortedBy { it.due ?: Long.MAX_VALUE }

    /** "2 or 2.5": no trailing .0. */
    fun qty(v: Double): String = if (v == Math.floor(v)) v.toLong().toString() else v.toString()

    /** Reads "1,250.50" or "1250,50" the way people type them. */
    fun number(s: String): Double {
        val t = s.filter { it.isDigit() || it == '.' || it == ',' }
        return if (t.contains('.')) t.replace(",", "").toDoubleOrNull() ?: 0.0 else t.replace(',', '.').toDoubleOrNull() ?: 0.0
    }
}

/** The invoices and quotes made on this phone, kept in the app's private files. Nothing leaves the phone. */
object InvoiceStore {
    private const val PREFS = "invoice"
    private fun file(ctx: Context) = File(ctx.filesDir, "invoices.json")

    fun load(ctx: Context): List<InvoiceLogic.Doc> = runCatching {
        val a = JSONArray(file(ctx).readText())
        (0 until a.length()).map { i ->
            val o = a.getJSONObject(i)
            val ls = o.getJSONArray("lines")
            InvoiceLogic.Doc(
                id = o.getString("id"), kind = InvoiceLogic.Kind.valueOf(o.getString("kind")), number = o.getString("number"),
                date = o.getLong("date"), due = if (o.has("due")) o.getLong("due") else null,
                from = o.optString("from"), to = o.optString("to"),
                lines = (0 until ls.length()).map { j -> ls.getJSONObject(j).let { InvoiceLogic.Line(it.getString("what"), it.getDouble("qty"), it.getDouble("price")) } },
                taxPercent = o.optDouble("tax", 0.0), notes = o.optString("notes"), currency = o.optString("currency", "$"), paid = o.optBoolean("paid"),
            )
        }
    }.getOrDefault(emptyList())

    private fun save(ctx: Context, docs: List<InvoiceLogic.Doc>) {
        val a = JSONArray()
        docs.forEach { d ->
            a.put(JSONObject().apply {
                put("id", d.id); put("kind", d.kind.name); put("number", d.number); put("date", d.date)
                d.due?.let { put("due", it) }
                put("from", d.from); put("to", d.to); put("tax", d.taxPercent); put("notes", d.notes); put("currency", d.currency); put("paid", d.paid)
                put("lines", JSONArray().apply { d.lines.forEach { l -> put(JSONObject().put("what", l.what).put("qty", l.qty).put("price", l.price)) } })
            })
        }
        file(ctx).writeText(a.toString())
    }

    fun add(ctx: Context, d: InvoiceLogic.Doc) {
        save(ctx, listOf(d) + load(ctx))
        val key = monthKey(d.date)
        val p = ctx.getSharedPreferences(PREFS, 0)
        p.edit().putInt(key, p.getInt(key, 0) + 1).apply()
    }
    fun setPaid(ctx: Context, id: String, paid: Boolean) = save(ctx, load(ctx).map { if (it.id == id) it.copy(paid = paid) else it })
    fun remove(ctx: Context, id: String) = save(ctx, load(ctx).filterNot { it.id == id })

    /** Made this month — counted when made. */
    fun madeThisMonth(ctx: Context, now: Long = System.currentTimeMillis()): Int =
        maxOf(ctx.getSharedPreferences(PREFS, 0).getInt(monthKey(now), 0), load(ctx).count { InvoiceLogic.sameMonth(it.date, now) })

    private fun monthKey(t: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = t }
        return "made.${c.get(Calendar.YEAR)}-${c.get(Calendar.MONTH) + 1}"
    }

    /** Your details, typed once. */
    fun from(ctx: Context): String = ctx.getSharedPreferences(PREFS, 0).getString("from", "") ?: ""
    fun setFrom(ctx: Context, v: String) = ctx.getSharedPreferences(PREFS, 0).edit().putString("from", v).apply()
}
