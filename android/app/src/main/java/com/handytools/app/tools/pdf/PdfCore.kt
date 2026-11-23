package com.handytools.app.tools.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color as AColor
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import java.io.File

/**
 * What the Android PDF tools share (Organize Pages, Protect, Convert, Sign, Mark up, Redact, Fill a Form, Make
 * Searchable — the iPhone's PDF tab): reading a picked PDF, drawing its pages for thumbnails and previews, and the
 * finished-file card (preview, Save, Share) every tool ends on. All on the phone.
 */
object PdfCore {
    @Volatile private var ready = false
    fun init(ctx: Context) { if (!ready) { PDFBoxResourceLoader.init(ctx.applicationContext); ready = true } }

    /** The file's name as the person sees it, without ".pdf". */
    fun name(ctx: Context, uri: Uri): String = runCatching {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }.getOrNull()?.substringBeforeLast('.')?.ifBlank { null } ?: "Document"

    /** Copies the picked file into the app's cache so it can be read more than once. */
    fun copy(ctx: Context, uri: Uri, ext: String = "pdf"): File? = runCatching {
        val f = File.createTempFile("in_", ".$ext", ctx.cacheDir)
        ctx.contentResolver.openInputStream(uri)!!.use { i -> f.outputStream().use { i.copyTo(it) } }
        f
    }.getOrNull()

    fun out(ctx: Context, name: String): File {
        val dir = File(ctx.cacheDir, "out").apply { mkdirs() }
        return File(dir, name.replace("/", "-"))
    }

    fun pageCount(file: File): Int = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd -> PdfRenderer(fd).use { it.pageCount } }
    }.getOrDefault(0)

    /** Page [index] as a picture [width] pixels wide (white paper behind it). Null if it can't be drawn (locked PDF). */
    fun render(file: File, index: Int, width: Int = 600): Bitmap? = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { r ->
                r.openPage(index).use { p ->
                    val h = (width.toFloat() * p.height / p.width).toInt().coerceAtLeast(1)
                    Bitmap.createBitmap(width, h, Bitmap.Config.ARGB_8888).also {
                        it.eraseColor(AColor.WHITE); p.render(it, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    }
                }
            }
        }
    }.getOrNull()

    fun thumbs(file: File, width: Int = 240): List<Bitmap?> = (0 until pageCount(file)).map { render(file, it, width) }

    /** A page that's almost all white (a blank scan page). Pure on the pixel data. */
    fun isBlank(pixels: IntArray, threshold: Double = 0.995): Boolean {
        if (pixels.isEmpty()) return true
        val white = pixels.count { p -> ((p shr 16) and 0xFF) > 245 && ((p shr 8) and 0xFF) > 245 && (p and 0xFF) > 245 }
        return white.toDouble() / pixels.size >= threshold
    }
    fun isBlank(b: Bitmap): Boolean {
        val px = IntArray(b.width * b.height); b.getPixels(px, 0, b.width, 0, 0, b.width, b.height); return isBlank(px)
    }
}

/** "Choose a PDF" — the first screen of every PDF tool. */
@Composable
fun PdfPicker(line: String, mime: String = "application/pdf", onPicked: (Uri) -> Unit) {
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { it?.let(onPicked) }
    Text(I18n.t(line), color = Handy.palette.textSecondary)
    Spacer(Modifier.size(12.dp))
    HPrimaryButton("Choose a PDF", modifier = Modifier.testTag("pdf-pick")) { pick.launch(arrayOf(mime)) }
}

/** The finished file: a preview of what was made, then Save (pick where) or Share — same as the iPhone. */
@Composable
fun ResultCard(file: File, mime: String, preview: Bitmap?, line: String, onAgain: () -> Unit) {
    val ctx = LocalContext.current
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(mime)) { uri ->
        uri?.let { u -> runCatching { ctx.contentResolver.openOutputStream(u)?.use { o -> file.inputStream().use { it.copyTo(o) } } } }
    }
    Column {
        Text(I18n.t("Ready"), fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.onBackground)
        Text(line, fontSize = 13.sp, color = Handy.palette.textSecondary)
        Spacer(Modifier.size(10.dp))
        val img = remember(preview) { preview?.asImageBitmap() }
        if (img != null) Image(img, I18n.t("Preview"), contentScale = ContentScale.FillWidth,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).testTag("pdf-preview"))
        Spacer(Modifier.size(12.dp))
        HPrimaryButton("Share", modifier = Modifier.testTag("pdf-share")) { Share.file(ctx, file, mime) }
        Spacer(Modifier.size(8.dp))
        HSecondaryButton("Save to my files") { save.launch(file.name) }
        Spacer(Modifier.size(8.dp))
        HSecondaryButton("Start again") { onAgain() }
    }
}
