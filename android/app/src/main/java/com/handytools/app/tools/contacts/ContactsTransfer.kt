package com.handytools.app.tools.contacts

import android.content.ContentProviderOperation
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.provider.ContactsContract
import java.io.File

/** A place contacts are stored: a Google account, Exchange, or just this phone (no account). */
data class ContactAccount(val name: String?, val type: String?, val count: Int, val writable: Boolean) {
    val key get() = "${type.orEmpty()}|${name.orEmpty()}"
    val kind get() = when {
        type == null && name == null -> "On this phone"
        type == "com.google" -> "Google"
        type == "com.android.exchange" -> "Exchange"
        type?.contains("samsung", true) == true || type == "vnd.sec.contact.phone" -> "Samsung"
        else -> type?.substringAfterLast('.')?.replaceFirstChar { it.uppercase() } ?: "Other"
    }
    val title get() = if (name.isNullOrBlank()) kind else "$name · $kind"
}

/**
 * Copy or move contacts between accounts (for example Google to this phone, or the phone into Google).
 * Copy is the default and leaves the originals alone. Move deletes them only after the copies are saved.
 * Everything happens on this phone through the system contacts provider.
 */
object ContactsTransfer {
    data class Item(val id: Long, val name: String, val numbers: List<String>, val emails: List<String>)
    data class Outcome(val copied: Int = 0, val alreadyThere: Int = 0, val failed: Int = 0, val removed: Int = 0)

    // ---- pure matching (unit-tested) ----
    fun normName(s: String) = s.lowercase().filter { it.isLetterOrDigit() }
    private fun digits(n: String) = n.filter(Char::isDigit).takeLast(10)

    /** Same person already in the target: same name AND a shared number or email (or nothing else to compare). */
    fun same(a: Item, b: Item): Boolean {
        val an = a.numbers.map(::digits).filter { it.length >= 7 }; val bn = b.numbers.map(::digits).filter { it.length >= 7 }
        val ae = a.emails.map { it.lowercase() }; val be = b.emails.map { it.lowercase() }
        val shared = an.any { it in bn } || ae.any { it in be }
        val na = normName(a.name); val nb = normName(b.name)
        if (na.isEmpty() || nb.isEmpty()) return shared
        if (na != nb) return false
        return shared || (an.isEmpty() && ae.isEmpty() && bn.isEmpty() && be.isEmpty())
    }

    fun plan(source: List<Item>, existing: List<Item>): Pair<List<Item>, List<Item>> {
        val copy = mutableListOf<Item>(); val present = mutableListOf<Item>()
        val seen = existing.toMutableList()
        for (s in source) if (seen.any { same(s, it) }) present.add(s) else { copy.add(s); seen.add(s) }
        return copy to present
    }

    // ---- accounts ----
    /** Apps that keep a read-only mirror of contacts (chat apps). Copying into them would fail. */
    private val readOnlyTypes = listOf("whatsapp", "thoughtcrime", "signal", "telegram", "viber", "facebook", "linkedin", "instagram", "snapchat", "line", "kakao")

    private fun rawAccounts(ctx: Context): Map<Long, Pair<String?, String?>> {
        val out = HashMap<Long, Pair<String?, String?>>()
        ctx.contentResolver.query(ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(ContactsContract.RawContacts._ID, ContactsContract.RawContacts.ACCOUNT_NAME, ContactsContract.RawContacts.ACCOUNT_TYPE),
            "${ContactsContract.RawContacts.DELETED}=0", null, null)?.use { c ->
            while (c.moveToNext()) out[c.getLong(0)] = c.getString(1) to c.getString(2)
        }
        return out
    }

    fun accounts(ctx: Context): List<ContactAccount> =
        rawAccounts(ctx).values.groupingBy { it }.eachCount().map { (k, n) ->
            val (name, type) = k
            ContactAccount(name, type, n, writable = type == null || readOnlyTypes.none { type.contains(it, true) })
        }.sortedByDescending { it.count }

    // ---- reading ----
    private fun items(ctx: Context, account: ContactAccount): Map<Long, Item> {
        val ids = rawAccounts(ctx).filterValues { it.first == account.name && it.second == account.type }.keys
        val names = HashMap<Long, String>(); val nums = HashMap<Long, MutableList<String>>(); val mails = HashMap<Long, MutableList<String>>()
        ctx.contentResolver.query(ContactsContract.Data.CONTENT_URI,
            arrayOf(ContactsContract.Data.RAW_CONTACT_ID, ContactsContract.Data.MIMETYPE, ContactsContract.Data.DATA1), null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0); if (id !in ids) continue
                val v = c.getString(2) ?: continue
                when (c.getString(1)) {
                    ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE -> names[id] = v
                    ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE -> nums.getOrPut(id) { mutableListOf() }.add(v)
                    ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE -> mails.getOrPut(id) { mutableListOf() }.add(v)
                }
            }
        }
        return ids.associateWith { Item(it, names[it].orEmpty(), nums[it].orEmpty(), mails[it].orEmpty()) }
    }

    /** Every data row of one raw contact, as values ready to insert under a new raw contact. */
    private fun dataRows(ctx: Context, rawId: Long): List<ContentValues> {
        val rows = mutableListOf<ContentValues>()
        ctx.contentResolver.query(ContactsContract.Data.CONTENT_URI, null, "${ContactsContract.Data.RAW_CONTACT_ID}=?", arrayOf(rawId.toString()), null)?.use { c ->
            val mimeCol = c.getColumnIndexOrThrow(ContactsContract.Data.MIMETYPE)
            while (c.moveToNext()) {
                val mime = c.getString(mimeCol) ?: continue
                // Group memberships point at groups of the OLD account, so they can't travel.
                if (mime == ContactsContract.CommonDataKinds.GroupMembership.CONTENT_ITEM_TYPE) continue
                val cv = ContentValues(); cv.put(ContactsContract.Data.MIMETYPE, mime)
                for (n in 1..15) {
                    val i = c.getColumnIndex("data$n"); if (i < 0) continue
                    when (c.getType(i)) {
                        Cursor.FIELD_TYPE_STRING -> cv.put("data$n", c.getString(i))
                        Cursor.FIELD_TYPE_INTEGER -> cv.put("data$n", c.getLong(i))
                        Cursor.FIELD_TYPE_BLOB -> cv.put("data$n", c.getBlob(i))
                        else -> {}
                    }
                }
                rows.add(cv)
            }
        }
        return rows
    }

    private fun insertCopy(ctx: Context, rawId: Long, to: ContactAccount): Boolean = runCatching {
        val ops = ArrayList<ContentProviderOperation>()
        ops.add(ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
            .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, to.type).withValue(ContactsContract.RawContacts.ACCOUNT_NAME, to.name).build())
        for (row in dataRows(ctx, rawId)) {
            ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0).withValues(row).build())
        }
        ctx.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
        true
    }.getOrDefault(false)

    /** Copy (or move) every contact in [from] into [to], skipping people already there. */
    fun transfer(ctx: Context, from: ContactAccount, to: ContactAccount, move: Boolean, progress: (Float) -> Unit = {}): Outcome {
        val source = items(ctx, from).values.toList()
        val existing = items(ctx, to).values.toList()
        val (copy, present) = plan(source, existing)
        var copied = 0; var failed = 0
        val safeToRemove = present.map { it.id }.toMutableList()
        copy.forEachIndexed { i, it ->
            if (insertCopy(ctx, it.id, to)) { copied++; safeToRemove.add(it.id) } else failed++
            if (i % 10 == 0) progress(i / copy.size.coerceAtLeast(1).toFloat())
        }
        var removed = 0
        if (move) {
            // An original is removed only when its copy is saved or it was already in the target.
            for (id in safeToRemove) {
                val n = runCatching { ctx.contentResolver.delete(ContactsContract.RawContacts.CONTENT_URI, "${ContactsContract.RawContacts._ID}=?", arrayOf(id.toString())) }.getOrDefault(0)
                if (n > 0) removed++
            }
        }
        progress(1f)
        return Outcome(copied, present.size, failed, removed)
    }

    /** Keep a copy of everything in [from] as a .vcf before a move removes anything. */
    fun backup(ctx: Context, from: ContactAccount): File? = runCatching {
        val ids = rawAccounts(ctx).filterValues { it.first == from.name && it.second == from.type }.keys
        val lookups = linkedSetOf<String>()
        ctx.contentResolver.query(ContactsContract.RawContacts.CONTENT_URI, arrayOf(ContactsContract.RawContacts._ID, ContactsContract.RawContacts.CONTACT_ID), null, null, null)?.use { c ->
            val contactIds = HashSet<Long>()
            while (c.moveToNext()) if (c.getLong(0) in ids) contactIds.add(c.getLong(1))
            ctx.contentResolver.query(ContactsContract.Contacts.CONTENT_URI, arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.LOOKUP_KEY), null, null, null)?.use { k ->
                while (k.moveToNext()) if (k.getLong(0) in contactIds) k.getString(1)?.let(lookups::add)
            }
        }
        val out = File(ctx.cacheDir, "contacts-before-move-${System.currentTimeMillis()}.vcf")
        out.outputStream().use { os ->
            for (lk in lookups) runCatching {
                ctx.contentResolver.openInputStream(android.net.Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_VCARD_URI, lk))?.use { it.copyTo(os) }
            }
        }
        out
    }.getOrNull()
}
