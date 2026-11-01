package com.handytools.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build

/**
 * One safe way to turn a picked image Uri into a Bitmap. Full-resolution camera photos are tens of
 * megapixels; decoding them raw is the single biggest crash source in the image tools (an
 * OutOfMemoryError, which ordinary `catch (Exception)` does NOT catch). This always downsamples to a
 * sane working size and swallows any decode failure — including OOM — by returning null, so a bad or
 * huge image degrades gracefully instead of taking down the app.
 */
object SafeBitmap {

    /** Decode [uri] downsampled so its longest edge is roughly [maxEdge]px. Null on any failure. */
    fun decode(ctx: Context, uri: Uri, maxEdge: Int = 2560): Bitmap? {
        // Preferred path on API 28+: ImageDecoder with a software allocator and a target size — it is
        // HEIC-aware and memory-friendly.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val src = ImageDecoder.createSource(ctx.contentResolver, uri)
                return ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    decoder.isMutableRequired = true
                    val w = info.size.width; val h = info.size.height
                    val longest = maxOf(w, h)
                    if (longest > maxEdge && longest > 0) {
                        val s = maxEdge.toFloat() / longest
                        decoder.setTargetSize((w * s).toInt().coerceAtLeast(1), (h * s).toInt().coerceAtLeast(1))
                    }
                }
            } catch (_: Throwable) { /* fall through to the BitmapFactory path */ }
        }
        // Fallback: a bounds pass to choose inSampleSize, then a downsampled decode.
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            while (longest / sample > maxEdge) sample *= 2
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
        } catch (_: Throwable) { null }
    }
}
