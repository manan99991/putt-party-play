package com.handytools.app.tools.autoruns

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Back up my contacts every week (the iPhone's autorun): a copy of every contact, kept on the phone in Tenzy's own
 * files (the last eight), and a word when anyone has disappeared since the last copy — one tap hands that contact back
 * to the phone's Contacts app, exactly as it was. The copy can be emailed to yourself to keep it off the phone too.
 */
object ContactsBackup {
    /** One contact in a copy: its whole vCard, and the name and numbers it's known by. */
    data class Card(val vcard: String, val name: String, val numbers: List<String>) {
        /** The same person in two copies: same name, or (no name) same first number. */
        val key: String get() = name.lowercase().filter { it.isLetterOrDigit() }.ifEmpty { numbers.firstOrNull().orEmpty() }
    }

    /** The vCards in a .vcf, each with its name (FN) and numbers (TEL, digits only, last 10). Pure. */
    fun parse(vcf: String): List<Card> {
        val out = ArrayList<Card>()
        var at = 0
        while (true) {
            val begin = vcf.indexOf("BEGIN:VCARD", at, ignoreCase = true); if (begin < 0) break
            val endTag = vcf.indexOf("END:VCARD", begin, ignoreCase = true); if (endTag < 0) break
            val end = endTag + "END:VCARD".length
            val card = vcf.substring(begin, end)
            val lines = card.replace("\r\n ", "").replace("\n ", "").lines()    // unfold
            val name = lines.firstOrNull { it.uppercase().startsWith("FN") }?.substringAfter(':')?.trim().orEmpty()
            val numbers = lines.filter { it.uppercase().startsWith("TEL") }.map { it.substringAfter(':').filter(Char::isDigit).takeLast(10) }.filter { it.length >= 7 }
            out += Card(card.trim(), name, numbers)
            at = end
        }
        return out
    }

    /** Who was in [before] and isn't in [now] (by name, or number when there's no name). Pure. */
    fun disappeared(before: List<Card>, now: List<Card>): List<Card> {
        val keys = now.map { it.key }.toSet()
        val numbers = now.flatMap { it.numbers }.toSet()
        return before.filter { c -> c.key.isNotEmpty() && c.key !in keys && c.numbers.none { it in numbers } }.distinctBy { it.key }
    }

    fun canRead(ctx: Context) = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun dir(ctx: Context) = File(ctx.filesDir, "contacts-copies").also { it.mkdirs() }

    /** The copies kept, newest first. */
    fun copies(ctx: Context): List<File> = dir(ctx).listFiles { f -> f.name.endsWith(".vcf") }.orEmpty().sortedByDescending { it.lastModified() }

    /** Every contact on the phone as one .vcf text. */
    fun current(ctx: Context): String {
        val cr = ctx.contentResolver
        val sb = StringBuilder()
        cr.query(ContactsContract.Contacts.CONTENT_URI, arrayOf(ContactsContract.Contacts.LOOKUP_KEY), null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val lk = c.getString(0) ?: continue
                runCatching { cr.openInputStream(Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_VCARD_URI, lk))?.use { sb.append(it.bufferedReader().readText()).append("\r\n") } }
            }
        }
        return sb.toString()
    }

    data class Result(val file: File, val count: Int, val gone: List<Card>, val since: Long?)

    /** Makes this week's copy and says who's gone since the last one. null without permission or with no contacts. */
    fun make(ctx: Context, now: Long = System.currentTimeMillis()): Result? {
        if (!canRead(ctx)) return null
        val text = current(ctx)
        val cards = parse(text)
        if (cards.isEmpty()) return null
        val last = copies(ctx).firstOrNull()
        val gone = last?.let { disappeared(parse(it.readText()), cards) }.orEmpty()
        val name = "Contacts " + SimpleDateFormat("yyyy-MM-dd HHmm", Locale.US).format(Date(now)) + ".vcf"
        val f = File(dir(ctx), name).also { it.writeText(text) }
        copies(ctx).drop(8).forEach { it.delete() }
        return Result(f, cards.size, gone, last?.lastModified())
    }

    fun notice(gone: Int): String = if (gone == 1) com.handytools.app.I18n.t("1 contact has disappeared since last week's copy — tap to bring it back.")
        else com.handytools.app.I18n.fmt("%d contacts have disappeared since last week's copy — tap to bring them back.", gone)

    /** One or more contacts as a .vcf the phone's Contacts app can take back. */
    fun handBack(ctx: Context, cards: List<Card>): File =
        File(ctx.cacheDir, "bring-back-${System.nanoTime()}.vcf").also { it.writeText(cards.joinToString("\r\n") { c -> c.vcard } + "\r\n") }
}
