package com.handytools.app.tools.power

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.exifinterface.media.ExifInterface
import com.handytools.app.tools.gifmaker.GifEncoder
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.roundToInt

/** On-device image/video helpers behind Media Studio. Nothing here touches the network. */
internal object MediaEngine {

    enum class Kind { IMAGE, VIDEO, AUDIO }

    data class LoadedImage(val bitmap: Bitmap, val bytes: Long, val name: String, val mime: String)

    data class ExifRows(val gps: String?, val device: String?, val date: String?, val readOk: Boolean)

    data class Encoded(val bytes: ByteArray, val width: Int, val height: Int)

    // ------------------------------------------------------------------ reading

    fun sizeOf(ctx: Context, uri: Uri): Long =
        runCatching { ctx.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize.coerceAtLeast(0) } ?: 0L }.getOrDefault(0L)

    fun displayName(ctx: Context, uri: Uri): String = runCatching {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    }.getOrNull() ?: (uri.lastPathSegment ?: "file")

    fun mimeOf(ctx: Context, uri: Uri): String {
        val fromResolver = runCatching { ctx.contentResolver.getType(uri) }.getOrNull()
        if (!fromResolver.isNullOrBlank()) return fromResolver
        val n = displayName(ctx, uri).lowercase()
        return when {
            n.endsWith(".heic") || n.endsWith(".heif") -> "image/heic"
            n.endsWith(".png") -> "image/png"
            n.endsWith(".mov") -> "video/quicktime"
            n.endsWith(".mp4") -> "video/mp4"
            n.endsWith(".webm") -> "video/webm"
            n.endsWith(".gif") -> "image/gif"
            else -> "application/octet-stream"
        }
    }

    fun baseName(name: String): String = name.substringBeforeLast('.').ifBlank { "photo" }

    /** Decode a photo (HEIC included on Android 9+), honour EXIF orientation, cap the longest side. */
    fun loadImage(ctx: Context, uri: Uri, maxDim: Int = 2560): LoadedImage? {
        val bytes = sizeOf(ctx, uri)
        val name = displayName(ctx, uri)
        val mime = mimeOf(ctx, uri)
        val decoded: Bitmap? = if (Build.VERSION.SDK_INT >= 28) {
            runCatching {
                val src = ImageDecoder.createSource(ctx.contentResolver, uri)
                ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    decoder.isMutableRequired = true
                    val longest = max(info.size.width, info.size.height)
                    var sample = 1
                    while (longest / (sample * 2) >= maxDim) sample *= 2
                    if (sample > 1) decoder.setTargetSampleSize(sample)
                }
            }.getOrNull() ?: legacyDecode(ctx, uri, maxDim)
        } else legacyDecode(ctx, uri, maxDim)
        val bmp = decoded ?: return null
        val longest = max(bmp.width, bmp.height)
        val fitted = if (longest > maxDim) {
            val s = maxDim.toFloat() / longest
            Bitmap.createScaledBitmap(bmp, (bmp.width * s).roundToInt().coerceAtLeast(1), (bmp.height * s).roundToInt().coerceAtLeast(1), true)
        } else bmp
        val safe = if (fitted.config == Bitmap.Config.ARGB_8888 && fitted.isMutable) fitted else fitted.copy(Bitmap.Config.ARGB_8888, true) ?: fitted
        return LoadedImage(safe, bytes, name, mime)
    }

    private fun legacyDecode(ctx: Context, uri: Uri, maxDim: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        runCatching { ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) } }
        val longest = max(bounds.outWidth, bounds.outHeight)
        var sample = 1
        if (longest > 0) while (longest / (sample * 2) >= maxDim) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample; inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val decoded = runCatching { ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } }.getOrNull()
            ?: return null
        return applyOrientation(ctx, uri, decoded)
    }

    private fun applyOrientation(ctx: Context, uri: Uri, bmp: Bitmap): Bitmap {
        val orientation = runCatching {
            ctx.contentResolver.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } ?: ExifInterface.ORIENTATION_NORMAL
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            else -> return bmp
        }
        return runCatching { Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true) }.getOrDefault(bmp)
    }

    fun readExif(ctx: Context, uri: Uri): ExifRows = runCatching {
        ctx.contentResolver.openInputStream(uri)?.use { stream ->
            val exif = ExifInterface(stream)
            val ll = FloatArray(2)
            val gps = if (exif.getLatLong(ll)) "%.4f, %.4f".format(ll[0], ll[1]) else null
            val make = exif.getAttribute(ExifInterface.TAG_MAKE)?.trim()
            val model = exif.getAttribute(ExifInterface.TAG_MODEL)?.trim()
            val device = listOfNotNull(make, model).joinToString(" ").ifBlank { null }
            val date = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL) ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
            ExifRows(gps, device, date, true)
        } ?: ExifRows(null, null, null, false)
    }.getOrDefault(ExifRows(null, null, null, false))

    // ------------------------------------------------------------------ encoding

    fun jpeg(bmp: Bitmap, quality: Int): ByteArray {
        val flat = if (bmp.hasAlpha()) onColor(bmp, Color.WHITE) else bmp
        val bos = ByteArrayOutputStream()
        flat.compress(Bitmap.CompressFormat.JPEG, quality, bos)
        return bos.toByteArray()
    }

    fun png(bmp: Bitmap): ByteArray {
        val bos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, bos)
        return bos.toByteArray()
    }

    /** Iterative quality-then-scale loop until the JPEG fits under [limitBytes] (same loop as the prototype). */
    fun shrinkToBytes(src: Bitmap, limitBytes: Long): Encoded {
        var q = 92
        var scale = 1f
        var work = src
        var bytes = jpeg(work, q)
        var n = 0
        while (bytes.size > limitBytes && n < 14) {
            if (q > 50) q -= 8 else {
                scale *= 0.85f
                val w = (src.width * scale).roundToInt().coerceAtLeast(16)
                val h = (src.height * scale).roundToInt().coerceAtLeast(16)
                val next = Bitmap.createScaledBitmap(src, w, h, true)
                if (work != src) work.recycle()
                work = next
            }
            bytes = jpeg(work, q)
            n++
        }
        val out = Encoded(bytes, work.width, work.height)
        if (work != src) work.recycle()
        return out
    }

    /** Scale so the longest side is [px] (never upscales), encode at a sensible quality. */
    fun shrinkToPx(src: Bitmap, px: Int): Encoded {
        val longest = max(src.width, src.height)
        val scale = minOf(1f, px.toFloat() / longest)
        val w = (src.width * scale).roundToInt().coerceAtLeast(16)
        val h = (src.height * scale).roundToInt().coerceAtLeast(16)
        val scaled = if (scale < 1f) Bitmap.createScaledBitmap(src, w, h, true) else src
        val bytes = jpeg(scaled, 85)
        if (scaled != src) scaled.recycle()
        return Encoded(bytes, w, h)
    }

    // ------------------------------------------------------------------ compositing

    fun onColor(fg: Bitmap, color: Int): Bitmap {
        val out = Bitmap.createBitmap(fg.width, fg.height, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(color)
        c.drawBitmap(fg, 0f, 0f, null)
        return out
    }

    /** Subject over a softly blurred copy of the original (cheap down/upscale blur, no RenderScript). */
    fun onBlur(original: Bitmap, fg: Bitmap): Bitmap {
        val w = original.width; val h = original.height
        val tiny = Bitmap.createScaledBitmap(original, (w / 14).coerceAtLeast(4), (h / 14).coerceAtLeast(4), true)
        val mid = Bitmap.createScaledBitmap(tiny, (w / 4).coerceAtLeast(8), (h / 4).coerceAtLeast(8), true)
        val blurred = Bitmap.createScaledBitmap(mid, w, h, true)
        tiny.recycle(); mid.recycle()
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawBitmap(blurred, 0f, 0f, null)
        val dst = Rect(0, 0, w, h)
        c.drawBitmap(fg, null, dst, Paint(Paint.FILTER_BITMAP_FLAG))
        blurred.recycle()
        return out
    }

    fun redacted(src: Bitmap, boxes: List<Rect>): Bitmap {
        val copy = src.copy(Bitmap.Config.ARGB_8888, true) ?: src
        val c = Canvas(copy)
        val p = Paint().apply { color = Color.BLACK }
        boxes.forEach { c.drawRect(it, p) }
        return copy
    }

    /** Place the cut-out subject, centred, on white at the spec size with standard headroom. */
    fun composeIdPhoto(fg: Bitmap, w: Int, h: Int): Bitmap {
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(Color.WHITE)
        val b = alphaBounds(fg) ?: Rect(0, 0, fg.width, fg.height)
        val subH = b.height().coerceAtLeast(1).toFloat()
        val scale = (0.72f * h) / subH
        val subjCenterX = (b.left + b.right) / 2f
        val left = w / 2f - subjCenterX * scale
        val top = 0.12f * h - b.top * scale
        val m = Matrix().apply { postScale(scale, scale); postTranslate(left, top) }
        c.drawBitmap(fg, m, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        return out
    }

    /** Fallback when no subject can be found: crop the upper-centre of the photo to the spec ratio. */
    fun centreCrop(src: Bitmap, w: Int, h: Int): Bitmap {
        val ratio = w.toFloat() / h
        var cw = (src.width * 0.8f).roundToInt()
        var ch = (cw / ratio).roundToInt()
        if (ch > src.height) { ch = src.height; cw = (ch * ratio).roundToInt().coerceAtMost(src.width) }
        val left = (src.width - cw) / 2
        val top = ((src.height - ch) * 0.35f).roundToInt().coerceIn(0, src.height - ch)
        val crop = Bitmap.createBitmap(src, left, top, cw, ch)
        val out = Bitmap.createScaledBitmap(crop, w, h, true)
        if (out != crop) crop.recycle()
        return out
    }

    /** A 4×6 in sheet at 300 dpi (1200×1800) holding [copies] copies, with cut gaps. */
    fun printSheet(photo: Bitmap, copies: Int): Bitmap {
        val sheetW = 1200; val sheetH = 1800
        val out = Bitmap.createBitmap(sheetW, sheetH, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(Color.WHITE)
        val cols = 2
        val rows = if (copies <= 4) 2 else 3
        val gap = 24
        val cellW = (sheetW - gap * (cols + 1)) / cols
        val cellH = (sheetH - gap * (rows + 1)) / rows
        val scale = minOf(cellW.toFloat() / photo.width, cellH.toFloat() / photo.height, 1f)
        val pw = (photo.width * scale).roundToInt(); val ph = (photo.height * scale).roundToInt()
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        val line = Paint().apply { color = Color.LTGRAY; style = Paint.Style.STROKE; strokeWidth = 2f }
        var placed = 0
        for (r in 0 until rows) for (col in 0 until cols) {
            if (placed >= copies) break
            val x = gap + col * (cellW + gap) + (cellW - pw) / 2
            val y = gap + r * (cellH + gap) + (cellH - ph) / 2
            val dst = Rect(x, y, x + pw, y + ph)
            c.drawBitmap(photo, null, dst, paint)
            c.drawRect(dst, line)
            placed++
        }
        return out
    }

    private fun alphaBounds(bmp: Bitmap): Rect? {
        val w = bmp.width; val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        var minX = w; var minY = h; var maxX = -1; var maxY = -1
        for (y in 0 until h) {
            val row = y * w
            for (x in 0 until w) {
                if (((px[row + x] ushr 24) and 0xff) > 16) {
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                }
            }
        }
        return if (maxX < 0) null else Rect(minX, minY, maxX, maxY)
    }

    // ------------------------------------------------------------------ video helpers

    /** Lossless copy of the audio track into an .m4a (AAC stays AAC). Throws if the track can't be muxed. */
    fun extractAudio(ctx: Context, uri: Uri, out: File) {
        val extractor = MediaExtractor()
        extractor.setDataSource(ctx, uri, null)
        var track = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { track = i; format = f; break }
        }
        if (track < 0 || format == null) { extractor.release(); throw IllegalStateException("no audio track") }
        extractor.selectTrack(track)
        val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val outTrack = muxer.addTrack(format)
        muxer.start()
        val buffer = ByteBuffer.allocate(512 * 1024)
        val info = MediaCodec.BufferInfo()
        try {
            while (true) {
                val n = extractor.readSampleData(buffer, 0)
                if (n < 0) break
                info.offset = 0; info.size = n
                info.presentationTimeUs = extractor.sampleTime
                info.flags = extractor.sampleFlags
                muxer.writeSampleData(outTrack, buffer, info)
                if (!extractor.advance()) break
            }
        } finally {
            try { muxer.stop() } catch (_: Exception) {}
            muxer.release()
            extractor.release()
        }
    }

    /** First ~4 s of the clip sampled into a looping GIF (same recipe as GIF Maker). Returns file + first frame. */
    fun videoToGif(ctx: Context, uri: Uri, targetW: Int): Pair<File, Bitmap>? {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(ctx, uri)
            val durMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            if (durMs <= 0L) return null
            val spanMs = minOf(durMs, 4000L)
            val count = 20
            val stepMs = (spanMs / count).coerceAtLeast(60L)
            val frames = ArrayList<Bitmap>()
            var t = 0L
            var tw = 0; var th = 0
            while (t < spanMs && frames.size < count) {
                val raw = mmr.getFrameAtTime(t * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                if (raw != null) {
                    if (tw == 0) {
                        tw = (targetW / 2) * 2
                        th = (targetW.toFloat() / raw.width * raw.height).toInt().let { (it / 2) * 2 }.coerceAtLeast(2)
                    }
                    val scaled = Bitmap.createScaledBitmap(raw, tw, th, true)
                    if (scaled != raw) raw.recycle()
                    frames.add(scaled)
                }
                t += stepMs
            }
            if (frames.isEmpty()) return null
            val delayCs = (stepMs / 10).toInt().coerceIn(4, 25)
            val bytes = GifEncoder.encode(frames, delayCs)
            val first = frames.first()
            val preview = first.copy(first.config ?: Bitmap.Config.ARGB_8888, false)
            frames.forEach { it.recycle() }
            val file = File(ctx.cacheDir, "Tenzy-${System.currentTimeMillis()}.gif")
            file.writeBytes(bytes)
            return file to preview
        } catch (e: Exception) {
            return null
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }

    fun videoFrame(ctx: Context, uri: Uri): Bitmap? {
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(ctx, uri)
            mmr.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } catch (e: Exception) { null } finally { try { mmr.release() } catch (_: Exception) {} }
    }

    fun videoDims(ctx: Context, uri: Uri): String? {
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(ctx, uri)
            val w = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            if (w != null && h != null) "$w×$h" else null
        } catch (e: Exception) { null } finally { try { mmr.release() } catch (_: Exception) {} }
    }

    // ------------------------------------------------------------------ saving

    /**
     * Write bytes (or a cache file) into the public gallery: Pictures/Tenzy, Movies/Tenzy or Music/Tenzy.
     * Returns the MediaStore uri, or null when the device refused (older phones without storage permission).
     */
    fun saveToGallery(ctx: Context, name: String, mime: String, kind: Kind, bytes: ByteArray? = null, file: File? = null): Uri? {
        val cr = ctx.contentResolver
        val collection = when (kind) {
            Kind.IMAGE -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            Kind.VIDEO -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            Kind.AUDIO -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val folder = when (kind) { Kind.IMAGE -> "Pictures"; Kind.VIDEO -> "Movies"; Kind.AUDIO -> "Music" }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= 29) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/Tenzy")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            } else {
                val envDir = when (kind) {
                    Kind.IMAGE -> Environment.DIRECTORY_PICTURES
                    Kind.VIDEO -> Environment.DIRECTORY_MOVIES
                    Kind.AUDIO -> Environment.DIRECTORY_MUSIC
                }
                val dir = File(Environment.getExternalStoragePublicDirectory(envDir), "Tenzy")
                dir.mkdirs()
                @Suppress("DEPRECATION")
                put(MediaStore.MediaColumns.DATA, File(dir, name).absolutePath)
            }
        }
        val uri = runCatching { cr.insert(collection, values) }.getOrNull() ?: return null
        return try {
            cr.openOutputStream(uri)?.use { os ->
                if (bytes != null) os.write(bytes) else file?.inputStream()?.use { it.copyTo(os) } ?: throw IOException("nothing to write")
            } ?: throw IOException("no stream")
            if (Build.VERSION.SDK_INT >= 29) {
                val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                cr.update(uri, done, null, null)
            }
            uri
        } catch (e: Exception) {
            runCatching { cr.delete(uri, null, null) }
            null
        }
    }

    fun cacheFile(ctx: Context, name: String, bytes: ByteArray): File {
        val f = File(ctx.cacheDir, name)
        f.writeBytes(bytes)
        return f
    }

    fun human(bytes: Long): String {
        if (bytes <= 0) return "—"
        val kb = bytes / 1024.0
        if (kb < 1024) return "%.0f KB".format(kb)
        val mb = kb / 1024.0
        if (mb < 1024) return "%.1f MB".format(mb)
        return "%.2f GB".format(mb / 1024.0)
    }
}
