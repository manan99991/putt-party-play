package com.handytools.app.tools.contacts

import android.content.ContentProviderOperation
import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import java.io.File

/** One aggregated contact plus the raw-contact rows behind it (needed to merge). */
data class ContactRec(
    val contactId: Long,
    val rawIds: MutableList<Long> = mutableListOf(),
    var name: String = "",
    val numbers: MutableSet<String> = linkedSetOf(),
    val emails: MutableSet<String> = linkedSetOf(),
    var lookupKey: String? = null
) {
    val hasName get() = name.isNotBlank()
    val hasNumber get() = numbers.isNotEmpty()
    fun normName() = name.lowercase().filter { it.isLetterOrDigit() }
    fun normNumbers() = numbers.map { it.filter(Char::isDigit).takeLast(10) }.filter { it.length >= 7 }
    fun whyIncomplete(): String = when {
        !hasName && !hasNumber -> "No name or number"
        !hasName -> "No name"
        else -> "No phone number"
    }
}

data class ContactsReport(
    val total: Int,
    val duplicateGroups: List<List<ContactRec>>,
    val incomplete: List<ContactRec>
) {
    val duplicateCount get() = duplicateGroups.sumOf { it.size - 1 }
}

/** Contacts cleanup: find duplicates + incomplete entries, merge without losing data, export a backup. */
object ContactsEngine {

    fun scan(ctx: Context): ContactsReport {
        val cr = ctx.contentResolver
        val byId = linkedMapOf<Long, ContactRec>()

        cr.query(ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME, ContactsContract.Contacts.LOOKUP_KEY),
            null, null, null)?.use { c ->
            val iId = c.getColumnIndexOrThrow(ContactsContract.Contacts._ID)
            val iName = c.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)
            val iLk = c.getColumnIndexOrThrow(ContactsContract.Contacts.LOOKUP_KEY)
            while (c.moveToNext()) {
                val id = c.getLong(iId)
                byId[id] = ContactRec(contactId = id, name = c.getString(iName) ?: "", lookupKey = c.getString(iLk))
            }
        }
        cr.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Phone.CONTACT_ID, ContactsContract.CommonDataKinds.Phone.NUMBER),
            null, null, null)?.use { c ->
            val iC = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val iN = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (c.moveToNext()) { byId[c.getLong(iC)]?.numbers?.add((c.getString(iN) ?: "").trim()) }
        }
        cr.query(ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Email.CONTACT_ID, ContactsContract.CommonDataKinds.Email.ADDRESS),
            null, null, null)?.use { c ->
            val iC = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.CONTACT_ID)
            val iA = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.ADDRESS)
            while (c.moveToNext()) { byId[c.getLong(iC)]?.emails?.add((c.getString(iA) ?: "").trim()) }
        }
        cr.query(ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(ContactsContract.RawContacts._ID, ContactsContract.RawContacts.CONTACT_ID),
            null, null, null)?.use { c ->
            val iR = c.getColumnIndexOrThrow(ContactsContract.RawContacts._ID)
            val iC = c.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID)
            while (c.moveToNext()) { byId[c.getLong(iC)]?.rawIds?.add(c.getLong(iR)) }
        }

        val all = byId.values.toList()
        val groups = mutableListOf<List<ContactRec>>()
        val seen = hashSetOf<Long>()

        // Group by normalized display name.
        all.filter { it.normName().isNotEmpty() }
            .groupBy { it.normName() }
            .values.filter { it.size > 1 }
            .forEach { g -> groups.add(g); g.forEach { seen.add(it.contactId) } }

        // Then group remaining by a shared normalized phone number.
        val byNum = hashMapOf<String, MutableList<ContactRec>>()
        all.filter { it.contactId !in seen }.forEach { rec ->
            rec.normNumbers().forEach { n -> byNum.getOrPut(n) { mutableListOf() }.add(rec) }
        }
        byNum.values.forEach { recs ->
            val uniq = recs.distinctBy { it.contactId }
            if (uniq.size > 1 && uniq.none { it.contactId in seen }) {
                groups.add(uniq); uniq.forEach { seen.add(it.contactId) }
            }
        }

        val incomplete = all.filter { !it.hasName || !it.hasNumber }
        return ContactsReport(all.size, groups, incomplete)
    }

    /** Merge a duplicate group by joining their raw contacts (keeps all data; nothing deleted). */
    fun merge(ctx: Context, group: List<ContactRec>) {
        val rawIds = group.flatMap { it.rawIds }.distinct()
        if (rawIds.size < 2) return
        val ops = ArrayList<ContentProviderOperation>()
        val anchor = rawIds.first()
        for (i in 1 until rawIds.size) {
            ops.add(ContentProviderOperation.newUpdate(ContactsContract.AggregationExceptions.CONTENT_URI)
                .withValue(ContactsContract.AggregationExceptions.TYPE, ContactsContract.AggregationExceptions.TYPE_KEEP_TOGETHER)
                .withValue(ContactsContract.AggregationExceptions.RAW_CONTACT_ID1, anchor)
                .withValue(ContactsContract.AggregationExceptions.RAW_CONTACT_ID2, rawIds[i])
                .build())
        }
        ctx.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
    }

    /** Export every contact to a .vcf backup file and return it. */
    fun exportVcf(ctx: Context): File {
        val cr = ctx.contentResolver
        val out = File(ctx.cacheDir, "contacts-backup-${System.currentTimeMillis()}.vcf")
        out.outputStream().use { os ->
            cr.query(ContactsContract.Contacts.CONTENT_URI,
                arrayOf(ContactsContract.Contacts.LOOKUP_KEY), null, null, null)?.use { c ->
                val iLk = c.getColumnIndexOrThrow(ContactsContract.Contacts.LOOKUP_KEY)
                while (c.moveToNext()) {
                    val lk = c.getString(iLk) ?: continue
                    val uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_VCARD_URI, lk)
                    runCatching { cr.openInputStream(uri)?.use { it.copyTo(os) } }
                }
            }
        }
        return out
    }
}
