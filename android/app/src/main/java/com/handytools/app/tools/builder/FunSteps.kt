package com.handytools.app.tools.builder

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import com.handytools.app.HandyApp
import com.handytools.app.tools.gifmaker.GifEncoder
import com.handytools.app.tools.power.MediaEngine
import com.handytools.app.tools.power.ScrubberEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * The playful steps of Build your own: a sticker, emojis over faces, meme text, an emoji mosaic, a boomerang GIF and
 * a video played slower or faster. Everything is drawn on the phone.
 */
object FunSteps {
    /**
     * Null when [step] is not one of these steps.
     * @param dryRun true while the builder previews a tool, so a meme with no words yet shows where they will go.
     */
    suspend fun apply(step: Step, input: Payload, dryRun: Boolean = false): Outcome? {
        val b = step.block
        val ctx: Context = HandyApp.instance
        fun stop(why: String): Outcome = Outcome.Stopped(why)
        fun fail(): Outcome = Outcome.Stopped("${b.title} couldn't finish. Try again.")
        return when {
            b == Block.STICKER && input is Payload.Pic -> {
                // Google's on-device cut-out. Its model is a one-time download; without it the step says so plainly.
                val seg = SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                try {
                    val cut = seg.process(InputImage.fromBitmap(input.bmp, 0)).await().foregroundBitmap
                    val made = cut?.let { sticker(it) }
                    // Saved as a PNG so the see-through background survives being shared.
                    if (made == null) stop("Make a sticker couldn't find a person, pet or object to cut out. Try a photo where it stands clear of the background.")
                    else Outcome.Done(Payload.Doc(MediaEngine.png(made), "png"))
                } catch (_: Throwable) {
                    stop("Make a sticker needs a one-time download that isn't on this phone yet. Open Media Studio, remove a background once while online, then run this again.")
                } finally { runCatching { seg.close() } }
            }

            b == Block.EMOJI_FACES && input is Payload.Pic -> {
                val faces = ScrubberEngine.detectFaces(input.bmp)
                if (faces.isEmpty()) stop("Emoji over faces didn't find a face in that photo. Try one where the face is clear and turned to the camera.")
                else Outcome.Done(Payload.Pic(emojiOver(input.bmp, faces, TextTidy.faceEmoji(step.settings["emoji"]))))
            }

            b == Block.MEME && input is Payload.Pic -> {
                var top = TextTidy.memeText(step.settings["top"].orEmpty()); var bottom = TextTidy.memeText(step.settings["bottom"].orEmpty())
                if (dryRun && top.isEmpty() && bottom.isEmpty()) { top = "TOP LINE"; bottom = "BOTTOM LINE" }
                if (top.isEmpty() && bottom.isEmpty()) stop("Add meme text needs some words. Type a top or a bottom line, then run it again.")
                else Outcome.Done(Payload.Pic(meme(input.bmp, top, bottom)))
            }

            b == Block.EMOJI_MOSAIC && input is Payload.Pic -> mosaic(input.bmp)?.let { Outcome.Done(Payload.Pic(it)) } ?: fail()

            b == Block.VIDEO_SPEED && input is Payload.Clip ->
                VideoSteps.speed(ctx, input.uri, TextTidy.speedRate(step.settings["speed"]))?.let { Outcome.Done(Payload.Clip(Uri.fromFile(it))) } ?: fail()

            b == Block.VIDEO_LOOP && input is Payload.Clip ->
                withContext(Dispatchers.IO) { loopGif(ctx, input.uri, step.settings["style"]) }?.let { Outcome.Done(Payload.Doc(it, "gif")) } ?: fail()

            else -> null
        }
    }

    // ------------------------------------------------------------------ sticker

    /** A cut-out with the empty space trimmed away and a white edge drawn round it, like a printed sticker. Null when the cut-out holds nothing. */
    fun sticker(cut: Bitmap, side: Int = 1024): Bitmap? {
        val box = solidBounds(cut) ?: return null
        val piece = Bitmap.createBitmap(cut, box.left, box.top, box.width(), box.height())
        val fit = minOf(2f, side * 0.9f / maxOf(box.width(), box.height()))
        val w = maxOf(1, Math.round(box.width() * fit)); val h = maxOf(1, Math.round(box.height() * fit))
        val subject = if (w != piece.width || h != piece.height) Bitmap.createScaledBitmap(piece, w, h, true) else piece
        val edge = maxOf(6f, maxOf(w, h) * 0.022f)
        val pad = Math.round(edge * 2)
        val out = Bitmap.createBitmap(w + pad * 2, h + pad * 2, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        // The same shape, all white: stamped in a ring it becomes the sticker's edge.
        val shape = subject.extractAlpha()
        val white = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { color = Color.WHITE }
        for (i in 0 until 24) {
            val a = i / 24.0 * 2 * Math.PI
            c.drawBitmap(shape, pad + (Math.cos(a) * edge).toFloat(), pad + (Math.sin(a) * edge).toFloat(), white)
        }
        c.drawBitmap(subject, pad.toFloat(), pad.toFloat(), Paint(Paint.FILTER_BITMAP_FLAG))
        return out
    }

    /** The smallest box holding every pixel that isn't see-through. Null when all of it is. */
    fun solidBounds(bmp: Bitmap): Rect? {
        val k = minOf(1f, 256f / maxOf(bmp.width, bmp.height, 1))
        val w = maxOf(1, (bmp.width * k).toInt()); val h = maxOf(1, (bmp.height * k).toInt())
        val small = if (w != bmp.width || h != bmp.height) Bitmap.createScaledBitmap(bmp, w, h, true) else bmp
        val px = IntArray(w * h); small.getPixels(px, 0, w, 0, 0, w, h)
        var minX = w; var minY = h; var maxX = -1; var maxY = -1
        for (y in 0 until h) for (x in 0 until w) if ((px[y * w + x] ushr 24) > 24) {
            if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y
        }
        if (maxX < minX || maxY < minY) return null
        val left = (((minX - 1) / k).toInt()).coerceIn(0, bmp.width - 1); val top = (((minY - 1) / k).toInt()).coerceIn(0, bmp.height - 1)
        val right = (Math.ceil(((maxX + 2) / k).toDouble()).toInt()).coerceIn(left + 1, bmp.width); val bottom = (Math.ceil(((maxY + 2) / k).toDouble()).toInt()).coerceIn(top + 1, bmp.height)
        return Rect(left, top, right, bottom)
    }

    // ------------------------------------------------------------------ emoji over faces

    /** The emoji drawn over each face, a little bigger than the face so none of it shows round the edge. */
    fun emojiOver(src: Bitmap, faces: List<Rect>, emoji: String): Bitmap {
        val out = src.copy(Bitmap.Config.ARGB_8888, true)
        val c = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (f in faces) {
            paint.textSize = maxOf(f.width(), f.height()) * 1.05f
            val m = paint.fontMetrics
            c.drawText(emoji, f.exactCenterX() - paint.measureText(emoji) / 2f, f.exactCenterY() - (m.ascent + m.descent) / 2f, paint)
        }
        return out
    }

    // ------------------------------------------------------------------ meme text

    /** Big white capitals with a black edge, across the top and the bottom. The words shrink until each block fits. */
    fun meme(src: Bitmap, top: String, bottom: String): Bitmap {
        val out = src.copy(Bitmap.Config.ARGB_8888, true)
        val c = Canvas(out)
        val width = (out.width * 0.94f).toInt().coerceAtLeast(1); val room = out.height * 0.3f; val gap = out.height * 0.025f
        val face = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        for ((words, atTop) in listOf(top to true, bottom to false)) {
            if (words.isEmpty()) continue
            var size = maxOf(16f, minOf(out.width, out.height) / 7f)
            fun layout(stroke: Boolean): StaticLayout {
                val p = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    typeface = face; textSize = size; color = if (stroke) Color.BLACK else Color.WHITE
                    if (stroke) { style = Paint.Style.STROKE; strokeWidth = size * 0.12f; strokeJoin = Paint.Join.ROUND }
                }
                return StaticLayout.Builder.obtain(words, 0, words.length, p, width).setAlignment(Layout.Alignment.ALIGN_CENTER).build()
            }
            var edge = layout(true)
            while (edge.height > room && size > 12f) { size *= 0.9f; edge = layout(true) }
            val fill = layout(false)
            c.save()
            c.translate((out.width - width) / 2f, if (atTop) gap else out.height - edge.height - gap)
            edge.draw(c); fill.draw(c)
            c.restore()
        }
        return out
    }

    // ------------------------------------------------------------------ emoji mosaic

    /** One emoji drawn at [side] pixels on a see-through square. */
    private fun tile(emoji: String, side: Int): Bitmap {
        val b = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = side * 0.78f }
        val m = p.fontMetrics
        Canvas(b).drawText(emoji, side / 2f - p.measureText(emoji) / 2f, side / 2f - (m.ascent + m.descent) / 2f, p)
        return b
    }

    /** What colour each mosaic emoji is on the whole, on white, measured once from how this phone draws it. */
    private val palette: List<IntArray> by lazy {
        TextTidy.MOSAIC_EMOJIS.map { e ->
            val t = tile(e, 24)
            val px = IntArray(24 * 24); t.getPixels(px, 0, 24, 0, 0, 24, 24)
            var r = 0L; var g = 0L; var b = 0L
            for (v in px) {
                val a = v ushr 24
                r += ((v shr 16 and 0xFF) * a + 255 * (255 - a)) / 255; g += ((v shr 8 and 0xFF) * a + 255 * (255 - a)) / 255; b += ((v and 0xFF) * a + 255 * (255 - a)) / 255
            }
            intArrayOf((r / px.size).toInt(), (g / px.size).toInt(), (b / px.size).toInt())
        }
    }

    /**
     * The photo rebuilt from emojis: each small square of it becomes the emoji closest to its colour, on a square of
     * that colour, so from a step back it still reads as the photo.
     */
    fun mosaic(src: Bitmap, cell: Int = 28): Bitmap? {
        val (cols, rows) = TextTidy.mosaicGrid(src.width.toDouble(), src.height.toDouble())
        if (cols <= 0 || rows <= 0) return null
        val small = Bitmap.createScaledBitmap(src, cols, rows, true)
        val px = IntArray(cols * rows); small.getPixels(px, 0, cols, 0, 0, cols, rows)
        val out = Bitmap.createBitmap(cols * cell, rows * cell, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val ground = Paint()
        val tiles = HashMap<Int, Bitmap>()
        for (i in px.indices) {
            val v = px[i]; val r = v shr 16 and 0xFF; val g = v shr 8 and 0xFF; val b = v and 0xFF
            val x = (i % cols) * cell; val y = (i / cols) * cell
            ground.color = Color.rgb(r, g, b)
            c.drawRect(x.toFloat(), y.toFloat(), (x + cell).toFloat(), (y + cell).toFloat(), ground)
            val pick = TextTidy.nearestColor(r, g, b, palette)
            if (pick >= 0) c.drawBitmap(tiles.getOrPut(pick) { tile(TextTidy.MOSAIC_EMOJIS[pick], cell) }, x.toFloat(), y.toFloat(), null)
        }
        return out
    }

    // ------------------------------------------------------------------ GIFs

    /** The first two and a half seconds of a video as a GIF that plays forwards then back (or just backwards), for ever. */
    fun loopGif(ctx: Context, uri: Uri, style: String?, width: Int = 360): ByteArray? {
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(ctx, uri)
            val length = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            if (length <= 0L) return null
            val span = minOf(length, 2500L)
            val count = 20
            val frames = ArrayList<Bitmap>()
            var tw = 0; var th = 0
            for (i in 0 until count) {
                // The exact moment, not the nearest key frame: a couple of seconds may hold only two or three of those.
                val raw = mmr.getFrameAtTime(span * i / count * 1000, MediaMetadataRetriever.OPTION_CLOSEST) ?: continue
                if (tw == 0) { tw = (width / 2) * 2; th = ((width.toFloat() / raw.width * raw.height).toInt() / 2 * 2).coerceAtLeast(2) }
                val scaled = Bitmap.createScaledBitmap(raw, tw, th, true)
                if (scaled != raw) raw.recycle()
                frames.add(scaled)
            }
            if (frames.isEmpty()) return null
            val played = TextTidy.loopOrder(frames.size, style).map { frames[it] }
            val bytes = GifEncoder.encode(played, ((span / count) / 10).toInt().coerceIn(4, 25))
            frames.forEach { it.recycle() }
            bytes
        } catch (_: Throwable) { null } finally { runCatching { mmr.release() } }
    }

    /** Several pictures played one after another as a GIF, for ever. Every picture fills the shape of the first one. */
    fun photosGif(pictures: List<Bitmap>, long: Int = 480, holdCs: Int = 60): ByteArray? {
        val first = pictures.firstOrNull() ?: return null
        val k = long.toFloat() / maxOf(first.width, first.height)
        val w = maxOf(2, Math.round(first.width * k)); val h = maxOf(2, Math.round(first.height * k))
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        val frames = pictures.map { bmp ->
            val f = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val s = maxOf(w.toFloat() / bmp.width, h.toFloat() / bmp.height)
            val bw = bmp.width * s; val bh = bmp.height * s
            Canvas(f).apply { drawColor(Color.WHITE); drawBitmap(bmp, null, RectF((w - bw) / 2f, (h - bh) / 2f, (w + bw) / 2f, (h + bh) / 2f), paint) }
            f
        }
        return try { GifEncoder.encode(frames, holdCs) } catch (_: Throwable) { null } finally { frames.forEach { it.recycle() } }
    }
}
