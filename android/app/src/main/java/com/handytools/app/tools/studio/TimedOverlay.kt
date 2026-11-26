package com.handytools.app.tools.studio

import android.graphics.Bitmap
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlaySettings

/**
 * One picture laid over a video that changes with time (the trailer's cards and flashes, a funny moment's words):
 * [pick] gives the picture and how see-through it is at a time in seconds (null: nothing), [scaleAt] how big.
 */
@androidx.annotation.OptIn(UnstableApi::class)
class TimedOverlay(private val pick: (Double) -> Pair<Bitmap, Float>?, private val scaleAt: (Double) -> Float = { 1f }) : BitmapOverlay() {
    private val clear = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
    override fun getBitmap(presentationTimeUs: Long): Bitmap = pick(presentationTimeUs / 1e6)?.first ?: clear
    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
        val t = presentationTimeUs / 1e6
        val a = pick(t)?.second ?: 0f
        val s = scaleAt(t)
        return OverlaySettings.Builder().setAlphaScale(a.coerceIn(0f, 1f)).setScale(s, s).build()   // Media3 1.5: OverlaySettings is the class
    }
}
