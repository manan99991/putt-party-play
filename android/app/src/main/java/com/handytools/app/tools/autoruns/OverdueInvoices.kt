package com.handytools.app.tools.autoruns

import com.handytools.app.I18n
import com.handytools.app.tools.invoice.InvoiceLogic
import java.text.DateFormat
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.Date
import java.util.Locale

/**
 * Nudge me about overdue invoices (the iPhone's autorun): every unpaid invoice past its pay-by day, how late it is, and
 * a reminder email ready — the invoice attached, the client's address filled in, the tone right for how late it is (a
 * friendly nudge up to a week, firm up to a month, then a final notice). The person reads it and sends it; Mark paid
 * clears it. Written as whole translated sentences, like the iPhone's. Pure, so it's unit-tested.
 */
object OverdueInvoices {
    enum class Tone { FRIENDLY, FIRM, FINAL }

    fun daysLate(d: InvoiceLogic.Doc, now: Long, zone: ZoneId = ZoneId.systemDefault()): Int {
        val due = d.due ?: return 0
        val a = Instant.ofEpochMilli(due).atZone(zone).toLocalDate(); val b = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        return maxOf(0, ChronoUnit.DAYS.between(a, b).toInt())
    }

    fun tone(daysLate: Int): Tone = if (daysLate <= 7) Tone.FRIENDLY else if (daysLate <= 30) Tone.FIRM else Tone.FINAL

    /** The client's email, if their details on the invoice have one. */
    fun email(to: String): String? = Regex("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", RegexOption.IGNORE_CASE).find(to)?.value

    /** Every unpaid invoice past its pay-by day, most overdue first. */
    fun overdue(docs: List<InvoiceLogic.Doc>, now: Long): List<InvoiceLogic.Doc> =
        docs.filter { it.overdue(now) }.sortedByDescending { daysLate(it, now) }

    fun amount(d: InvoiceLogic.Doc): String = "${d.currency}${"%,.2f".format(d.total)}"

    /** The reminder, in plain, polite words: subject and body. Number and amount exactly as on the invoice. */
    fun reminder(d: InvoiceLogic.Doc, now: Long, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): Pair<String, String> {
        val late = daysLate(d, now, zone)
        val amount = amount(d)
        val dueText = d.due?.let { DateFormat.getDateInstance(DateFormat.LONG, locale).apply { timeZone = java.util.TimeZone.getTimeZone(zone) }.format(Date(it)) } ?: ""
        val first = d.who.split(" ").firstOrNull().orEmpty()
        val hi = if (first.isEmpty()) I18n.t("Hello,") else I18n.fmt("Hi %@,", first)
        val sign = d.from.lineSequence().firstOrNull()?.trim().orEmpty()
        return when (tone(late)) {
            Tone.FRIENDLY -> I18n.fmt("Friendly reminder: invoice %@", d.number) to
                (hi + "\n\n" + I18n.fmt("Just a quick reminder that invoice %@ for %@ was due on %@. I've attached it again for convenience.", d.number, amount, dueText) +
                    "\n\n" + I18n.t("If it's already on its way, thank you — please ignore this.") + "\n\n" + sign).trim()
            Tone.FIRM -> I18n.fmt("Invoice %@ is %d days overdue", d.number, late) to
                (hi + "\n\n" + I18n.fmt("Invoice %@ for %@ was due on %@ and is now %d days overdue. Could you let me know when I can expect payment?", d.number, amount, dueText, late) +
                    "\n\n" + I18n.t("The invoice is attached.") + "\n\n" + sign).trim()
            Tone.FINAL -> I18n.fmt("Final notice: invoice %@", d.number) to
                (hi + "\n\n" + I18n.fmt("This is a final reminder that invoice %@ for %@, due on %@, is still unpaid after %d days. Please arrange payment this week, or reply to let me know if there's a problem.", d.number, amount, dueText, late) +
                    "\n\n" + I18n.t("The invoice is attached.") + "\n\n" + sign).trim()
        }
    }

    /** What the notification says. */
    fun notice(n: Int): String = if (n == 1) I18n.t("1 invoice is overdue — a reminder is ready to send.") else I18n.fmt("%d invoices are overdue — reminders are ready to send.", n)
}
