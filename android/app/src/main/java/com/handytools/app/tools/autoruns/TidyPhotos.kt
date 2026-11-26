package com.handytools.app.tools.autoruns

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.tools.spaceclean.SpaceCleanerEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext

/**
 * Tidy up screenshots, duplicates and look-alikes (the iPhone's autorun): screenshots older than a week that you won't
 * need, extra copies of the same photo or video, and look-alikes — grouped, with what's kept and why. Screenshots with
 * a code, a ticket, a booking, an order or a receipt in them always stay, and one of every set of copies is always
 * kept. Nothing goes until the person picks the groups and the phone confirms; it goes to the bin, recoverable.
 */
object TidyPhotos {
    /** A screenshot: its uri (as text, so the rules stay pure), size and when it was added. */
    data class Shot(val id: String, val bytes: Long, val added: Long) { val uri: Uri get() = Uri.parse(id) }
    data class Group(val id: String, val title: String, val remove: List<Uri>, val keep: List<Uri>, val why: String, val bytes: Long)

    /** Words that make a screenshot worth keeping (as on the iPhone: tickets, codes, bookings, receipts, confirmations). */
    val keepWords = listOf("ticket", "boarding", "booking", "reservation", "confirmation", "order", "receipt", "invoice", "total",
        "qr", "gate", "seat", "flight", "check-in", "pnr", "voucher", "coupon", "password", "wi-fi", "wifi")

    /** Screenshots older than a week, oldest first. Pure. */
    fun oldScreenshots(shots: List<Shot>, now: Long): List<Shot> = shots.filter { now - it.added >= 7L * 24 * 3600_000 }.sortedBy { it.added }

    /** Whether a screenshot's words say it's worth keeping. Pure. */
    fun worthKeeping(words: String): Boolean { val w = words.lowercase(); return keepWords.any { it in w } }

    private fun screenshots(ctx: Context): List<Shot> = runCatching {
        val out = ArrayList<Shot>()
        ctx.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.SIZE, MediaStore.Images.Media.DATE_ADDED, MediaStore.Images.Media.BUCKET_DISPLAY_NAME),
            null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (!(c.getString(3) ?: "").equals("Screenshots", true)) continue
                out += Shot(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, c.getLong(0)).toString(), c.getLong(1), c.getLong(2) * 1000)
            }
        }
        out
    }.getOrDefault(emptyList())

    fun oldScreenshotCount(ctx: Context, now: Long): Int = oldScreenshots(screenshots(ctx), now).size

    /** Everything worth tidying, grouped. [progress] runs 0…1. */
    suspend fun scan(ctx: Context, now: Long = System.currentTimeMillis(), progress: (Double) -> Unit = {}): List<Group> = withContext(Dispatchers.Default) {
        val groups = ArrayList<Group>()
        // Old screenshots: read each (on the phone) and keep any with a code or the words of a ticket, booking or receipt.
        val old = oldScreenshots(screenshots(ctx), now).take(400)
        val text = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val codes = BarcodeScanning.getClient()
        val go = ArrayList<Shot>(); val stay = ArrayList<Shot>()
        try {
            old.forEachIndexed { i, s ->
                ensureActive()
                progress(0.5 * (i + 1) / old.size)
                val b = PhotoDays.small(ctx, s.uri, 720)
                val keep = b?.let { bmp ->
                    val img = InputImage.fromBitmap(bmp, 0)
                    val hasCode = runCatching { Tasks.await(codes.process(img)).isNotEmpty() }.getOrDefault(false)
                    hasCode || worthKeeping(runCatching { Tasks.await(text.process(img)).text }.getOrDefault(""))
                } ?: true
                b?.recycle()
                if (keep) stay += s else go += s
            }
        } finally { text.close(); codes.close() }
        if (go.isNotEmpty()) groups += Group("screenshots", "%d old screenshots", go.map { it.uri }, stay.map { it.uri },
            if (stay.isEmpty()) "Older than a week." else "Older than a week. Ones with a code, ticket, booking or receipt are kept.", go.sumOf { it.bytes })
        progress(0.55)
        // Copies and look-alikes across the library (one of each set is always kept).
        val report = runCatching { SpaceCleanerEngine.scan(ctx) }.getOrNull()
        report?.exactDupes?.forEachIndexed { i, g ->
            groups += Group("copies-$i", "%d copies of the same photo", g.items.drop(1).map { it.uri }, listOf(g.items.first().uri),
                "The same to the byte — one is kept.", g.reclaim)
        }
        report?.similar?.forEachIndexed { i, g ->
            groups += Group("alike-$i", "%d look-alikes", g.items.drop(1).map { it.uri }, listOf(g.items.first().uri),
                "Almost the same picture — the newest is kept.", g.reclaim)
        }
        progress(1.0)
        groups
    }

    /** What the notification says. */
    fun notice(groups: List<Group>): String {
        val n = groups.sumOf { it.remove.size }
        return com.handytools.app.I18n.fmt("%d photos could go to the bin and free %@ — you choose.", n, HeavyVideos.human(groups.sumOf { it.bytes }))
    }
}
