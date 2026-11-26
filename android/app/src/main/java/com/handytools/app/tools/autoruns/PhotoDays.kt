package com.handytools.app.tools.autoruns

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import android.provider.MediaStore
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The day's (or week's) photos for the collage and the week's film (the iPhone's autoruns): each photo in the window
 * read on the phone — how many faces (ML Kit), how sharp, whether it's a screenshot — then picked the iPhone's way
 * (people, sharp, one per moment, little ones first, spread across the day), and laid out as one picture.
 */
object PhotoDays {
    data class Photo(val uri: Uri, val created: Long, val width: Int, val height: Int, val screenshot: Boolean)

    /** The photos added in [window], oldest first (at most [limit], the newest kept). */
    fun find(ctx: Context, window: LongRange, limit: Int = 300): List<Photo> = runCatching {
        val cols = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DATE_TAKEN, MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.WIDTH, MediaStore.Images.Media.HEIGHT, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
        val out = ArrayList<Photo>()
        ctx.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cols,
            "${MediaStore.Images.Media.DATE_ADDED} >= ? AND ${MediaStore.Images.Media.DATE_ADDED} <= ?",
            arrayOf((window.first / 1000).toString(), (window.last / 1000 + 1).toString()), "${MediaStore.Images.Media.DATE_ADDED} DESC")?.use { c ->
            while (c.moveToNext() && out.size < limit) {
                val taken = c.getLong(1).takeIf { it > 0 } ?: (c.getLong(2) * 1000)
                val name = (c.getString(5) ?: "") + " " + (c.getString(6) ?: "")
                out += Photo(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, c.getLong(0)), taken, c.getInt(3), c.getInt(4),
                    name.contains("screenshot", ignoreCase = true))
            }
        }
        out.sortedBy { it.created }
    }.getOrDefault(emptyList())

    /** A photo decoded small (its long side about [px]), upright. */
    fun small(ctx: Context, uri: Uri, px: Int = 512): Bitmap? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= px) sample *= 2
        val b = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) } ?: return null
        val deg = runCatching { ctx.contentResolver.openInputStream(uri)?.use { androidx.exifinterface.media.ExifInterface(it).rotationDegrees } ?: 0 }.getOrDefault(0)
        if (deg == 0) b else Bitmap.createBitmap(b, 0, 0, b.width, b.height, android.graphics.Matrix().apply { postRotate(deg.toFloat()) }, true).also { if (it !== b) b.recycle() }
    }.getOrNull()

    /** How sharp a picture is, 0 (blurry or flat) … 1 (crisp): the average luminance gradient on a 64×64 sampling. */
    fun sharpness(b: Bitmap): Double {
        val w = 64; val h = 64
        val s = Bitmap.createScaledBitmap(b, w, h, true)
        val px = IntArray(w * h); s.getPixels(px, 0, w, 0, 0, w, h)
        if (s !== b) s.recycle()
        val lum = DoubleArray(px.size) { i -> val c = px[i]; 0.299 * Color.red(c) + 0.587 * Color.green(c) + 0.114 * Color.blue(c) }
        var grad = 0.0
        for (y in 0 until h) for (x in 0 until w - 1) {
            val i = y * w + x
            val dx = lum[i + 1] - lum[i]; grad += dx * dx
            if (y < h - 1) { val dy = lum[i + w] - lum[i]; grad += dy * dy }
        }
        return min(1.0, grad / px.size / 170.0)
    }

    /** Each photo read on the phone, as the picker wants it. [progress] runs 0…1. */
    suspend fun read(ctx: Context, photos: List<Photo>, progress: (Double) -> Unit = {}): List<SmartRuns.Found> = withContext(Dispatchers.Default) {
        val faces = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST).setMinFaceSize(0.08f).build())
        try {
            photos.mapIndexed { i, p ->
                ensureActive()
                progress((i + 1).toDouble() / max(1, photos.size))
                val b = if (p.screenshot) null else small(ctx, p.uri)
                val n = b?.let { runCatching { Tasks.await(faces.process(InputImage.fromBitmap(it, 0))).size }.getOrDefault(0) } ?: 0
                val sharp = b?.let { sharpness(it) } ?: 0.0
                b?.recycle()
                SmartRuns.Found(p.uri.toString(), p.created, isScreenshot = p.screenshot, width = p.width, height = p.height,
                    seen = SmartRuns.PhotoSeen(emptyList(), "", n, sharp))
            }
        } finally { faces.close() }
    }

    /**
     * Rows for a collage: photos (by their aspect ratios, w/h) packed into justified rows [width] wide with [gap]
     * between, each row about [rowHeight] tall. Pure, so it's tested: every photo placed once, in order, rows full width.
     */
    data class Box(val left: Int, val top: Int, val right: Int, val bottom: Int) { val width get() = right - left; val height get() = bottom - top }

    fun layout(aspects: List<Double>, width: Int = 1080, gap: Int = 8, rowHeight: Int = 420): List<Box> {
        val out = ArrayList<Box>()
        var y = gap; var i = 0
        while (i < aspects.size) {
            var j = i; var sum = 0.0
            while (j < aspects.size) {
                sum += aspects[j].coerceIn(0.3, 3.5); j++
                if (sum * rowHeight + gap * (j - i + 1) >= width) break
            }
            val n = j - i
            val avail = width - gap * (n + 1)
            val full = j < aspects.size || sum * rowHeight + gap * (n + 1) >= width
            val h = if (full) (avail / sum).roundToInt() else rowHeight
            var x = gap
            for (k in i until j) {
                val w = if (full && k == j - 1) width - gap - x else (aspects[k].coerceIn(0.3, 3.5) * h).roundToInt()
                out += Box(x, y, x + w, y + h); x += w + gap
            }
            y += h + gap; i = j
        }
        return out
    }

    /** The day's collage: [uris] laid out in justified rows on a white page, as a JPEG in the cache. */
    suspend fun collage(ctx: Context, uris: List<Uri>): File? = withContext(Dispatchers.Default) {
        val pics = uris.mapNotNull { small(ctx, it, 900) }
        if (pics.isEmpty()) return@withContext null
        val rects = layout(pics.map { it.width.toDouble() / max(1, it.height) })
        val height = (rects.maxOf { it.bottom } + 8).coerceAtMost(8000)
        val page = Bitmap.createBitmap(1080, height, Bitmap.Config.ARGB_8888)
        val c = Canvas(page); c.drawColor(Color.WHITE)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        pics.zip(rects).forEach { (b, r) ->
            // Fill the tile, cropping the middle of the photo to its shape.
            val k = max(r.width.toFloat() / b.width, r.height.toFloat() / b.height)
            val sw = (r.width / k).roundToInt(); val sh = (r.height / k).roundToInt()
            val sx = (b.width - sw) / 2; val sy = (b.height - sh) / 2
            c.drawBitmap(b, Rect(sx, sy, sx + sw, sy + sh), Rect(r.left, r.top, r.right, r.bottom), paint)
            b.recycle()
        }
        val f = File(File(ctx.cacheDir, "autoruns").also { it.mkdirs() }, "collage-${System.nanoTime()}.jpg")
        f.outputStream().use { page.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        page.recycle()
        f
    }
}
