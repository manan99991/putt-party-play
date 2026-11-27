package com.handytools.app.tools.builder

import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.drawable.AnimatedImageDrawable
import android.os.Build
import android.widget.ImageView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import java.nio.ByteBuffer

/** A GIF result, playing. Phones before Android 9 can't animate one in an ImageView, so they show its first frame. */
@Composable
fun GifView(bytes: ByteArray, modifier: Modifier = Modifier) {
    AndroidView(
        factory = { ImageView(it).apply { adjustViewBounds = true; scaleType = ImageView.ScaleType.FIT_CENTER } },
        update = { v ->
            if (v.tag === bytes) return@AndroidView
            v.tag = bytes
            if (Build.VERSION.SDK_INT >= 28) {
                val d = runCatching { ImageDecoder.decodeDrawable(ImageDecoder.createSource(ByteBuffer.wrap(bytes))) }.getOrNull()
                v.setImageDrawable(d)
                (d as? AnimatedImageDrawable)?.start()
            } else {
                v.setImageBitmap(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
            }
        },
        modifier = modifier,
    )
}
