package com.handytools.app.tools.autoruns

import android.content.ContentProviderOperation
import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.tools.builder.TextTidy
import com.handytools.app.tools.power.CaptureClassifier
import com.handytools.app.tools.power.CaptureKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Today's receipts into my expense sheet, and business cards into my contacts (the iPhone's autoruns): the day's photos
 * are read on the phone (ML Kit text), and the ones that are receipts or business cards are picked out with the same
 * reading Capture uses — shop, date and total; name, title, company, phone and email. Nothing is added until the person
 * has looked them over; a card already in Contacts (same phone or email) is shown, not added twice.
 */
object PaperFinds {
    /** A receipt found in a photo (the photo's uri as text, so the rules stay pure). */
    data class Receipt(val photo: String, val merchant: String, val total: String, val dateMs: Long?)
    data class Card(val photo: String, val name: String, val title: String, val company: String, val phone: String, val email: String,
                    val taken: Long, val already: String? = null)

    /** Every photo in [window] read and sorted into receipts and cards. [progress] runs 0…1. */
    suspend fun read(ctx: Context, window: LongRange, progress: (Double) -> Unit = {}): Pair<List<Receipt>, List<Card>> = withContext(Dispatchers.Default) {
        val photos = PhotoDays.find(ctx, window).filterNot { it.screenshot }
        val reader = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val receipts = ArrayList<Receipt>(); val cards = ArrayList<Card>()
        try {
            photos.forEachIndexed { i, p ->
                ensureActive()
                progress((i + 1).toDouble() / photos.size)
                val b = PhotoDays.small(ctx, p.uri, 1600) ?: return@forEachIndexed
                val text = runCatching { Tasks.await(reader.process(InputImage.fromBitmap(b, 0))).text }.getOrDefault("")
                b.recycle()
                if (text.isBlank()) return@forEachIndexed
                val r = CaptureClassifier.classify(text)
                when {
                    r.kind == CaptureKind.RECEIPT && r.total.isNotBlank() -> receipts += Receipt(p.uri.toString(), r.merchant, r.total, r.purchaseMs ?: p.created)
                    r.kind == CaptureKind.CARD && (r.phone.isNotBlank() || r.email.isNotBlank()) ->
                        cards += Card(p.uri.toString(), r.name, r.title, r.company, r.phone, r.email, p.created)
                }
            }
        } finally { reader.close() }
        receipts to dedupedCards(cards).map { it.copy(already = existing(ctx, it)) }
    }

    /** The same card photographed twice (or both sides) counts once: a shared phone or email. Pure. */
    fun dedupedCards(cards: List<Card>): List<Card> {
        val out = ArrayList<Card>()
        fun digits(s: String) = s.filter(Char::isDigit).takeLast(10)
        for (c in cards) {
            val i = out.indexOfFirst { o -> (c.email.isNotBlank() && o.email.equals(c.email, true)) || (digits(c.phone).length >= 7 && digits(o.phone) == digits(c.phone)) }
            if (i < 0) out += c
            else { val o = out[i]; out[i] = o.copy(name = o.name.ifBlank { c.name }, title = o.title.ifBlank { c.title }, company = o.company.ifBlank { c.company },
                phone = o.phone.ifBlank { c.phone }, email = o.email.ifBlank { c.email }) }
        }
        return out
    }

    /** The name a card's person is already saved under in Contacts (same phone or email), if they are. */
    fun existing(ctx: Context, c: Card): String? {
        val cr = ctx.contentResolver
        fun first(uri: Uri, col: String): String? = runCatching { cr.query(uri, arrayOf(col), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null } }.getOrNull()
        if (c.phone.isNotBlank()) first(Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(c.phone)), ContactsContract.PhoneLookup.DISPLAY_NAME)?.let { return it }
        if (c.email.isNotBlank()) first(Uri.withAppendedPath(ContactsContract.CommonDataKinds.Email.CONTENT_FILTER_URI, Uri.encode(c.email)), ContactsContract.CommonDataKinds.Email.DISPLAY_NAME)?.let { return it }
        return null
    }

    /** The expense sheet the receipts go into (the Build steps' own sheet: "Expenses yyyy-MM"). */
    fun expenseSheet(ctx: Context): File = File(File(ctx.filesDir, "lists").also { it.mkdirs() }, TextTidy.fileName(TextTidy.DEFAULT_LIST, "List", ext = "csv"))

    /** Adds [receipts] to the expense sheet; the sheet. */
    fun addToSheet(ctx: Context, receipts: List<Receipt>): File {
        val f = expenseSheet(ctx)
        var sheet = if (f.exists()) f.readText() else ""
        receipts.forEach { r -> sheet = TextTidy.mergedList(sheet, TextTidy.expenseRow(r.dateMs, r.merchant, r.total)) }
        f.writeText(sheet)
        return f
    }

    /** Saves the new cards (not already in Contacts) with "Met on <day>". How many were added. */
    fun saveCards(ctx: Context, cards: List<Card>): Int {
        var n = 0
        val day = SimpleDateFormat("d MMM yyyy", Locale.getDefault())
        for (c in cards) {
            if (c.already != null || existing(ctx, c) != null) continue
            val ops = arrayListOf(ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null).withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null).build())
            fun data(mime: String, vararg kv: Pair<String, String>) {
                ops += ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI).withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                    .withValue(ContactsContract.Data.MIMETYPE, mime).apply { kv.forEach { (k, v) -> withValue(k, v) } }.build()
            }
            if (c.name.isNotBlank()) data(ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE, ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME to c.name)
            if (c.company.isNotBlank() || c.title.isNotBlank()) data(ContactsContract.CommonDataKinds.Organization.CONTENT_ITEM_TYPE,
                ContactsContract.CommonDataKinds.Organization.COMPANY to c.company, ContactsContract.CommonDataKinds.Organization.TITLE to c.title)
            if (c.phone.isNotBlank()) data(ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE, ContactsContract.CommonDataKinds.Phone.NUMBER to c.phone,
                ContactsContract.CommonDataKinds.Phone.TYPE to ContactsContract.CommonDataKinds.Phone.TYPE_WORK.toString())
            if (c.email.isNotBlank()) data(ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE, ContactsContract.CommonDataKinds.Email.ADDRESS to c.email,
                ContactsContract.CommonDataKinds.Email.TYPE to ContactsContract.CommonDataKinds.Email.TYPE_WORK.toString())
            data(ContactsContract.CommonDataKinds.Note.CONTENT_ITEM_TYPE, ContactsContract.CommonDataKinds.Note.NOTE to
                com.handytools.app.I18n.fmt("Met on %@", day.format(Date(c.taken))))
            if (runCatching { ctx.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops) }.isSuccess) n++
        }
        return n
    }
}
