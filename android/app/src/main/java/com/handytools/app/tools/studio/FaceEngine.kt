package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * The Video Studio's face engine (27 Nov rebuild, the iPhone's FaceEngine): Google's open models run directly with
 * LiteRT — nothing leaves the phone. Faces are found (BlazeFace on the whole frame and overlapping tiles, so small
 * faces count), then a 478-point face mesh is followed from look to look and steadied (One-Euro); each look is split
 * into background, hair, body skin, face skin and clothes, so heads are found even turned away, Bald removes real hair,
 * skin effects colour only skin and the person's outline is clean. Pixels of the frame, y down.
 */
class FaceEngine private constructor(private val detector: Interpreter, private val mesh: Interpreter, private val parts: Interpreter) : AutoCloseable {
    /** A head: its skull above the brow line — brow middle, up, skull centre (on the brow line), half-width, height — and its skin colour. */
    class Skull(val bx: Float, val by: Float, val ux: Float, val uy: Float, val cx: Float, val cy: Float, val ax: Float, val ay: Float,
                val tone: FloatArray, val mesh: Int)

    /** One look: the face meshes (x, y, z per point), the 256 x 256 class shares and RGB, and the heads. */
    class Look(val w: Int, val h: Int, val meshes: List<FloatArray>, val parts: FloatArray?, val rgb: IntArray?, val heads: List<Skull>)

    private class Track(var cx: Float, var cy: Float, var size: Float, var angle: Float, val filter: OneEuro, var mesh: FloatArray)
    private class HeadTrack(val filter: OneEuro, var e: FloatArray, var misses: Int = 0)

    private val anchors: FloatArray
    private var tracks = ArrayList<Track>()
    private var headTracks = ArrayList<HeadTrack>()
    private var count = 0
    private var lastT = -10.0

    init {
        val a = ArrayList<Float>()
        for ((stride, n) in listOf(8 to 2, 16 to 6)) {
            val g = 128 / stride
            for (y in 0 until g) for (x in 0 until g) repeat(n) { a += (x + 0.5f) / g; a += (y + 0.5f) / g }
        }
        anchors = a.toFloatArray()
    }

    override fun close() { detector.close(); mesh.close(); parts.close() }

    companion object {
        const val SIDE = 256
        val JAW = intArrayOf(234, 93, 132, 58, 172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323, 454)
        val EYE_A = intArrayOf(33, 160, 158, 133, 153, 144); val EYE_B = intArrayOf(362, 385, 387, 263, 373, 380)
        val BROWS = intArrayOf(70, 63, 105, 66, 107, 336, 296, 334, 293, 300)
        val FOREHEAD = intArrayOf(151, 9, 108, 337, 69, 299)
        const val TOP = 10; const val CHIN = 152; const val NOSE_TIP = 1; const val MOUTH_UP = 13; const val MOUTH_DOWN = 14

        private fun load(ctx: Context, name: String): MappedByteBuffer {
            val fd = ctx.assets.openFd("face/$name.tflite")
            return FileInputStream(fd.fileDescriptor).channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
        }

        fun open(ctx: Context): FaceEngine? = runCatching {
            val o = { Interpreter.Options().setNumThreads(2) }
            FaceEngine(Interpreter(load(ctx, "face_detector"), o()), Interpreter(load(ctx, "face_landmarks_detector"), o()),
                Interpreter(load(ctx, "selfie_multiclass_256x256"), o()))
        }.getOrNull()

        fun iou(a: FloatArray, b: FloatArray): Float {
            val x0 = max(a[0], b[0]); val y0 = max(a[1], b[1]); val x1 = min(a[2], b[2]); val y1 = min(a[3], b[3])
            val inter = max(0f, x1 - x0) * max(0f, y1 - y0)
            return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter + 1e-6f)
        }

        fun box(m: FloatArray): FloatArray {
            var x0 = Float.MAX_VALUE; var y0 = Float.MAX_VALUE; var x1 = -Float.MAX_VALUE; var y1 = -Float.MAX_VALUE
            for (i in 0 until m.size / 3) { x0 = min(x0, m[i * 3]); y0 = min(y0, m[i * 3 + 1]); x1 = max(x1, m[i * 3]); y1 = max(y1, m[i * 3 + 1]) }
            return floatArrayOf(x0, y0, x1, y1)
        }

        /** The next look's crop from a mesh: centre, 1.5 x its turned extent, turned with its eyes. */
        fun roi(m: FloatArray): FloatArray {
            fun p(i: Int) = floatArrayOf(m[i * 3], m[i * 3 + 1])
            val r = floatArrayOf((p(33)[0] + p(133)[0]) / 2, (p(33)[1] + p(133)[1]) / 2)
            val l = floatArrayOf((p(362)[0] + p(263)[0]) / 2, (p(362)[1] + p(263)[1]) / 2)
            val angle = atan2(l[1] - r[1], l[0] - r[0])
            val n = m.size / 3
            var mx = 0f; var my = 0f
            for (i in 0 until n) { mx += m[i * 3]; my += m[i * 3 + 1] }
            mx /= n; my /= n
            val c = cos(-angle); val s = sin(-angle)
            var lx = Float.MAX_VALUE; var ly = Float.MAX_VALUE; var hx = -Float.MAX_VALUE; var hy = -Float.MAX_VALUE
            for (i in 0 until n) {
                val dx = m[i * 3] - mx; val dy = m[i * 3 + 1] - my
                val qx = c * dx - s * dy; val qy = s * dx + c * dy
                lx = min(lx, qx); ly = min(ly, qy); hx = max(hx, qx); hy = max(hy, qy)
            }
            return floatArrayOf(mx, my, max(hx - lx, hy - ly) * 1.5f, angle)
        }

        /** A face as the studio's effects take it (fractions of the frame, y down) from a mesh. */
        fun spot(m: FloatArray, w: Int, h: Int): FaceSpot {
            fun x(i: Int) = m[i * 3] / w
            fun y(i: Int) = m[i * 3 + 1] / h
            val b = box(m)
            val ea = Spot(EYE_A.map { x(it) }.average().toFloat(), EYE_A.map { y(it) }.average().toFloat())
            val eb = Spot(EYE_B.map { x(it) }.average().toFloat(), EYE_B.map { y(it) }.average().toFloat())
            val eyes = listOf(ea, eb).sortedBy { it.x }
            val roll = atan2((eyes[1].y - eyes[0].y) * h, (eyes[1].x - eyes[0].x) * w)
            val size = max(b[2] - b[0], b[3] - b[1]) / w
            val cx = (b[0] + b[2]) / 2 / w; val cy = (b[1] + b[3]) / 2 / h
            return FaceSpot(cx, cy, size, eyes, roll, Spot((x(MOUTH_UP) + x(MOUTH_DOWN)) / 2, (y(MOUTH_UP) + y(MOUTH_DOWN)) / 2), Spot(x(NOSE_TIP), y(NOSE_TIP)))
        }
    }

    // ---- one look

    /** Everything the effects need from [frame] at [t] seconds. Looks are expected in order; a jump starts afresh. */
    fun step(frame: Bitmap, t: Double, wantParts: Boolean = true): Look {
        val w = frame.width; val h = frame.height
        val fps = (if (t > lastT) 1.0 / (t - lastT) else 30.0).coerceIn(4.0, 60.0).toFloat()
        if (abs(t - lastT) > 0.6) { tracks = ArrayList(); headTracks = ArrayList(); count = 0 }
        lastT = t
        val alive = ArrayList<Track>()
        for (tr in tracks) {
            val (m, presence) = runMesh(frame, tr.cx, tr.cy, tr.size, tr.angle) ?: continue
            if (presence < 0.5f) continue
            tr.filter.fps = fps
            tr.mesh = tr.filter.filter(m)
            val r = roi(m); tr.cx = r[0]; tr.cy = r[1]; tr.size = r[2]; tr.angle = r[3]
            alive += tr
        }
        tracks = alive
        if (count % 4 == 0 || tracks.isEmpty()) {
            for (d in findFaces(frame)) {
                if (tracks.any { iou(d.box, box(it.mesh)) > 0.2f }) continue
                val cx = (d.box[0] + d.box[2]) / 2; val cy = (d.box[1] + d.box[3]) / 2
                var angle = atan2(d.eyes[3] - d.eyes[1], d.eyes[2] - d.eyes[0])
                if (abs(angle) > (PI / 2).toFloat()) angle -= if (angle > 0) PI.toFloat() else -PI.toFloat()
                val (m, presence) = runMesh(frame, cx, cy, (d.box[2] - d.box[0]) * 1.9f, angle) ?: continue
                if (presence < 0.5f) continue
                val f = OneEuro(fps)
                val first = f.filter(m)
                val r = roi(m)
                tracks += Track(r[0], r[1], r[2], r[3], f, first)
            }
        }
        count++
        val meshes = tracks.map { it.mesh }
        if (!wantParts) return Look(w, h, meshes, null, null, emptyList())
        val (p, rgb) = runParts(frame) ?: return Look(w, h, meshes, null, null, emptyList())
        return Look(w, h, meshes, p, rgb, followHeads(p, rgb, w, h, meshes, fps))
    }

    // ---- models

    /** [frame] inside the square of [size] at ([cx], [cy]) turned by [angle], as [n] x [n] RGB floats; and the frame-to-crop matrix. */
    private fun crop(frame: Bitmap, cx: Float, cy: Float, size: Float, angle: Float, n: Int, signed: Boolean): Pair<ByteBuffer, Matrix> {
        val m = Matrix()
        m.postTranslate(-cx, -cy)
        m.postRotate((-angle * 180 / PI).toFloat())
        m.postScale(n / size, n / size)
        m.postTranslate(n / 2f, n / 2f)
        val out = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(frame, m, Paint(Paint.FILTER_BITMAP_FLAG))
        val px = IntArray(n * n); out.getPixels(px, 0, n, 0, 0, n, n); out.recycle()
        val buf = ByteBuffer.allocateDirect(n * n * 3 * 4).order(ByteOrder.nativeOrder())
        for (v in px) {
            val r = (v shr 16) and 255; val g = (v shr 8) and 255; val b = v and 255
            if (signed) { buf.putFloat(r / 127.5f - 1); buf.putFloat(g / 127.5f - 1); buf.putFloat(b / 127.5f - 1) }
            else { buf.putFloat(r / 255f); buf.putFloat(g / 255f); buf.putFloat(b / 255f) }
        }
        buf.rewind()
        return buf to m
    }

    private class Detection(val score: Float, val box: FloatArray, val eyes: FloatArray)

    private fun detect(frame: Bitmap, x: Float, y: Float, w: Float, h: Float): List<Detection> {
        val s = max(w, h)
        val (input, _) = crop(frame, x + s / 2, y + s / 2, s, 0f, 128, true)
        val outs = runOutputs(detector, input) ?: return emptyList()
        val regs = outs.firstOrNull { it.size == 896 * 16 } ?: return emptyList()
        val cls = outs.firstOrNull { it.size == 896 } ?: return emptyList()
        val out = ArrayList<Detection>()
        for (i in 0 until 896) {
            val score = 1f / (1f + exp(-cls[i].coerceIn(-80f, 80f)))
            if (score < 0.55f) continue
            val ax = anchors[i * 2]; val ay = anchors[i * 2 + 1]; val r = regs.copyOfRange(i * 16, i * 16 + 16)
            val cx = ax + r[0] / 128; val cy = ay + r[1] / 128; val bw = r[2] / 128; val bh = r[3] / 128
            if (cx * s > w + 4 || cy * s > h + 4) continue
            out += Detection(score, floatArrayOf(x + (cx - bw / 2) * s, y + (cy - bh / 2) * s, x + (cx + bw / 2) * s, y + (cy + bh / 2) * s),
                floatArrayOf(x + (ax + r[4] / 128) * s, y + (ay + r[5] / 128) * s, x + (ax + r[6] / 128) * s, y + (ay + r[7] / 128) * s))
        }
        return out
    }

    /** The whole frame and 3 x 2 overlapping tiles (each seen larger), so faces a few percent of the frame are found. */
    private fun findFaces(frame: Bitmap): List<Detection> {
        val w = frame.width.toFloat(); val h = frame.height.toFloat()
        val all = ArrayList(detect(frame, 0f, 0f, w, h))
        val tw = w / 2.2f; val th = h / 1.6f
        for (ty in listOf(0f, h - th)) for (tx in listOf(0f, (w - tw) / 2, w - tw)) all += detect(frame, tx, ty, tw, th)
        val kept = ArrayList<Detection>()
        for (d in all.sortedByDescending { it.score }) if (d.box[2] - d.box[0] > 12 && kept.all { iou(it.box, d.box) < 0.3f }) kept += d
        return kept
    }

    private fun runMesh(frame: Bitmap, cx: Float, cy: Float, size: Float, angle: Float): Pair<FloatArray, Float>? {
        if (size < 8) return null
        val (input, m) = crop(frame, cx, cy, size, angle, 256, false)
        val outs = runOutputs(mesh, input) ?: return null
        // Outputs by size, not by position: the 478 x 3 points, and the face flag (the first single number).
        val pts = outs.firstOrNull { it.size >= 1434 } ?: return null
        val flag = outs.firstOrNull { it.size == 1 } ?: return null
        val inv = Matrix(); m.invert(inv)
        val k = size / 256f
        val xy = FloatArray(478 * 2)
        for (i in 0 until 478) { xy[i * 2] = pts[i * 3]; xy[i * 2 + 1] = pts[i * 3 + 1] }
        inv.mapPoints(xy)
        val out = FloatArray(478 * 3)
        for (i in 0 until 478) { out[i * 3] = xy[i * 2]; out[i * 3 + 1] = xy[i * 2 + 1]; out[i * 3 + 2] = pts[i * 3 + 2] * k }
        return out to (1f / (1f + exp(-flag[0])))
    }

    /** Every output of [it] for [input], as flat floats (each sized from the model itself), or null if it failed. */
    private fun runOutputs(it: Interpreter, input: ByteBuffer): List<FloatArray>? = runCatching {
        val n = it.outputTensorCount
        val bufs = (0 until n).map { i -> ByteBuffer.allocateDirect(it.getOutputTensor(i).numBytes()).order(ByteOrder.nativeOrder()) }
        it.runForMultipleInputsOutputs(arrayOf(input), (0 until n).associateWith { i -> bufs[i] as Any })
        bufs.map { b -> b.rewind(); val f = b.asFloatBuffer(); FloatArray(f.remaining()).also { f.get(it) } }
    }.onFailure { e -> lastError = e.toString(); android.util.Log.e("FaceEngine", "model run failed", e) }.getOrNull()

    /** The last model failure, for the tests' report. */
    var lastError: String? = null

    /** Class shares for the whole frame (stretched to 256 x 256) and its RGB at that size. */
    private fun runParts(frame: Bitmap): Pair<FloatArray, IntArray>? {
        val n = SIDE
        val small = Bitmap.createScaledBitmap(frame, n, n, true)
        val px = IntArray(n * n); small.getPixels(px, 0, n, 0, 0, n, n)
        if (small !== frame) small.recycle()
        val buf = ByteBuffer.allocateDirect(n * n * 3 * 4).order(ByteOrder.nativeOrder())
        for (v in px) { buf.putFloat(((v shr 16) and 255) / 255f); buf.putFloat(((v shr 8) and 255) / 255f); buf.putFloat((v and 255) / 255f) }
        buf.rewind()
        val out = ByteBuffer.allocateDirect(n * n * 6 * 4).order(ByteOrder.nativeOrder())
        runCatching { parts.run(buf, out) }.getOrElse { e -> lastError = e.toString(); android.util.Log.e("FaceEngine", "parts failed", e); return null }
        out.rewind()
        val fb = out.asFloatBuffer()
        val sm = FloatArray(n * n * 6)
        val e = FloatArray(6)
        for (i in 0 until n * n) {
            var mx = -Float.MAX_VALUE
            for (c in 0 until 6) { e[c] = fb.get(i * 6 + c); mx = max(mx, e[c]) }
            var sum = 0f
            for (c in 0 until 6) { e[c] = exp(e[c] - mx); sum += e[c] }
            for (c in 0 until 6) sm[i * 6 + c] = e[c] / sum
        }
        return sm to px
    }

    // ---- heads

    private fun followHeads(p: FloatArray, rgb: IntArray, w: Int, h: Int, meshes: List<FloatArray>, fps: Float): List<Skull> {
        val n = SIDE
        val on = BooleanArray(n * n) { p[it * 6 + 1] + p[it * 6 + 3] > 0.5f }
        val label = IntArray(n * n)
        val sx = w / n.toFloat(); val sy = h / n.toFloat()
        val found = ArrayList<FloatArray>()
        var next = 1
        val stack = IntArray(n * n)
        for (start in 0 until n * n) {
            if (!on[start] || label[start] != 0) continue
            var top = 0; stack[top++] = start; label[start] = next
            val px = ArrayList<Int>()
            while (top > 0) {
                val i = stack[--top]; px += i
                val x = i % n; val y = i / n
                for ((dx, dy) in arrayOf(1 to 0, -1 to 0, 0 to 1, 0 to -1)) {
                    val xx = x + dx; val yy = y + dy
                    if (xx < 0 || xx >= n || yy < 0 || yy >= n) continue
                    val j = yy * n + xx
                    if (on[j] && label[j] == 0) { label[j] = next; stack[top++] = j }
                }
            }
            next++
            if (px.size < n * n * 0.002f) continue
            var mx = 0f; var my = 0f
            for (i in px) { mx += (i % n + 0.5f) * sx; my += (i / n + 0.5f) * sy }
            mx /= px.size; my /= px.size
            var cxx = 0f; var cyy = 0f; var cxy = 0f
            for (i in px) { val dx = (i % n + 0.5f) * sx - mx; val dy = (i / n + 0.5f) * sy - my; cxx += dx * dx; cyy += dy * dy; cxy += dx * dy }
            cxx /= px.size; cyy /= px.size; cxy /= px.size
            val tr = cxx + cyy; val det = cxx * cyy - cxy * cxy
            val disc = sqrt(max(0f, tr * tr / 4 - det))
            val l1 = tr / 2 + disc; val l2 = tr / 2 - disc
            var tilt = 0.5f * atan2(2 * cxy, cxx - cyy) - (PI / 2).toFloat()
            if (tilt < -(PI / 2).toFloat()) tilt += PI.toFloat()
            if (tilt > (PI / 2).toFloat()) tilt -= PI.toFloat()
            found += floatArrayOf(mx, my, 2 * sqrt(max(l2, 1f)) * 0.93f, 2 * sqrt(max(l1, 1f)) * 0.93f, tilt)
        }
        val used = HashSet<Int>(); val keep = ArrayList<HeadTrack>()
        for (ht in headTracks) {
            val r = max(ht.e[2], ht.e[3]) * 1.5f
            val best = found.indices.filter { it !in used }.minByOrNull { hypot(found[it][0] - ht.e[0], found[it][1] - ht.e[1]) }
            if (best != null && hypot(found[best][0] - ht.e[0], found[best][1] - ht.e[1]) < r) {
                used += best; ht.misses = 0; ht.filter.fps = fps; ht.e = ht.filter.filter(found[best]); keep += ht
            } else { ht.misses++; if (ht.misses < fps * 0.4f) keep += ht }
        }
        for ((i, e) in found.withIndex()) if (i !in used) { val f = OneEuro(fps, 1.5f, 0.02f); keep += HeadTrack(f, f.filter(e)) }
        headTracks = keep
        return keep.map { ht ->
            val e = ht.e
            val mi = meshes.indexOfFirst { m -> val b = box(m); hypot((b[0] + b[2]) / 2 - e[0], (b[1] + b[3]) / 2 - e[1]) < max(e[2], e[3]) * 1.2f }
            skull(e, if (mi >= 0) meshes[mi] else null, mi, p, rgb, w, h)
        }
    }

    /** The bare skull above the brow line (from the face mesh when seen, else the head's outline), and the head's skin colour. */
    private fun skull(e: FloatArray, m: FloatArray?, mi: Int, p: FloatArray, rgb: IntArray, w: Int, h: Int): Skull {
        var ux = sin(e[4]); var uy = -cos(e[4])
        var bx = e[0] - ux * e[3] * 0.5f; var by = e[1] - uy * e[3] * 0.5f
        if (m != null) {
            bx = BROWS.map { m[it * 3] }.average().toFloat(); by = BROWS.map { m[it * 3 + 1] }.average().toFloat()
            val dx = m[TOP * 3] - m[CHIN * 3]; val dy = m[TOP * 3 + 1] - m[CHIN * 3 + 1]
            val l = max(hypot(dx, dy), 1e-3f); ux = dx / l; uy = dy / l
        }
        val sxv = -uy; val syv = ux
        val n = SIDE; val gx = w / n.toFloat(); val gy = h / n.toFloat()
        val reach = max(e[2], e[3]) * 1.6f
        val along = ArrayList<Float>(); val across = ArrayList<Float>()
        for (i in 0 until n * n) {
            if (p[i * 6 + 1] + p[i * 6 + 3] <= 0.5f) continue
            val x = (i % n + 0.5f) * gx; val y = (i / n + 0.5f) * gy
            if (hypot(x - e[0], y - e[1]) > reach) continue
            val a = (x - bx) * ux + (y - by) * uy
            if (a > 0) { along += a; across += (x - bx) * sxv + (y - by) * syv }
        }
        val tone = tone(e, m, p, rgb, w, h)
        if (along.size <= 10) return Skull(bx, by, ux, uy, bx + ux * e[3] * 0.5f, by + uy * e[3] * 0.5f, e[2], e[3] * 0.6f, tone, mi)
        fun pct(v: List<Float>, q: Float): Float { val s = v.sorted(); return s[(q * (s.size - 1)).toInt().coerceIn(0, s.size - 1)] }
        var top = pct(along, 0.99f); var lo = pct(across, 0.01f); var hi = pct(across, 0.99f)
        val thick = 0.05f * max(top, (hi - lo) / 2)
        lo += thick; hi -= thick; top -= thick
        val mid = (lo + hi) / 2
        return Skull(bx, by, ux, uy, bx + sxv * mid, by + syv * mid, max(1f, (hi - lo) / 2), max(1f, top), tone, mi)
    }

    private fun tone(e: FloatArray, m: FloatArray?, p: FloatArray, rgb: IntArray, w: Int, h: Int): FloatArray {
        val n = SIDE
        fun col(i: Int) = floatArrayOf(((rgb[i] shr 16) and 255) / 255f, ((rgb[i] shr 8) and 255) / 255f, (rgb[i] and 255) / 255f)
        fun median(v: List<FloatArray>) = FloatArray(3) { c -> v.map { it[c] }.sorted()[v.size / 2] }
        if (m != null) {
            val pts = FOREHEAD.toList().mapNotNull { k ->
                val gx = (m[k * 3] / w * n).toInt(); val gy = (m[k * 3 + 1] / h * n).toInt()
                if (gx in 0 until n && gy in 0 until n) col(gy * n + gx) else null
            }
            if (pts.size >= 3) return median(pts)
        }
        val reach = max(e[2], e[3]) * 2
        for (cls in intArrayOf(3, 2)) {
            val v = ArrayList<FloatArray>()
            for (i in 0 until n * n) {
                if (p[i * 6 + cls] <= 0.7f) continue
                val x = (i % n + 0.5f) * w / n; val y = (i / n + 0.5f) * h / n
                if (hypot(x - e[0], y - e[1]) < reach) v += col(i)
            }
            if (v.size > 8) return median(v)
        }
        return floatArrayOf(0.85f, 0.66f, 0.55f)
    }
}

/** The One-Euro filter (Casiez et al.): steady when still, quick when moving. */
class OneEuro(var fps: Float, private val minCut: Float = 1.2f, private val beta: Float = 0.04f, private val dCut: Float = 1f) {
    private var x: FloatArray? = null
    private var dx = FloatArray(0)
    private fun alpha(cut: Float) = 1f / (1f + 1f / (2f * PI.toFloat() * cut) * fps)

    fun filter(v: FloatArray): FloatArray {
        val old = x
        if (old == null || old.size != v.size) { x = v.copyOf(); dx = FloatArray(v.size); return v.copyOf() }
        val ad = alpha(dCut)
        val out = FloatArray(v.size)
        for (i in v.indices) {
            val d = (v[i] - old[i]) * fps
            dx[i] = ad * d + (1 - ad) * dx[i]
            val a = alpha(minCut + beta * abs(dx[i]))
            out[i] = a * v[i] + (1 - a) * old[i]
        }
        x = out
        return out
    }
}
