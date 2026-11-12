package com.handytools.app.tools.builder

/**
 * Turns a photo into a pencil sketch, a comic, a black-and-white print or pop art. It works on plain numbers
 * (one 0xRRGGBB value per pixel, row by row), so it is the same on Android and iPhone and can be unit-tested.
 */
object PixelArt {
    val STYLES = listOf("sketch" to "Pencil sketch", "comic" to "Comic", "noir" to "Black and white", "pop" to "Pop art")
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
            else -> pencil(px, width, height).let { p -> IntArray(p.size) { rgb(p[it], p[it], p[it]) } }
        }
    }
}
