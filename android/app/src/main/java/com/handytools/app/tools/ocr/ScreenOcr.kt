package com.handytools.app.tools.ocr

import com.handytools.app.ui.HandyHaptics

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.Toast
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.HandyApp
import com.handytools.app.data.Clip
import com.handytools.app.tools.clipboard.ClipboardOverlay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

object ScreenOcr {
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    /** OCR the frame, copy all text to the clipboard AND push it onto the clipboard stack. */
    suspend fun recognizeAndCopy(ctx: Context, frame: Bitmap) {
        val text = runCatching { recognizer.process(InputImage.fromBitmap(frame, 0)).await().text }.getOrDefault("")
        if (text.isBlank()) { withContext(Dispatchers.Main) { Toast.makeText(ctx, "No text found on screen", Toast.LENGTH_SHORT).show() }; return }
        withContext(Dispatchers.Main) {
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Screen text", text))
            com.handytools.app.ui.HandyHaptics.medium(ctx)
            Toast.makeText(ctx, "Copied ${text.lines().size} lines of text", Toast.LENGTH_SHORT).show()
        }
        com.handytools.app.tools.clipboard.ClipStore.save(text, "ocr")
    }
}
