package com.handytools.app.tools.power

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import java.io.File
import java.io.FileOutputStream

/**
 * The engine behind the Scrubber: find faces and text in a photo (or a video), paint those
 * regions out, and write a clean copy with no metadata. Pure logic — no Compose — and meant to
 * run off the main thread. ML Kit face + text detection run fully on-device; nothing is uploaded.
 *
 * Why blurring text hides so much: licence plates, names, street addresses, card and account
 * numbers are all *text*, so the text pass is what actually scrubs them. The face pass covers
 * the people. The metadata strip drops EXIF (GPS, device, timestamps) simply by re-encoding the
 * pixels to a fresh JPEG/PNG — a re-encoded bitmap carries no EXIF at all.
 */
internal object ScrubberEngine {

    /** How a region gets hidden. Both are destructive — the original pixels are gone in the output. */
    enum class HideStyle(val label: String) { PIXELATE("Pixelate"), BLUR("Blur") }

    /** Everything detected (and manually added) for one image, in that image's own pixel coords. */
    data class Detection(val faces: List<Rect>, val text: List<Rect>)

    // Reuse the shared loader in this package (honours EXIF rotation, scales big images down).
    fun loadBitmap(ctx: Context, uri: Uri, maxEdge: Int = 2400): Bitmap? = DocEngine.loadBitmap(ctx, uri, maxEdge)

    private val faceOptions = FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
        .setMinFaceSize(0.06f)
        .build()

    /** Faces as padded bounding boxes in [bmp] pixel space. Never throws — returns [] on any failure. */
    suspend fun detectFaces(bmp: Bitmap): List<Rect> {
        val detector = FaceDetection.getClient(faceOptions)
        return try {
            detector.process(InputImage.fromBitmap(bmp, 0)).await()
                .mapNotNull { it.boundingBox }
                .map { pad(it, bmp, 0.10f) }
        } catch (_: Exception) {
            emptyList()
        } finally {
            try { detector.close() } catch (_: Exception) {}
        }
    }

    /** Every text block as a padded bounding box in [bmp] pixel space (plates, names, numbers…). */
    suspend fun detectText(bmp: Bitmap): List<Rect> {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            val out = ArrayList<Rect>()
            for (block in recognizer.process(InputImage.fromBitmap(bmp, 0)).await().textBlocks) {
                block.boundingBox?.let { out.add(pad(it, bmp, 0.06f)) }
            }
            out
        } catch (_: Exception) {
            emptyList()
        } finally {
            try { recognizer.close() } catch (_: Exception) {}
        }
    }

    private fun pad(r: Rect, bmp: Bitmap, frac: Float): Rect {
        val dx = (r.width() * frac).toInt()
        val dy = (r.height() * frac).toInt()
        return Rect(
            (r.left - dx).coerceAtLeast(0),
            (r.top - dy).coerceAtLeast(0),
            (r.right + dx).coerceAtMost(bmp.width),
            (r.bottom + dy).coerceAtMost(bmp.height),
        )
    }

    /**
     * Return a fresh bitmap with every rect in [rects] hidden by [style]. The source is never
     * mutated. Rects are clipped to the bitmap, so manual boxes dragged off the edge are safe.
     */
    fun scrub(src: Bitmap, rects: List<Rect>, style: HideStyle): Bitmap {
        val copy = src.copy(Bitmap.Config.ARGB_8888, true)
        if (rects.isEmpty()) return copy
        val canvas = Canvas(copy)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        for (r in rects) {
            val c = Rect(
                r.left.coerceAtLeast(0), r.top.coerceAtLeast(0),
                r.right.coerceAtMost(copy.width), r.bottom.coerceAtMost(copy.height),
            )
            if (c.width() < 2 || c.height() < 2) continue
            val region = try {
                Bitmap.createBitmap(copy, c.left, c.top, c.width(), c.height())
            } catch (_: Exception) {
                continue
            }
            val hidden = when (style) {
                HideStyle.PIXELATE -> pixelate(region)
                HideStyle.BLUR -> blur(region)
            }
            canvas.drawBitmap(hidden, null, c, paint)
        }
        return copy
    }

    /** Blocky mosaic: shrink with no filtering, blow back up with no filtering. Fully opaque. */
    private fun pixelate(region: Bitmap): Bitmap {
        val dw = (region.width / 12).coerceAtLeast(1)
        val dh = (region.height / 12).coerceAtLeast(1)
        val small = Bitmap.createScaledBitmap(region, dw, dh, false)
        return Bitmap.createScaledBitmap(small, region.width, region.height, false)
    }

    /** Soft blur: shrink hard with bilinear filtering, blow back up filtered — detail is unrecoverable. */
    private fun blur(region: Bitmap): Bitmap {
        val dw = (region.width / 14).coerceAtLeast(1)
        val dh = (region.height / 14).coerceAtLeast(1)
        val small = Bitmap.createScaledBitmap(region, dw, dh, true)
        return Bitmap.createScaledBitmap(small, region.width, region.height, true)
    }

    /** A square manual-brush box centred on a bitmap-space point, [sizePx] on a side. */
    fun brushRect(cx: Int, cy: Int, sizePx: Int): Rect {
        val half = (sizePx / 2).coerceAtLeast(6)
        return Rect(cx - half, cy - half, cx + half, cy + half)
    }

    // ---------------------------------------------------------------- output (metadata-free)

    /**
     * Write [bmp] to [out] as a fresh JPEG/PNG. Because it is a re-encode of raw pixels, the file
     * has no EXIF — no GPS, no device model, no timestamps. Returns the file, or null on failure.
     */
    fun writeBitmap(ctx: Context, bmp: Bitmap, png: Boolean): File? {
        return try {
            val f = File(ctx.cacheDir, "Scrubbed-${System.currentTimeMillis()}." + if (png) "png" else "jpg")
            FileOutputStream(f).use {
                if (png) bmp.compress(Bitmap.CompressFormat.PNG, 100, it)
                else bmp.compress(Bitmap.CompressFormat.JPEG, 92, it)
            }
            f
        } catch (_: Exception) {
            null
        }
    }

    /** Write [bmp] straight into a SAF document the user chose with CreateDocument. */
    fun writeBitmapToUri(ctx: Context, bmp: Bitmap, uri: Uri, png: Boolean): Boolean {
        return try {
            ctx.contentResolver.openOutputStream(uri)?.use {
                if (png) bmp.compress(Bitmap.CompressFormat.PNG, 100, it)
                else bmp.compress(Bitmap.CompressFormat.JPEG, 92, it)
            } ?: return false
            true
        } catch (_: Exception) {
            false
        }
    }

    // ---------------------------------------------------------------- video (best-effort)

    /** Oriented pixel size of a video (width/height swapped for 90°/270° rotation). */
    data class VideoInfo(val width: Int, val height: Int)

    fun videoInfo(ctx: Context, uri: Uri): VideoInfo? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(ctx, uri)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: return null
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: return null
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rot % 180 != 0) VideoInfo(h, w) else VideoInfo(w, h)
        } catch (_: Exception) {
            null
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    /**
     * Sample [samples] frames across the clip, run face/text detection on each, and return the
     * union of all regions in oriented-video pixel space.
     *
     * TODO(video): this is a fixed/averaged detection — the same boxes are burned over the whole
     * clip, so a subject that moves can slip out from behind a box. True per-frame tracking needs a
     * frame-by-frame decode→detect→blur→re-encode pipeline (a custom GlEffect / frame processor);
     * that is the follow-up. For now the boxes are solid redaction so whatever they cover is gone.
     */
    suspend fun detectVideoBoxes(ctx: Context, uri: Uri, faces: Boolean, text: Boolean, samples: Int = 6): List<Rect> {
        val info = videoInfo(ctx, uri) ?: return emptyList()
        val r = MediaMetadataRetriever()
        val out = ArrayList<Rect>()
        try {
            r.setDataSource(ctx, uri)
            val durMs = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val n = samples.coerceAtLeast(1)
            for (i in 0 until n) {
                val tUs = if (durMs > 0) (durMs * 1000L * i) / n else 0L
                val frame = try {
                    r.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                } catch (_: Exception) { null } ?: continue
                // Map detections on this (possibly rescaled) frame back into oriented-video coords.
                val sx = info.width.toFloat() / frame.width
                val sy = info.height.toFloat() / frame.height
                if (faces) detectFaces(frame).forEach { out.add(scaleRect(it, sx, sy)) }
                if (text) detectText(frame).forEach { out.add(scaleRect(it, sx, sy)) }
                frame.recycle()
            }
        } catch (_: Exception) {
            // fall through with whatever we gathered
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
        return out
    }

    private fun scaleRect(r: Rect, sx: Float, sy: Float) = Rect(
        (r.left * sx).toInt(), (r.top * sy).toInt(), (r.right * sx).toInt(), (r.bottom * sy).toInt(),
    )

    /**
     * A full-frame transparent overlay (at oriented video size) with solid redaction boxes painted
     * where things were detected. Fed to a Media3 OverlayEffect, which centres a native-size overlay
     * over each frame, so these boxes land exactly on the video. Returns null if there's nothing to hide.
     */
    fun overlayBitmap(width: Int, height: Int, rects: List<Rect>): Bitmap? {
        if (width <= 0 || height <= 0 || rects.isEmpty()) return null
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(17, 17, 22) }
        val radius = (minOf(width, height) * 0.015f)
        for (r in rects) {
            val left = r.left.coerceIn(0, width).toFloat()
            val top = r.top.coerceIn(0, height).toFloat()
            val right = r.right.coerceIn(0, width).toFloat()
            val bottom = r.bottom.coerceIn(0, height).toFloat()
            if (right - left < 2 || bottom - top < 2) continue
            canvas.drawRoundRect(left, top, right, bottom, radius, radius, fill)
        }
        return bmp
    }
}
