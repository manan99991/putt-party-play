package com.handytools.app.tools.spaceclean

import android.content.ContentUris
import android.content.Context
import android.content.IntentSender
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import java.security.MessageDigest
import java.util.concurrent.Callable
import java.util.concurrent.Executors

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
    /** Run [f] over [items] on all cores (the work is I/O + image decode, so this is ~N× faster). */
    private fun <T, R> parallelMap(items: List<T>, f: (T) -> R): List<R> {
        if (items.size < 8) return items.map(f)
        val pool = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors().coerceIn(2, 6))
        return try { pool.invokeAll(items.map { x -> Callable { f(x) } }).map { it.get() } } finally { pool.shutdown() }
    }

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
        val candidates = images.groupBy { it.size }.values.filter { it.size > 1 }
        val hashedBySize = parallelMap(candidates.flatten()) { m -> m to contentHash(ctx, m.uri) }.toMap()
        candidates.forEach { sameSize ->
            val byHash = hashMapOf<String, MutableList<MediaItem>>()
            sameSize.forEach { m -> hashedBySize[m]?.let { h -> byHash.getOrPut(h) { mutableListOf() }.add(m) } }
            byHash.values.filter { it.size > 1 }.forEach { g ->
                exact.add(CleanGroup("${g.size} identical copies", g, g.drop(1).sumOf { it.size }))
            }
        }
        val exactUris = exact.flatMap { it.items }.map { it.uri }.toHashSet()

        // Look-alikes via difference-hash (dHash), excluding exact dupes already found. Three guards
        // kill the false positives that made unrelated photos cluster together:
        //  • skip the Screenshots bucket — flat UI shots have low-detail hashes that collide, and they
        //    already have their own pile below;
        //  • skip near-uniform hashes (mostly one tone) that would match almost anything;
        //  • require a matching aspect ratio AND a tight hamming distance (≤ 4 of 64 bits).
        val similar = mutableListOf<CleanGroup>()
        val toHash = images.filter { it.uri !in exactUris && !it.bucket.equals("Screenshots", true) }
            .take(SIMILAR_CAP)
        // Require real information content: mostly-dark or mostly-bright shots (an almost all-0 or
        // all-1 dHash) match nearly anything, which grouped unrelated dark photos/UI as "look-alikes".
        val hashed = parallelMap(toHash) { m -> dHash(ctx, m.uri)?.let { fp -> if (fp.detail in 20..44) fp to m else null } }
            .filterNotNull()
        val used = hashSetOf<Uri>()
        for (i in hashed.indices) {
            val (f1, m1) = hashed[i]
            if (m1.uri in used) continue
            val cluster = mutableListOf(m1)
            for (j in i + 1 until hashed.size) {
                val (f2, m2) = hashed[j]
                if (m2.uri in used) continue
                val sameShape = kotlin.math.abs(f1.aspect - f2.aspect) <= 0.08f * maxOf(f1.aspect, f2.aspect)
                // Two genuine look-alikes have comparable complexity AND a very tight hash distance.
                // Tightened from ≤4 to ≤3 and added the complexity guard to stop false matches.
                val sameComplexity = kotlin.math.abs(f1.detail - f2.detail) <= 6
                if (sameShape && sameComplexity && hamming(f1.hash, f2.hash) <= 3) { cluster.add(m2); used.add(m2.uri) }
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
            val buf = ByteArray(1 shl 16); var n = 0; var read = 0L
            while (read < (1L shl 20) && ins.read(buf).also { n = it } > 0) { md.update(buf, 0, n); read += n }
            md.digest().joinToString("") { "%02x".format(it) }
        }
    }.getOrNull()

    /** A perceptual fingerprint: the dHash bits, the source aspect ratio, and how many bits are set
     *  (its "detail" — a near-uniform image sets very few/many bits and is unreliable to match on). */
    private data class Fingerprint(val hash: Long, val aspect: Float, val detail: Int)

    private fun dHash(ctx: Context, uri: Uri): Fingerprint? = runCatching {
        val bmp = thumb(ctx, uri) ?: return null
        val aspect = bmp.width.toFloat() / bmp.height.coerceAtLeast(1)
        val small = Bitmap.createScaledBitmap(bmp, 9, 8, true)
        var hash = 0L; var bit = 0
        for (y in 0 until 8) for (x in 0 until 8) {
            if (gray(small.getPixel(x, y)) > gray(small.getPixel(x + 1, y))) hash = hash or (1L shl bit)
            bit++
        }
        bmp.recycle(); small.recycle()
        Fingerprint(hash, aspect, java.lang.Long.bitCount(hash))
    }.getOrNull()

    /** A small bitmap for fingerprinting. Uses the system's cached thumbnail where available (fast),
     *  otherwise a bounds-first decode sampled down to ~64 px so we never decode a full 12 MP photo. */
    private fun thumb(ctx: Context, uri: Uri): Bitmap? {
        if (Build.VERSION.SDK_INT >= 29) {
            runCatching { return ctx.contentResolver.loadThumbnail(uri, Size(96, 96), null) }
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= 64 && bounds.outHeight / (sample * 2) >= 64) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    private fun gray(p: Int): Int {
        val r = (p shr 16) and 0xff; val g = (p shr 8) and 0xff; val b = p and 0xff
        return (r * 299 + g * 587 + b * 114) / 1000
    }

    private fun hamming(a: Long, b: Long): Int = java.lang.Long.bitCount(a xor b)

    /** Move to the system Trash — RECOVERABLE for ~30 days (not a hard delete). User confirms.
     *  Directly answers the #1 user fear with these tools: accidental/false-positive deletion. */
    fun trashRequest(ctx: Context, uris: List<Uri>): IntentSender? {
        if (uris.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return MediaStore.createTrashRequest(ctx.contentResolver, uris, true).intentSender
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
