package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** A point as fractions of the frame (y down). */
data class Spot(val x: Float, val y: Float)

/** One face in a frame, as fractions of the frame (y down): its centre, its size (its longer side over the frame's width), its eyes. */
data class FaceSpot(val x: Float, val y: Float, val size: Float, val eyes: List<Spot> = emptyList())

/**
 * Where the people are in a video, found once on the phone before it's made (the iPhone finds them frame by frame
 * with Vision): a few times a second, the person mask (ML Kit selfie segmentation, bytes 0…255, row 0 at the top) and
 * the faces with their eyes (ML Kit face detection). Nothing leaves the phone. Between two looks the masks are mixed
 * and the faces glide, so the effect follows the person smoothly.
 */
class People(val step: Double, val maskW: Int, val maskH: Int, val masks: List<ByteArray>, val faces: List<List<FaceSpot>>) {
    /** The two looks around [t] and how far between them it is (0…1). */
    fun around(t: Double): Triple<Int, Int, Float> = Companion.around(t, step, max(masks.size, faces.size))

    fun facesAt(t: Double): List<FaceSpot> {
        if (faces.isEmpty()) return emptyList()
        val (a, b, f) = around(t)
        return glide(faces[a], faces[b], f)
    }

    companion object {
        /** How often to look: 8 times a second, fewer for long videos so a minute is at most 240 looks. */
        fun stepFor(seconds: Double): Double = max(1.0 / 8, seconds / 240)

        fun around(t: Double, step: Double, count: Int): Triple<Int, Int, Float> {
            if (count <= 1) return Triple(0, 0, 0f)
            val x = (t / step).coerceIn(0.0, (count - 1).toDouble())
            val a = x.toInt().coerceAtMost(count - 1)
            val b = min(count - 1, a + 1)
            return Triple(a, b, (x - a).toFloat())
        }

        /** Each face of [a] moved [f] of the way to the nearest face of [b] (a face that's gone stays where it was). */
        fun glide(a: List<FaceSpot>, b: List<FaceSpot>, f: Float): List<FaceSpot> {
            if (a.isEmpty()) return if (f >= 0.5f) b else emptyList()
            return a.map { fa ->
                val fb = b.minByOrNull { (it.x - fa.x) * (it.x - fa.x) + (it.y - fa.y) * (it.y - fa.y) }
                    ?.takeIf { abs(it.x - fa.x) < 0.25f && abs(it.y - fa.y) < 0.25f } ?: return@map fa
                fun l(p: Float, q: Float) = p + (q - p) * f
                val eyes = if (fa.eyes.size == fb.eyes.size) fa.eyes.zip(fb.eyes) { p, q -> Spot(l(p.x, q.x), l(p.y, q.y)) } else fa.eyes
                FaceSpot(l(fa.x, fb.x), l(fa.y, fb.y), l(fa.size, fb.size), eyes)
            }
        }

        /** A look that found no face keeps the last faces found up to [hold] seconds before (a turned head, a blink of the finder). */
        fun fillGaps(found: List<List<FaceSpot>>, step: Double, hold: Double = 0.6): List<List<FaceSpot>> {
            var last: List<FaceSpot> = emptyList(); var lastAt = -1
            return found.mapIndexed { i, fs ->
                if (fs.isNotEmpty()) { last = fs; lastAt = i; fs }
                else if (lastAt >= 0 && (i - lastAt) * step <= hold + 1e-9) last else emptyList()
            }
        }

        /**
         * Looks through the first [seconds] of [uri] for people: masks when [masks], faces when [faces]. [progress]
         * runs 0…1. nil if the video can't be read.
         */
        suspend fun find(ctx: Context, uri: Uri, seconds: Double, masks: Boolean, faces: Boolean, progress: (Double) -> Unit = {}): People? =
            withContext(Dispatchers.Default) {
                val step = stepFor(seconds)
                val count = max(1, (seconds / step).toInt() + 1)
                val r = MediaMetadataRetriever()
                try { r.setDataSource(ctx, uri) } catch (e: Exception) { r.release(); return@withContext null }
                val segmenter = if (masks) Segmentation.getClient(SelfieSegmenterOptions.Builder()
                    .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE).enableRawSizeMask().build()) else null
                val finder = if (faces) FaceDetection.getClient(FaceDetectorOptions.Builder()
                    .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                    .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).setMinFaceSize(0.08f).build()) else null
                // Frames in order are decoded cheaply by index (Android 9+); by time otherwise.
                val frameCount = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)?.toIntOrNull() ?: 0
                val total = (r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) / 1000.0
                val fps = if (frameCount > 0 && total > 0) frameCount / total else 0.0
                val outMasks = ArrayList<ByteArray?>(); val outFaces = ArrayList<List<FaceSpot>>()
                var mw = 1; var mh = 1
                try {
                    for (i in 0 until count) {
                        ensureActive()
                        val t = i * step
                        val frame = frameAt(r, t, fps, frameCount) ?: break
                        val k = min(1.0, 480.0 / max(frame.width, frame.height))
                        val small = if (k < 1) Bitmap.createScaledBitmap(frame, max(1, (frame.width * k).roundToInt()), max(1, (frame.height * k).roundToInt()), true) else frame
                        if (small !== frame) frame.recycle()
                        val image = InputImage.fromBitmap(small, 0)
                        if (segmenter != null) {
                            val m = runCatching { Tasks.await(segmenter.process(image)) }.getOrNull()
                            if (m != null) {
                                mw = m.width; mh = m.height
                                val fb = m.buffer.also { it.rewind() }.asFloatBuffer()
                                outMasks.add(ByteArray(mw * mh) { j -> (fb.get(j).coerceIn(0f, 1f) * 255f).roundToInt().toByte() })
                            } else outMasks.add(null)
                        }
                        if (finder != null) {
                            val found = runCatching { Tasks.await(finder.process(image)) }.getOrNull().orEmpty()
                            val w = small.width.toFloat(); val h = small.height.toFloat()
                            outFaces.add(found.map { f ->
                                val b = f.boundingBox
                                val eyes = listOf(FaceLandmark.LEFT_EYE, FaceLandmark.RIGHT_EYE).mapNotNull { f.getLandmark(it)?.position }.map { Spot(it.x / w, it.y / h) }
                                FaceSpot(b.exactCenterX() / w, b.exactCenterY() / h, max(b.width(), b.height()) / w, eyes)
                            }.sortedByDescending { it.size }.take(2))
                        }
                        small.recycle()
                        progress((i + 1).toDouble() / count)
                    }
                } finally {
                    r.release(); segmenter?.close(); finder?.close()
                }
                // A look the person finder missed borrows the nearest one it didn't (all of them the same size).
                val firstMask = outMasks.firstOrNull { it != null }
                var held = firstMask
                val masksOut = if (firstMask == null) emptyList() else outMasks.map { m -> (m ?: held)!!.also { held = it } }
                if (masksOut.isEmpty() && outFaces.isEmpty()) return@withContext null
                People(step, mw, mh, masksOut, fillGaps(outFaces, step))
            }

        private fun frameAt(r: MediaMetadataRetriever, t: Double, fps: Double, frameCount: Int): Bitmap? {
            if (Build.VERSION.SDK_INT >= 28 && fps > 0) {
                val index = (t * fps).roundToInt()
                if (index < frameCount) runCatching { r.getFrameAtIndex(index) }.getOrNull()?.let { return it }
            }
            return runCatching { r.getFrameAtTime((t * 1e6).toLong(), MediaMetadataRetriever.OPTION_CLOSEST) }.getOrNull()
        }

        /** How much of a frame the mask calls person (0…1): for tests and the report. */
        fun share(mask: ByteArray): Double = if (mask.isEmpty()) 0.0 else mask.count { (it.toInt() and 0xFF) > 128 }.toDouble() / mask.size

        /** A mask's value at a point given as fractions of the frame (y down). */
        fun valueAt(mask: ByteArray, w: Int, h: Int, x: Float, y: Float): Int {
            val i = (y * (h - 1)).roundToInt().coerceIn(0, h - 1) * w + (x * (w - 1)).roundToInt().coerceIn(0, w - 1)
            return mask[i].toInt() and 0xFF
        }

        /** Distance between two faces' centres, as a fraction of the frame. */
        fun apart(a: FaceSpot, b: FaceSpot): Float = sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}
