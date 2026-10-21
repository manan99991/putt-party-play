package com.handytools.app.tools.spaceclean

import android.content.ContentUris
import android.content.Context
import android.content.IntentSender
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import java.security.MessageDigest

data class MediaItem(val uri: Uri, val name: String, val size: Long, val bucket: String)

data class CleanGroup(val label: String, val items: List<MediaItem>, val reclaim: Long)

data class CleanReport(
    val totalBytes: Long,
    val exactDupes: List<CleanGroup>,
    val similar: List<CleanGroup>,
    val screenshots: CleanGroup?,
    val largeFiles: CleanGroup?
) {
    val reclaimable get() =
        exactDupes.sumOf { it.reclaim } + similar.sumOf { it.reclaim } +
        (screenshots?.reclaim ?: 0L) + (largeFiles?.reclaim ?: 0L)
}

/** On-device photo/storage cleanup: exact dupes, look-alikes, the screenshot pile, and large images. */
object SpaceCleanerEngine {
    private const val LARGE = 20L * 1024 * 1024 // 20 MB
    private const val SIMILAR_CAP = 1500        // cap perceptual hashing for responsiveness

    fun scan(ctx: Context): CleanReport {
        val cr = ctx.contentResolver
        val images = mutableListOf<MediaItem>()
        val proj = arrayOf(
            MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.SIZE, MediaStore.Images.Media.BUCKET_DISPLAY_NAME
        )
        cr.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, proj, null, null,
            "${MediaStore.Images.Media.DATE_ADDED} DESC")?.use { c ->
            val iId = c.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val iN = c.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val iS = c.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val iB = c.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
            while (c.moveToNext()) {
                val id = c.getLong(iId)
                images.add(MediaItem(
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id),
                    c.getString(iN) ?: "image", c.getLong(iS), c.getString(iB) ?: ""))
            }
        }
        val total = images.sumOf { it.size }

        // Exact duplicates: same size, confirmed by a content hash (first 1 MB).
        val exact = mutableListOf<CleanGroup>()
        images.groupBy { it.size }.values.filter { it.size > 1 }.forEach { sameSize ->
            val byHash = hashMapOf<String, MutableList<MediaItem>>()
            sameSize.forEach { m -> contentHash(ctx, m.uri)?.let { h -> byHash.getOrPut(h) { mutableListOf() }.add(m) } }
            byHash.values.filter { it.size > 1 }.forEach { g ->
                exact.add(CleanGroup("${g.size} identical copies", g, g.drop(1).sumOf { it.size }))
            }
        }
        val exactUris = exact.flatMap { it.items }.map { it.uri }.toHashSet()

        // Look-alikes via difference-hash (dHash), excluding exact dupes already found.
        val similar = mutableListOf<CleanGroup>()
        val hashed = images.asSequence().filter { it.uri !in exactUris }.take(SIMILAR_CAP)
            .mapNotNull { m -> dHash(ctx, m.uri)?.let { it to m } }.toList()
        val used = hashSetOf<Uri>()
        for (i in hashed.indices) {
            val (h1, m1) = hashed[i]
            if (m1.uri in used) continue
            val cluster = mutableListOf(m1)
            for (j in i + 1 until hashed.size) {
                val (h2, m2) = hashed[j]
                if (m2.uri in used) continue
                if (hamming(h1, h2) <= 6) { cluster.add(m2); used.add(m2.uri) }
            }
            if (cluster.size > 1) { used.add(m1.uri); similar.add(CleanGroup("${cluster.size} look-alikes", cluster, cluster.drop(1).sumOf { it.size })) }
        }

        val shots = images.filter { it.bucket.equals("Screenshots", true) }
        val screenshots = if (shots.isNotEmpty()) CleanGroup("${shots.size} screenshots", shots, shots.sumOf { it.size }) else null

        val large = images.filter { it.size >= LARGE }.sortedByDescending { it.size }
        val largeFiles = if (large.isNotEmpty()) CleanGroup("${large.size} large images", large, large.sumOf { it.size }) else null

        return CleanReport(total, exact, similar, screenshots, largeFiles)
    }

    private fun contentHash(ctx: Context, uri: Uri): String? = runCatching {
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            val md = MessageDigest.getInstance("MD5")
            val buf = ByteArray(1 shl 16); var n: Int; var read = 0L
            while (read < (1L shl 20) && ins.read(buf).also { n = it } > 0) { md.update(buf, 0, n); read += n }
            md.digest().joinToString("") { "%02x".format(it) }
        }
    }.getOrNull()

    private fun dHash(ctx: Context, uri: Uri): Long? = runCatching {
        val opts = BitmapFactory.Options().apply { inSampleSize = 8 }
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        val small = Bitmap.createScaledBitmap(bmp, 9, 8, true)
        var hash = 0L; var bit = 0
        for (y in 0 until 8) for (x in 0 until 8) {
            if (gray(small.getPixel(x, y)) > gray(small.getPixel(x + 1, y))) hash = hash or (1L shl bit)
            bit++
        }
        bmp.recycle(); small.recycle()
        hash
    }.getOrNull()

    private fun gray(p: Int): Int {
        val r = (p shr 16) and 0xff; val g = (p shr 8) and 0xff; val b = p and 0xff
        return (r * 299 + g * 587 + b * 114) / 1000
    }

    private fun hamming(a: Long, b: Long): Int = java.lang.Long.bitCount(a xor b)

    /** System delete request (user confirms the batch). Android 11+. */
    fun deleteRequest(ctx: Context, uris: List<Uri>): IntentSender? {
        if (uris.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return MediaStore.createDeleteRequest(ctx.contentResolver, uris).intentSender
    }

    /** Pre-Android-11 best-effort direct delete. */
    fun deleteLegacy(ctx: Context, uris: List<Uri>): Int {
        var n = 0
        uris.forEach { runCatching { if (ctx.contentResolver.delete(it, null, null) > 0) n++ } }
        return n
    }

    fun humanSize(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val kb = bytes / 1024.0; if (kb < 1024) return "%.0f KB".format(kb)
        val mb = kb / 1024.0; if (mb < 1024) return "%.1f MB".format(mb)
        return "%.2f GB".format(mb / 1024.0)
    }
}
