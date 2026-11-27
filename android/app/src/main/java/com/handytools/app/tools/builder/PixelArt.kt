package com.handytools.app.tools.builder

/**
 * Turns a photo into a pencil sketch, a comic, a black-and-white print, pop art, watercolour, oil paint, neon,
 * retro film or a halftone print. It works on plain numbers
 * (one 0xRRGGBB value per pixel, row by row), so it is the same on Android and iPhone and can be unit-tested.
 */
object PixelArt {
    val STYLES = listOf("sketch" to "Pencil sketch", "comic" to "Comic", "noir" to "Black and white", "pop" to "Pop art",
        "watercolor" to "Watercolour", "oil" to "Oil paint", "neon" to "Neon glow", "film" to "Retro film", "halftone" to "Halftone print")
    fun style(setting: String?): String = if (STYLES.any { it.first == setting }) setting!! else "sketch"

    /** How bright each pixel is, 0 (black) to 255 (white). */
    fun gray(px: IntArray): IntArray = IntArray(px.size) { i -> ((px[i] shr 16 and 0xFF) * 299 + (px[i] shr 8 and 0xFF) * 587 + (px[i] and 0xFF) * 114) / 1000 }

    /** Each value replaced by the average of the square around it ([radius] pixels each way). Edges use what is there. */
    fun blur(v: IntArray, width: Int, height: Int, radius: Int): IntArray {
        if (radius <= 0 || width <= 0 || height <= 0 || v.size != width * height) return v
        val across = IntArray(v.size)
        for (y in 0 until height) {
            var sum = 0; var n = 0
            for (x in 0 until minOf(radius + 1, width)) { sum += v[y * width + x]; n++ }
            for (x in 0 until width) {
                across[y * width + x] = sum / n
                val add = x + radius + 1; val drop = x - radius
                if (add < width) { sum += v[y * width + add]; n++ }
                if (drop >= 0) { sum -= v[y * width + drop]; n-- }
            }
        }
        val out = IntArray(v.size)
        for (x in 0 until width) {
            var sum = 0; var n = 0
            for (y in 0 until minOf(radius + 1, height)) { sum += across[y * width + x]; n++ }
            for (y in 0 until height) {
                out[y * width + x] = sum / n
                val add = y + radius + 1; val drop = y - radius
                if (add < height) { sum += across[add * width + x]; n++ }
                if (drop >= 0) { sum -= across[drop * width + x]; n-- }
            }
        }
        return out
    }

    /** A pencil drawing of the picture: white paper, with a grey line wherever the picture changes. 0..255 per pixel. */
    fun pencil(px: IntArray, width: Int, height: Int): IntArray {
        val g = gray(px)
        val soft = blur(IntArray(g.size) { 255 - g[it] }, width, height, maxOf(2, minOf(width, height) / 80))
        return IntArray(g.size) { i ->
            val v = minOf(255, g[i] * 255 / maxOf(1, 255 - soft[i]))
            v * v / 255          // a little darker, so the lines read as pencil rather than haze
        }
    }

    private fun rgb(r: Int, g: Int, b: Int) = (r shl 16) or (g shl 8) or b

    // ---- painted looks (the same integer maths as the iPhone, so both phones make the same picture)

    private fun ch(px: IntArray, shift: Int) = IntArray(px.size) { px[it] shr shift and 0xFF }
    private fun clamp(v: Int) = v.coerceIn(0, 255)
    /** More (k > 100) or less colour, in hundredths, around each pixel's own brightness. */
    fun saturate(r: Int, g: Int, b: Int, k: Int): IntArray {
        val y = (r * 299 + g * 587 + b * 114) / 1000
        return intArrayOf(clamp(y + (r - y) * k / 100), clamp(y + (g - y) * k / 100), clamp(y + (b - y) * k / 100))
    }
    /** A fixed speckle in -n..n for pixel i, the same on every phone (film grain). */
    fun grain(i: Int, n: Int): Int {
        var x = (i.toLong() * 2654435761L) and 0xFFFFFFFFL
        x = x xor (x ushr 15); x = (x * 2246822519L) and 0xFFFFFFFFL; x = x xor (x ushr 13)
        return (x % (2 * n + 1)).toInt() - n
    }

    /** Soft washes of colour that bleed a little, darker where the paint pooled at edges, on white paper. */
    fun watercolor(px: IntArray, w: Int, h: Int): IntArray {
        val rad = maxOf(2, minOf(w, h) / 120)
        val r = blur(ch(px, 16), w, h, rad); val g = blur(ch(px, 8), w, h, rad); val b = blur(ch(px, 0), w, h, rad)
        val lines = pencil(px, w, h)
        return IntArray(px.size) { i ->
            val s = saturate(r[i] / 24 * 24 + 12, g[i] / 24 * 24 + 12, b[i] / 24 * 24 + 12, 115)
            val edge = 70 + lines[i] * 30 / 255
            fun paper(c: Int) = clamp((c * edge / 100) * 82 / 100 + 255 * 18 / 100)
            rgb(paper(s[0]), paper(s[1]), paper(s[2]))
        }
    }

    /** Thick, flat dabs of rich colour. */
    fun oil(px: IntArray, w: Int, h: Int): IntArray {
        val rad = maxOf(2, minOf(w, h) / 90)
        val r = blur(ch(px, 16), w, h, rad); val g = blur(ch(px, 8), w, h, rad); val b = blur(ch(px, 0), w, h, rad)
        val lum = gray(px); val fine = blur(lum, w, h, 1)
        return IntArray(px.size) { i ->
            val s = saturate(r[i] / 20 * 20 + 10, g[i] / 20 * 20 + 10, b[i] / 20 * 20 + 10, 135)
            val relief = (lum[i] - fine[i]) * 2
            rgb(clamp(s[0] + relief), clamp(s[1] + relief), clamp(s[2] + relief))
        }
    }

    /** Every outline glowing in the photo's own colours, brightened, on black. */
    fun neon(px: IntArray, w: Int, h: Int): IntArray {
        val lines = pencil(px, w, h).let { p -> IntArray(p.size) { 255 - p[it] } }
        val glow = blur(lines, w, h, maxOf(2, minOf(w, h) / 100))
        return IntArray(px.size) { i ->
            val e = minOf(255, lines[i] * 3 + glow[i] * 2)
            val s = saturate(px[i] shr 16 and 0xFF, px[i] shr 8 and 0xFF, px[i] and 0xFF, 220)
            fun lit(c: Int) = clamp((c + 80) * e / 255)
            rgb(lit(s[0]), lit(s[1]), lit(s[2]))
        }
    }

    /** An old print: warm, faded blacks, softer colour, a darker rim and fine grain. */
    fun film(px: IntArray, w: Int, h: Int): IntArray {
        val cx = w / 2; val cy = h / 2; val far = maxOf(1, cx * cx + cy * cy)
        return IntArray(px.size) { i ->
            val x = i % w; val y = i / w
            val rim = 100 - ((x - cx) * (x - cx) + (y - cy) * (y - cy)) * 30 / far
            val s = saturate(px[i] shr 16 and 0xFF, px[i] shr 8 and 0xFF, px[i] and 0xFF, 75)
            val n = grain(i, 9)
            fun tone(c: Int, shift: Int) = clamp((28 + c * 80 / 100 + shift) * rim / 100 + n)
            rgb(tone(s[0], 14), tone(s[1], 4), tone(s[2], -16))
        }
    }

    /** A printed look: a grid of ink dots, bigger where the photo is darker, each in its patch's colour, on cream paper. */
    fun halftone(px: IntArray, w: Int, h: Int): IntArray {
        val per = maxOf(5, minOf(w, h) / 90)
        val cols = (w + per - 1) / per; val rows = (h + per - 1) / per
        val sr = IntArray(cols * rows); val sg = IntArray(cols * rows); val sb = IntArray(cols * rows); val cnt = IntArray(cols * rows)
        for (i in px.indices) {
            val c = (i / w) / per * cols + (i % w) / per
            sr[c] += px[i] shr 16 and 0xFF; sg[c] += px[i] shr 8 and 0xFF; sb[c] += px[i] and 0xFF; cnt[c]++
        }
        val paper = rgb(250, 244, 228)
        return IntArray(px.size) { i ->
            val x = i % w; val y = i / w; val c = y / per * cols + x / per; val n = maxOf(1, cnt[c])
            val r = sr[c] / n; val g = sg[c] / n; val b = sb[c] / n
            val dark = 255 - (r * 299 + g * 587 + b * 114) / 1000
            val rad2 = per * per * (dark + 40) * (dark + 40) / (295 * 295) * 55 / 100
            val dx = 2 * (x % per) - per + 1; val dy = 2 * (y % per) - per + 1
            if (dx * dx + dy * dy >= 4 * rad2) paper else {
                val s = saturate(r, g, b, 140)
                rgb(clamp(s[0] * 85 / 100), clamp(s[1] * 85 / 100), clamp(s[2] * 85 / 100))
            }
        }
    }

    /** The picture in the chosen style, as 0xRRGGBB values. An unknown style gives the pencil sketch. */
    fun apply(px: IntArray, width: Int, height: Int, style: String): IntArray {
        if (width <= 0 || height <= 0 || px.size != width * height) return px
        return when (style) {
            "noir" -> gray(px).let { g -> IntArray(g.size) { val v = ((g[it] - 128) * 135 / 100 + 128).coerceIn(0, 255); rgb(v, v, v) } }
            "pop" -> {
                // Four flat inks, darkest to lightest.
                val inks = intArrayOf(rgb(27, 20, 100), rgb(230, 0, 126), rgb(255, 230, 0), rgb(255, 248, 231))
                gray(px).let { g -> IntArray(g.size) { inks[minOf(3, g[it] / 64)] } }
            }
            "comic" -> {
                // Flat blocks of colour with an ink line round them.
                val lines = pencil(px, width, height)
                fun flat(c: Int) = minOf(255, (c + 32) / 64 * 64)
                IntArray(px.size) { i ->
                    if (lines[i] < 150) rgb(24, 24, 28)
                    else rgb(flat(px[i] shr 16 and 0xFF), flat(px[i] shr 8 and 0xFF), flat(px[i] and 0xFF))
                }
            }
            "watercolor" -> watercolor(px, width, height)
            "oil" -> oil(px, width, height)
            "neon" -> neon(px, width, height)
            "film" -> film(px, width, height)
            "halftone" -> halftone(px, width, height)
            else -> pencil(px, width, height).let { p -> IntArray(p.size) { rgb(p[it], p[it], p[it]) } }
        }
    }
}
