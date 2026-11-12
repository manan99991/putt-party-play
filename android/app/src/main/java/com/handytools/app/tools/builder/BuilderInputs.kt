package com.handytools.app.tools.builder

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.ContactsContract
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File

/** More ways to hand something to a tool besides typing or picking a photo: a contact, a PDF. Speech uses the phone's own voice typing. */
object BuilderInputs {
    @Volatile private var pdfboxReady = false

    /** The one contact the person tapped, as plain lines. Works without the contacts permission: the picker grants that single row. */
    fun contact(ctx: Context, row: Uri): String = runCatching {
        ctx.contentResolver.query(row, arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { c ->
            if (c.moveToFirst()) TextTidy.contactLines(c.getString(0).orEmpty(), "", listOf(c.getString(1).orEmpty()), emptyList()) else ""
        } ?: ""
    }.getOrDefault("")

    /** The words in a PDF (first 150 pages). Null if it can't be opened; blank if it has no text (a scan). */
    fun pdfText(ctx: Context, uri: Uri): String? = try {
        if (!pdfboxReady) { PDFBoxResourceLoader.init(ctx.applicationContext); pdfboxReady = true }
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            PDDocument.load(ins).use { doc ->
                val stripper = PDFTextStripper()
                stripper.startPage = 1
                stripper.endPage = minOf(doc.numberOfPages, 150)
                (stripper.getText(doc) ?: "").trim()
            }
        }
    } catch (_: Throwable) { null }

    /** Each page as a picture sharp enough to read (long side about 2000 px), saved in the cache. Empty if the PDF can't be opened. */
    fun pdfPages(ctx: Context, uri: Uri, limit: Int): List<Uri> = try {
        val dir = File(ctx.cacheDir, "pdf-in").also { it.deleteRecursively(); it.mkdirs() }
        val copy = File(dir, "in.pdf")
        ctx.contentResolver.openInputStream(uri)?.use { ins -> copy.outputStream().use { ins.copyTo(it) } }
        val out = ArrayList<Uri>()
        ParcelFileDescriptor.open(copy, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { r ->
                for (i in 0 until minOf(r.pageCount, limit)) {
                    r.openPage(i).use { page ->
                        val scale = minOf(3f, 2000f / maxOf(page.width, page.height, 1))
                        val bmp = Bitmap.createBitmap((page.width * scale).toInt().coerceAtLeast(1), (page.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                        bmp.eraseColor(Color.WHITE)
                        page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                        val f = File(dir, "page-${i + 1}.jpg")
                        f.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                        bmp.recycle()
                        out.add(Uri.fromFile(f))
                    }
                }
            }
        }
        out
    } catch (_: Throwable) { emptyList() }
}
