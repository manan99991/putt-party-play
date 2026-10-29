package com.handytools.app.tools.power

import android.content.ContentUris
import android.content.Context
import android.content.IntentSender
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.ContactsContract
import android.provider.MediaStore
import android.util.LruCache
import android.util.Size
import com.handytools.app.tools.contacts.ContactRec
import com.handytools.app.tools.spaceclean.SpaceCleanerEngine
import com.handytools.app.tools.storage.StorageEngine
import java.io.File

internal data class CleanItem(val uri: Uri, val name: String, val size: Long, val isVideo: Boolean, val group: Int = -1, val why: String? = null)

internal class CleanCategory(val id: String, val title: String, val grouped: Boolean, items: List<CleanItem>) {
    var items: List<CleanItem> = items
    val bytes: Long get() = items.sumOf { it.size }
}

internal data class CleanScan(val usedBytes: Long, val totalBytes: Long, val categories: List<CleanCategory>)

/** A file we moved to the pre-Android-11 folder trash (Pictures/Tenzy/.trash), so it can come back. */
internal data class LegacyTrashRecord(val original: String, val trashed: String, val name: String, val size: Long, val isVideo: Boolean)

/** Clean Up: builds on SpaceCleanerEngine (dupes/look-alikes/screenshots) and StorageEngine (used space). */
internal object CleanupEngine {
    private const val LARGE_VIDEO = 100L * 1024 * 1024
    private const val BLUR_CAP = 500
    private const val PREFS = "tenzy_cleanup_trash"

    fun scan(ctx: Context, onPhase: (String, Float) -> Unit): CleanScan {
        onPhase("Measuring storage…", 0.08f)
        val storage = runCatching { StorageEngine.scan(ctx) }.getOrNull()
        onPhase("Finding duplicates & look-alikes…", 0.2f)
        val report = SpaceCleanerEngine.scan(ctx)
        val dupes = ArrayList<CleanItem>()
        var g = 0
        (report.exactDupes + report.similar).forEach { grp ->
            grp.items.sortedByDescending { it.size }.forEach { dupes.add(CleanItem(it.uri, it.name, it.size, false, g)) }
            g++
        }
        onPhase("Checking videos…", 0.6f)
        val videos = largeVideos(ctx)
        onPhase("Looking for blurry & dark shots…", 0.75f)
        val skip = dupes.map { it.uri }.toHashSet()
        val blurry = blurryOrDark(ctx, skip)
        onPhase("Done", 1f)
        val cats = listOf(
            CleanCategory("dupes", "Duplicate & look-alike photos", true, dupes),
            CleanCategory("videos", "Large videos", false, videos),
            CleanCategory("shots", "Screenshots", false, report.screenshots?.items?.map { CleanItem(it.uri, it.name, it.size, false) } ?: emptyList()),
            CleanCategory("blurry", "Blurry & dark shots", false, blurry),
        )
        return CleanScan(storage?.usedBytes ?: report.totalBytes, storage?.totalBytes ?: 0L, cats)
    }

    private fun largeVideos(ctx: Context): List<CleanItem> {
        val out = ArrayList<CleanItem>()
        val proj = arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME, MediaStore.Video.Media.SIZE)
        runCatching {
            ctx.contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, proj, "${MediaStore.Video.Media.SIZE} >= ?",
                arrayOf(LARGE_VIDEO.toString()), "${MediaStore.Video.Media.SIZE} DESC")?.use { c ->
                val iId = c.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val iN = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                val iS = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                while (c.moveToNext()) {
                    out.add(CleanItem(ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, c.getLong(iId)), c.getString(iN) ?: "video", c.getLong(iS), true))
                }
            }
        }
        return out
    }

    /** Laplacian variance + mean luminance on a 64 px thumbnail: cheap, newest 500 photos, screenshots skipped. */
    private fun blurryOrDark(ctx: Context, skip: Set<Uri>): List<CleanItem> {
        val out = ArrayList<CleanItem>()
        val proj = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.SIZE, MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
        val candidates = ArrayList<CleanItem>()
        runCatching {
            ctx.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, proj, null, null, "${MediaStore.Images.Media.DATE_ADDED} DESC")?.use { c ->
                val iId = c.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val iN = c.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                val iS = c.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
                val iB = c.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
                while (c.moveToNext() && candidates.size < BLUR_CAP) {
                    if ((c.getString(iB) ?: "").equals("Screenshots", true)) continue
                    val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, c.getLong(iId))
                    if (uri in skip) continue
                    val name = c.getString(iN) ?: "photo"
                    if (name.lowercase().endsWith(".gif")) continue
                    candidates.add(CleanItem(uri, name, c.getLong(iS), false))
                }
            }
        }
        for (item in candidates) {
            val bmp = tinyGray(ctx, item.uri) ?: continue
            val (lapVar, mean) = sharpnessAndLight(bmp)
            bmp.recycle()
            val why = when {
                mean < 35 -> "Very dark"
                lapVar < 45.0 -> "Looks blurry"
                else -> null
            }
            if (why != null) out.add(item.copy(why = why))
        }
        return out
    }

    private fun tinyGray(ctx: Context, uri: Uri): Bitmap? = runCatching {
        val src = if (Build.VERSION.SDK_INT >= 29) ctx.contentResolver.loadThumbnail(uri, Size(96, 96), null)
        else {
            val opts = BitmapFactory.Options().apply { inSampleSize = 16 }
            ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
        } ?: return null
        val small = Bitmap.createScaledBitmap(src, 64, 64, true)
        if (small != src) src.recycle()
        small
    }.getOrNull()

    private fun sharpnessAndLight(bmp: Bitmap): Pair<Double, Int> {
        val w = bmp.width; val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        val gray = IntArray(w * h)
        var sum = 0L
        for (i in px.indices) {
            val p = px[i]
            val gval = (((p shr 16) and 0xff) * 299 + ((p shr 8) and 0xff) * 587 + (p and 0xff) * 114) / 1000
            gray[i] = gval; sum += gval
        }
        val mean = (sum / px.size.coerceAtLeast(1)).toInt()
        var lapSum = 0.0; var lapSq = 0.0; var n = 0
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x
            val lap = (4 * gray[i] - gray[i - 1] - gray[i + 1] - gray[i - w] - gray[i + w]).toDouble()
            lapSum += lap; lapSq += lap * lap; n++
        }
        if (n == 0) return 0.0 to mean
        val m = lapSum / n
        return (lapSq / n - m * m) to mean
    }

    // ------------------------------------------------------------------ thumbnails

    private val cache = LruCache<String, Bitmap>(160)

    fun thumbnail(ctx: Context, uri: Uri, isVideo: Boolean): Bitmap? {
        cache.get(uri.toString())?.let { return it }
        val bmp = runCatching {
            if (Build.VERSION.SDK_INT >= 29) ctx.contentResolver.loadThumbnail(uri, Size(256, 256), null)
            else legacyThumbnail(ctx, uri, isVideo)
        }.getOrNull()
        if (bmp != null) cache.put(uri.toString(), bmp)
        return bmp
    }

    @Suppress("DEPRECATION")
    private fun legacyThumbnail(ctx: Context, uri: Uri, isVideo: Boolean): Bitmap? {
        val id = ContentUris.parseId(uri)
        return if (isVideo) MediaStore.Video.Thumbnails.getThumbnail(ctx.contentResolver, id, MediaStore.Video.Thumbnails.MINI_KIND, null)
        else MediaStore.Images.Thumbnails.getThumbnail(ctx.contentResolver, id, MediaStore.Images.Thumbnails.MINI_KIND, null)
    }

    // ------------------------------------------------------------------ trash (Android 11+)

    fun trashRequest(ctx: Context, uris: List<Uri>, toTrash: Boolean): IntentSender? {
        if (uris.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return MediaStore.createTrashRequest(ctx.contentResolver, uris, toTrash).intentSender
    }

    fun deleteRequest(ctx: Context, uris: List<Uri>): IntentSender? {
        if (uris.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return MediaStore.createDeleteRequest(ctx.contentResolver, uris).intentSender
    }

    /** What the system Trash currently holds (that this app is allowed to see). */
    fun systemTrash(ctx: Context): List<CleanItem> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        val out = ArrayList<CleanItem>()
        val args = Bundle().apply { putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_ONLY) }
        val proj = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.SIZE)
        listOf(MediaStore.Images.Media.EXTERNAL_CONTENT_URI to false, MediaStore.Video.Media.EXTERNAL_CONTENT_URI to true).forEach { (base, isVideo) ->
            runCatching {
                ctx.contentResolver.query(base, proj, args, null)?.use { c ->
                    val iId = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                    val iN = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                    val iS = c.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                    while (c.moveToNext()) out.add(CleanItem(ContentUris.withAppendedId(base, c.getLong(iId)), c.getString(iN) ?: "file", c.getLong(iS), isVideo))
                }
            }
        }
        return out
    }

    // ------------------------------------------------------------------ trash (Android 8–10: folder trash)

    private fun legacyTrashDir(): File = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Tenzy/.trash").apply { mkdirs() }

    @Suppress("DEPRECATION")
    private fun pathOf(ctx: Context, uri: Uri): String? = runCatching {
        ctx.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }.getOrNull()

    fun legacyTrash(ctx: Context, items: List<CleanItem>): List<LegacyTrashRecord> {
        val moved = ArrayList<LegacyTrashRecord>()
        val dir = legacyTrashDir()
        items.forEach { item ->
            val path = pathOf(ctx, item.uri) ?: return@forEach
            val src = File(path)
            if (!src.exists()) return@forEach
            val dst = File(dir, "${System.currentTimeMillis()}_${src.name}")
            if (src.renameTo(dst)) {
                runCatching { ctx.contentResolver.delete(item.uri, null, null) }
                moved.add(LegacyTrashRecord(path, dst.absolutePath, item.name, item.size, item.isVideo))
            }
        }
        if (moved.isNotEmpty()) saveLegacy(ctx, legacyRecords(ctx) + moved)
        return moved
    }

    fun legacyRecords(ctx: Context): List<LegacyTrashRecord> =
        ctx.getSharedPreferences(PREFS, 0).getStringSet("records", emptySet())?.mapNotNull { line ->
            val p = line.split("|")
            if (p.size < 5) null else LegacyTrashRecord(p[0], p[1], p[2], p[3].toLongOrNull() ?: 0L, p[4] == "1")
        }?.filter { File(it.trashed).exists() } ?: emptyList()

    private fun saveLegacy(ctx: Context, records: List<LegacyTrashRecord>) {
        ctx.getSharedPreferences(PREFS, 0).edit().putStringSet("records",
            records.map { "${it.original}|${it.trashed}|${it.name}|${it.size}|${if (it.isVideo) "1" else "0"}" }.toSet()).apply()
    }

    fun legacyRestoreAll(ctx: Context): Int {
        var n = 0
        val restoredPaths = ArrayList<String>()
        legacyRecords(ctx).forEach { r ->
            val src = File(r.trashed)
            val dst = File(r.original)
            dst.parentFile?.mkdirs()
            if (src.exists() && src.renameTo(dst)) { n++; restoredPaths.add(dst.absolutePath) }
        }
        if (restoredPaths.isNotEmpty()) MediaScannerConnection.scanFile(ctx, restoredPaths.toTypedArray(), null, null)
        saveLegacy(ctx, emptyList())
        return n
    }

    fun legacyDeleteAll(ctx: Context): Int {
        var n = 0
        legacyRecords(ctx).forEach { r -> if (File(r.trashed).delete()) n++ }
        saveLegacy(ctx, emptyList())
        return n
    }

    // ------------------------------------------------------------------ contacts extras

    private val accountNames = mapOf(
        "com.google" to "Google", "com.whatsapp" to "WhatsApp", "com.android.contacts.sim" to "SIM", "vnd.sec.contact.sim" to "SIM",
        "vnd.sec.contact.phone" to "Phone", "com.android.localphone" to "Phone", "com.samsung.android.coreapps" to "Phone",
        "com.microsoft.office.outlook" to "Outlook", "com.telegram.messenger" to "Telegram", "org.telegram.messenger" to "Telegram",
        "com.viber.voip" to "Viber", "com.skype.raider" to "Skype", "com.signal" to "Signal", "org.thoughtcrime.securesms" to "Signal",
    )

    /** Friendly names of the accounts a duplicate group's raw contacts come from ("Phone, Google"). */
    fun sources(ctx: Context, group: List<ContactRec>): List<String> {
        val rawIds = group.flatMap { it.rawIds }.distinct()
        if (rawIds.isEmpty()) return emptyList()
        val out = linkedSetOf<String>()
        runCatching {
            val sel = "${ContactsContract.RawContacts._ID} IN (${rawIds.joinToString(",") { "?" }})"
            ctx.contentResolver.query(ContactsContract.RawContacts.CONTENT_URI, arrayOf(ContactsContract.RawContacts.ACCOUNT_TYPE),
                sel, rawIds.map { it.toString() }.toTypedArray(), null)?.use { c ->
                while (c.moveToNext()) {
                    val t = c.getString(0)
                    out.add(if (t == null) "Phone" else accountNames[t] ?: t.substringAfterLast('.').replaceFirstChar { ch -> ch.uppercase() })
                }
            }
        }
        return out.toList()
    }

    /** Delete contacts that have neither a name nor a number. There is no contacts trash, so the caller confirms first. */
    fun deleteEmpty(ctx: Context, recs: List<ContactRec>): Int {
        var n = 0
        recs.forEach { r ->
            val lk = r.lookupKey ?: return@forEach
            val uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_LOOKUP_URI, lk)
            runCatching { if (ctx.contentResolver.delete(uri, null, null) > 0) n++ }
        }
        return n
    }

    fun human(bytes: Long): String = SpaceCleanerEngine.humanSize(bytes)
}
