package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.graphics.Canvas
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Stitches scrolling screenshots into one tall image. Consecutive shots usually share an overlapping
 * band (the part of the screen that didn't move between captures); this finds that band by matching
 * row signatures and removes the duplication, so the result reads as one continuous page. If it can't
 * find a confident overlap for a pair it simply stacks them — never fails.
 */
object StitchEngine {

    /** 16 evenly-spaced columns, each row summed to a single luminance signature. */
    private fun rowSignatures(bmp: Bitmap): IntArray {
        val w = bmp.width; val h = bmp.height
        val cols = IntArray(16) { ((it + 1) * w) / 17 }
        val sig = IntArray(h)
        val px = IntArray(w)
        for (y in 0 until h) {
            bmp.getPixels(px, 0, w, 0, y, w, 1)
            var s = 0
            for (c in cols) { val p = px[c]; s += ((p shr 16) and 0xFF) + ((p shr 8) and 0xFF) + (p and 0xFF) }
            sig[y] = s
        }
        return sig
    }

    /** Rows of B that duplicate the bottom of A (0 = no confident overlap). */
    private fun overlap(sigA: IntArray, sigB: IntArray): Int {
        val hA = sigA.size; val hB = sigB.size
        val limit = min(hA, hB)
        if (limit < 20) return 0
        val minH = max(10, (limit * 0.05).toInt())
        val maxH = (limit * 0.85).toInt()
        var best = 0; var bestScore = Double.MAX_VALUE
        var h = minH
        while (h <= maxH) {
            var diff = 0L; var cnt = 0
            val step = max(1, h / 200)
            var k = 0
            while (k < h) { diff += abs(sigA[hA - h + k] - sigB[k]).toLong(); cnt++; k += step }
            val score = diff.toDouble() / cnt
            if (score < bestScore) { bestScore = score; best = h }
            h += 2
        }
        // Accept only a genuinely close match, relative to the image's own row variation.
        var mag = 0L; for (v in sigB) mag += v
        val avg = (mag.toDouble() / hB).coerceAtLeast(1.0)
        return if (bestScore < avg * 0.06) best else 0
    }

    /** Stitch [bitmaps] top-to-bottom, removing detected overlaps. Null on failure. */
    fun stitch(bitmaps: List<Bitmap>): Bitmap? {
        if (bitmaps.isEmpty()) return null
        if (bitmaps.size == 1) return bitmaps[0]
        return try {
            val width = bitmaps.minOf { it.width }
            // Scale every shot to a common width so rows line up.
            val norm = bitmaps.map { if (it.width == width) it else Bitmap.createScaledBitmap(it, width, it.height * width / it.width, true) }
            val sigs = norm.map { rowSignatures(it) }
            val offsets = IntArray(norm.size)
            offsets[0] = 0
            for (i in 1 until norm.size) {
                val ov = overlap(sigs[i - 1], sigs[i])
                offsets[i] = offsets[i - 1] + norm[i - 1].height - ov
            }
            val totalH = offsets.last() + norm.last().height
            val out = Bitmap.createBitmap(width, totalH, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            for (i in norm.indices) canvas.drawBitmap(norm[i], 0f, offsets[i].toFloat(), null)
            out
        } catch (_: Throwable) { null }
    }
}
