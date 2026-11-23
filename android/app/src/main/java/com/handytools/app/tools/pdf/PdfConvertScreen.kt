package com.handytools.app.tools.pdf

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File

/** Convert a PDF into photos (one per page, sharp enough to read) or into text you can copy — a scan's words are
 *  read on the phone when the PDF has no text inside. */
object PdfConvert {
    fun images(ctx: Context, src: File, base: String, onPage: (Int, Int) -> Unit = { _, _ -> }): List<File> {
        val n = PdfCore.pageCount(src)
        return (0 until n).mapNotNull { i ->
            onPage(i + 1, n)
            PdfCore.render(src, i, 1654)?.let { b ->   // ~200 dpi on letter/A4
                val f = PdfCore.out(ctx, "$base - page ${i + 1}.jpg")
                f.outputStream().use { b.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it) }; b.recycle(); f
            }
        }
    }

    suspend fun text(ctx: Context, src: File, onPage: (Int, Int) -> Unit = { _, _ -> }): String {
        PdfCore.init(ctx)
        val inside = runCatching { PDDocument.load(src).use { PDFTextStripper().getText(it) } }.getOrDefault("").trim()
        if (inside.length > 20) return inside
        // A scan: read the words off each page.
        val rec = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val n = PdfCore.pageCount(src)
        val out = StringBuilder()
        for (i in 0 until n) {
            onPage(i + 1, n)
            val b = PdfCore.render(src, i, 1654) ?: continue
            val t = runCatching { rec.process(InputImage.fromBitmap(b, 0)).await().text }.getOrDefault("")
            if (t.isNotBlank()) out.append(t.trim()).append("\n\n")
        }
        return out.toString().trim()
    }
}

@Composable
fun PdfConvertScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var src by remember { mutableStateOf<File?>(null) }
    var name by remember { mutableStateOf("Document") }
    var progress by remember { mutableStateOf<String?>(null) }
    var text by remember { mutableStateOf<String?>(null) }
    var images by remember { mutableStateOf<List<File>>(emptyList()) }

    PowerToolPage("pdfconvert") {
        val s = src
        when {
            s == null -> PdfPicker("Choose a PDF to turn into photos or into text you can copy.") { uri ->
                scope.launch { src = withContext(Dispatchers.IO) { PdfCore.copy(ctx, uri) }; name = PdfCore.name(ctx, uri) }
            }
            text != null -> {
                Text(I18n.t("The text"), fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground)
                Spacer(Modifier.size(8.dp))
                SelectionContainer { Text(text!!.ifBlank { I18n.t("No words were found in this PDF.") }, fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.fillMaxWidth().heightIn(max = 420.dp).verticalScroll(rememberScrollState()).testTag("pdf-text")) }
                Spacer(Modifier.size(12.dp))
                HPrimaryButton("Share the text") { Share.text(ctx, text!!) }
                Spacer(Modifier.size(8.dp))
                HSecondaryButton("Save as a text file") {
                    val f = PdfCore.out(ctx, "$name.txt").apply { writeText(text!!) }
                    Share.file(ctx, f, "text/plain")
                }
                Spacer(Modifier.size(8.dp))
                HSecondaryButton("Start again") { text = null; src = null }
            }
            images.isNotEmpty() -> {
                ResultCard(images.first(), "image/jpeg", remember(images) { android.graphics.BitmapFactory.decodeFile(images.first().path) },
                    "${images.size} " + I18n.t("photos, one per page")) { images = emptyList(); src = null }
                Spacer(Modifier.size(8.dp))
                if (images.size > 1) HSecondaryButton("Share all ${images.size} photos") { Share.files(ctx, images, "image/jpeg") }
            }
            else -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("$name.pdf · ${PdfCore.pageCount(s)} " + I18n.t("pages"), color = MaterialTheme.colorScheme.onBackground)
                progress?.let { Text(it, fontSize = 13.sp, color = Handy.palette.textSecondary) }
                HPrimaryButton("Turn into photos", enabled = progress == null, modifier = Modifier.testTag("pdf-to-images")) {
                    scope.launch {
                        images = withContext(Dispatchers.IO) { PdfConvert.images(ctx, s, name) { i, n -> progress = I18n.t("Page") + " $i / $n" } }
                        progress = null
                    }
                }
                HSecondaryButton("Turn into text") {
                    scope.launch {
                        text = withContext(Dispatchers.IO) { PdfConvert.text(ctx, s) { i, n -> progress = I18n.t("Reading page") + " $i / $n" } }
                        progress = null
                    }
                }
            }
        }
    }
}
