package com.handytools.app.tools.power

import android.graphics.Bitmap

/**
 * Daltonisation — shifts the colours a given type of colour blindness confuses into differences the
 * eye can still tell apart, so (say) red/green that looks identical becomes distinguishable. Standard
 * LMS-space pipeline. Pure maths on the pixels; nothing leaves the phone.
 */
object ColorVisionEngine {

    // sRGB -> LMS (Hunt-Pointer-Estevez style, as used by common daltonize implementations)
    private val RGB2LMS = floatArrayOf(
        17.8824f, 43.5161f, 4.11935f,
        3.45565f, 27.1554f, 3.86714f,
        0.0299566f, 0.184309f, 1.46709f,
    )
    private val LMS2RGB = floatArrayOf(
        0.0809444479f, -0.130504409f, 0.116721066f,
        -0.0102485335f, 0.0540193266f, -0.113614708f,
        -0.000365296938f, -0.00412161469f, 0.693511405f,
    )
    // Simulation matrices for protanopia / deuteranopia / tritanopia (in LMS space).
    private val SIM = arrayOf(
        floatArrayOf(0f, 2.02344f, -2.52581f, 0f, 1f, 0f, 0f, 0f, 1f),          // protan
        floatArrayOf(1f, 0f, 0f, 0.494207f, 0f, 1.24827f, 0f, 0f, 1f),          // deutan
        floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, -0.395913f, 0.801109f, 0f),        // tritan
    )
    // Error-shift: push the colour the eye can't see into channels it can.
    private val SHIFT = floatArrayOf(0f, 0f, 0f, 0.7f, 1f, 0f, 0.7f, 0f, 1f)

    private fun mul(m: FloatArray, a: Float, b: Float, c: Float, out: FloatArray) {
        out[0] = m[0] * a + m[1] * b + m[2] * c
        out[1] = m[3] * a + m[4] * b + m[5] * c
        out[2] = m[6] * a + m[7] * b + m[8] * c
    }

    /** type: 0 protan, 1 deutan, 2 tritan. Returns a new corrected bitmap, or null on failure. */
    fun daltonize(src: Bitmap, type: Int): Bitmap? = try {
        val w = src.width; val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val sim = SIM[type.coerceIn(0, 2)]
        val lms = FloatArray(3); val lms2 = FloatArray(3); val rgb2 = FloatArray(3); val shifted = FloatArray(3)
        for (i in px.indices) {
            val p = px[i]
            val a = p.toInt() and 0xFF000000.toInt()
            val r = ((p shr 16) and 0xFF).toFloat()
            val g = ((p shr 8) and 0xFF).toFloat()
            val b = (p and 0xFF).toFloat()
            mul(RGB2LMS, r, g, b, lms)
            mul(sim, lms[0], lms[1], lms[2], lms2)
            mul(LMS2RGB, lms2[0], lms2[1], lms2[2], rgb2)
            val er = r - rgb2[0]; val eg = g - rgb2[1]; val eb = b - rgb2[2]
            mul(SHIFT, er, eg, eb, shifted)
            val nr = (r + shifted[0]).coerceIn(0f, 255f).toInt()
            val ng = (g + shifted[1]).coerceIn(0f, 255f).toInt()
            val nb = (b + shifted[2]).coerceIn(0f, 255f).toInt()
            px[i] = a or (nr shl 16) or (ng shl 8) or nb
        }
        Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    } catch (_: Throwable) { null }
}
