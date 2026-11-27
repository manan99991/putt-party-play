package com.handytools.app.tools.studio

import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Bald's filled picture (27 Nov rebuild, the iPhone's push-pull fill): at the parts map's 256 x 256, the hair standing
 * out beyond each skull (above the brows) is filled in from what's around it — averages over ever wider squares of the
 * known pixels, the finest that saw enough winning. The shader blends it in where that hair was.
 */
object BaldFill {
    /** How much of the hair at frame point ([x], [y]) stands out beyond [s]'s skull (the shader's own test). */
    fun beyond(s: FaceEngine.Skull, hair: Float, x: Float, y: Float): Float {
        val sx = -s.uy; val sy = s.ux
        val u = ((x - s.cx) * sx + (y - s.cy) * sy) / max(s.ax, 1f)
        val v = ((x - s.cx) * s.ux + (y - s.cy) * s.uy) / max(s.ay, 1f)
        val e = hypot(u, v)
        val scale = max(s.ax, s.ay)
        val gate = (((x - s.bx) * s.ux + (y - s.by) * s.uy + 0.02f * scale) / (0.12f * scale)).coerceIn(0f, 1f)
        val zone = 1f - step(1.8f, 1.95f, e)
        val skull = 1f - step(0.94f, 1f, e)
        return (hair * zone * gate - skull).coerceIn(0f, 1f)
    }

    private fun step(a: Float, b: Float, x: Float): Float { val t = ((x - a) / (b - a)).coerceIn(0f, 1f); return t * t * (3 - 2 * t) }

    fun filled(look: FaceEngine.Look, w: Int, h: Int): IntArray? {
        val p = look.parts ?: return null; val rgb = look.rgb ?: return null
        val n = FaceEngine.SIDE
        val hole = BooleanArray(n * n)
        for (i in 0 until n * n) {
            val x = (i % n + 0.5f) * w / n; val y = (i / n + 0.5f) * h / n
            if (look.heads.any { beyond(it, p[i * 6 + 1], x, y) > 0.12f }) hole[i] = true
        }
        if (hole.none { it }) return rgb.copyOf()
        // Grow the hole a pixel so the hair's soft edge goes too.
        val grown = hole.copyOf()
        for (i in 0 until n * n) if (hole[i]) {
            val x = i % n; val y = i / n
            for (dy in -1..1) for (dx in -1..1) { val xx = x + dx; val yy = y + dy; if (xx in 0 until n && yy in 0 until n) grown[yy * n + xx] = true }
        }
        // Push: premultiplied sums at each level.
        val levels = ArrayList<FloatArray>()   // r, g, b, weight per pixel
        var size = n
        var cur = FloatArray(n * n * 4)
        for (i in 0 until n * n) if (!grown[i]) {
            val c = rgb[i]
            cur[i * 4] = ((c shr 16) and 255).toFloat(); cur[i * 4 + 1] = ((c shr 8) and 255).toFloat(); cur[i * 4 + 2] = (c and 255).toFloat(); cur[i * 4 + 3] = 1f
        }
        levels += cur
        while (size > 4) {
            val half = size / 2
            val next = FloatArray(half * half * 4)
            for (y in 0 until half) for (x in 0 until half) for (dy in 0..1) for (dx in 0..1) {
                val j = ((y * 2 + dy) * size + x * 2 + dx) * 4; val k = (y * half + x) * 4
                for (c in 0..3) next[k + c] += cur[j + c]
            }
            levels += next; cur = next; size = half
        }
        // Pull: from the coarsest, each finer level keeps what it saw and takes the rest from the coarser (bilinear).
        var coarse = levels.last(); var cs = size
        var colour = FloatArray(cs * cs * 3) { i -> val k = i / 3; if (coarse[k * 4 + 3] > 0) coarse[k * 4 + i % 3] / coarse[k * 4 + 3] else 128f }
        for (li in levels.size - 2 downTo 0) {
            val fine = levels[li]; val fs = cs * 2
            val out = FloatArray(fs * fs * 3)
            for (y in 0 until fs) for (x in 0 until fs) {
                val gx = ((x + 0.5f) / 2 - 0.5f).coerceIn(0f, (cs - 1).toFloat()); val gy = ((y + 0.5f) / 2 - 0.5f).coerceIn(0f, (cs - 1).toFloat())
                val x0 = gx.toInt(); val y0 = gy.toInt(); val x1 = min(cs - 1, x0 + 1); val y1 = min(cs - 1, y0 + 1)
                val fx = gx - x0; val fy = gy - y0
                val k = (y * fs + x)
                val wgt = fine[k * 4 + 3]
                val have = min(1f, wgt / (if (li == 0) 1f else (1 shl (2 * li)).toFloat()) * 1.5f)
                for (c in 0..2) {
                    fun at(xx: Int, yy: Int) = colour[(yy * cs + xx) * 3 + c]
                    val up = at(x0, y0) * (1 - fx) * (1 - fy) + at(x1, y0) * fx * (1 - fy) + at(x0, y1) * (1 - fx) * fy + at(x1, y1) * fx * fy
                    val own = if (wgt > 0) fine[k * 4 + c] / wgt else up
                    out[k * 3 + c] = own * have + up * (1 - have)
                }
            }
            colour = out; cs = fs; coarse = fine
        }
        return IntArray(n * n) { i ->
            if (!grown[i]) rgb[i] else {
                val r = colour[i * 3].toInt().coerceIn(0, 255); val g = colour[i * 3 + 1].toInt().coerceIn(0, 255); val b = colour[i * 3 + 2].toInt().coerceIn(0, 255)
                (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
    }
}
