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

    /**
     * "Location": where the phone is right now, as an address and a map link, for a tool that sends or saves it.
     * The caller has already been given the location permission. Null when the phone can't say where it is.
     * Nothing is sent anywhere unless the person sends the result.
     */
    @android.annotation.SuppressLint("MissingPermission")
    suspend fun whereAmI(ctx: Context): String? = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        try {
            val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? android.location.LocationManager ?: return@withContext null
            val providers = runCatching { lm.getProviders(true) }.getOrDefault(emptyList())
            var loc: android.location.Location? = providers.mapNotNull { p -> runCatching { lm.getLastKnownLocation(p) }.getOrNull() }.maxByOrNull { it.time }
            // A fix older than two minutes may be somewhere else entirely, so ask for a fresh one where the phone can give it.
            if ((loc == null || System.currentTimeMillis() - loc.time > 120_000L) && android.os.Build.VERSION.SDK_INT >= 30) {
                val provider = listOf("fused", "network", "gps").firstOrNull { it in providers }
                if (provider != null) {
                    val fresh = kotlinx.coroutines.withTimeoutOrNull(15_000L) {
                        kotlinx.coroutines.suspendCancellableCoroutine<android.location.Location?> { cont ->
                            lm.getCurrentLocation(provider, null, ctx.mainExecutor) { found -> if (cont.isActive) cont.resumeWith(Result.success(found)) }
                        }
                    }
                    if (fresh != null) loc = fresh
                }
            }
            val here = loc ?: return@withContext null
            // The address is a nicety; with no connection the map link alone is still enough.
            @Suppress("DEPRECATION")
            val address = runCatching { android.location.Geocoder(ctx, java.util.Locale.getDefault()).getFromLocation(here.latitude, here.longitude, 1)?.firstOrNull()?.getAddressLine(0) }.getOrNull().orEmpty()
            TextTidy.locationText(here.latitude, here.longitude, address)
        } catch (_: Throwable) { null }
    }

    /** A picked file's bytes (a recording, a PDF). Null if it can't be read or is larger than [limit]. */
    fun bytes(ctx: Context, uri: Uri, limit: Long = 200L * 1_048_576L): ByteArray? = try {
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            val out = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(65_536)
            var ok = true
            while (true) {
                val n = ins.read(chunk)
                if (n < 0) break
                out.write(chunk, 0, n)
                if (out.size() > limit) { ok = false; break }
            }
            if (ok) out.toByteArray() else null
        }
    } catch (_: Throwable) { null }

    /** The ending a picked recording should carry ("m4a", "mp3"...), from its type or its name. */
    fun audioExt(ctx: Context, uri: Uri): String {
        val fromType = when (ctx.contentResolver.getType(uri)?.lowercase()) {
            "audio/mpeg", "audio/mp3" -> "mp3"; "audio/wav", "audio/x-wav", "audio/wave" -> "wav"; "audio/aac" -> "aac"; "audio/ogg" -> "ogg"; "audio/flac" -> "flac"
            "audio/mp4", "audio/m4a", "audio/x-m4a" -> "m4a"; else -> null
        }
        if (fromType != null) return fromType
        val name = runCatching { com.handytools.app.tools.power.MediaEngine.displayName(ctx, uri) }.getOrDefault("")
        return name.substringAfterLast('.', "").lowercase().takeIf { TextTidy.isAudio(it) } ?: "m4a"
    }

    /** The plain words of a Word .docx or OpenDocument .odt — unzip the one entry that holds the body
     * (java.util.zip is built in, no third-party library) and strip its XML. Null if it isn't one of those
     * or can't be read, so the caller can fall back to an honest message. */
    fun richDocumentText(ctx: Context, uri: Uri, name: String?): String? {
        val ext = name?.substringAfterLast('.', "")?.lowercase().orEmpty()
        if (ext == "xlsx") return xlsxText(ctx, uri)
        val entryName = when (ext) { "docx" -> "word/document.xml"; "odt" -> "content.xml"; else -> return null }
        return try {
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                java.util.zip.ZipInputStream(ins.buffered()).use { zip ->
                    var found: String? = null
                    var e = zip.nextEntry
                    while (e != null) {
                        if (e.name == entryName) { found = stripDocXml(zip.readBytes().toString(Charsets.UTF_8)); break }
                        e = zip.nextEntry
                    }
                    found?.takeIf { it.isNotBlank() }
                }
            }
        } catch (_: Throwable) { null }
    }

    /** An Excel .xlsx is a ZIP too; read the first worksheet (and the shared-strings table it references)
     * and turn its rows into tab/newline text. Null if it can't be read or has no rows. */
    private fun xlsxText(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            java.util.zip.ZipInputStream(ins.buffered()).use { zip ->
                var sheet: String? = null
                var sst: String? = null
                var e = zip.nextEntry
                while (e != null) {
                    when (e.name) {
                        "xl/worksheets/sheet1.xml" -> sheet = zip.readBytes().toString(Charsets.UTF_8)
                        "xl/sharedStrings.xml" -> sst = zip.readBytes().toString(Charsets.UTF_8)
                    }
                    e = zip.nextEntry
                }
                sheet?.let { sheetText(sst, it) }?.takeIf { it.isNotBlank() }
            }
        }
    } catch (_: Throwable) { null }

    /** Turn an .xlsx worksheet's XML (plus the shared-strings table) into tab/newline text — pure and
     * testable, the same rules as the iOS twin. Cells with t="s" reference a shared string by index;
     * inline and numeric cells are read directly. Reads a sheet's rows, not formulas. */
    internal fun sheetText(sharedStringsXml: String?, sheetXml: String): String {
        val shared = sharedStrings(sharedStringsXml)
        val rows = ArrayList<String>()
        for (row in Regex("<row\\b[^>]*>(.*?)</row>", RegexOption.DOT_MATCHES_ALL).findAll(sheetXml)) {
            val cells = Regex("<c\\b[^>]*>.*?</c>|<c\\b[^>]*/>", RegexOption.DOT_MATCHES_ALL)
                .findAll(row.groupValues[1]).map { cellValue(it.value, shared) }.toList()
            rows.add(cells.joinToString("\t"))
        }
        while (rows.isNotEmpty() && rows.last().isBlank()) rows.removeAt(rows.size - 1)
        return rows.joinToString("\n")
    }

    private fun sharedStrings(xml: String?): List<String> {
        if (xml == null) return emptyList()
        return Regex("<si\\b[^>]*>(.*?)</si>", RegexOption.DOT_MATCHES_ALL).findAll(xml).map { si ->
            val text = Regex("<t\\b[^>]*>(.*?)</t>", RegexOption.DOT_MATCHES_ALL)
                .findAll(si.groupValues[1]).joinToString("") { it.groupValues[1] }
            decodeXmlEntities(text)
        }.toList()
    }

    private fun cellValue(c: String, shared: List<String>): String {
        val type = Regex("<c\\b[^>]*\\bt=\"([a-z]+)\"", RegexOption.IGNORE_CASE).find(c)?.groupValues?.get(1)
        if (type == "inlineStr") {
            val inline = Regex("<t\\b[^>]*>(.*?)</t>", RegexOption.DOT_MATCHES_ALL)
                .findAll(c).joinToString("") { it.groupValues[1] }
            return decodeXmlEntities(inline)
        }
        val v = Regex("<v\\b[^>]*>(.*?)</v>", RegexOption.DOT_MATCHES_ALL).find(c)?.groupValues?.get(1) ?: return ""
        if (type == "s") { v.trim().toIntOrNull()?.let { if (it in shared.indices) return shared[it] } }
        return decodeXmlEntities(v)
    }

    private fun decodeXmlEntities(s: String): String =
        s.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'")

    /** Turn a Word/OpenDocument body XML into readable lines: paragraph/break tags become newlines, tabs
     * become tabs, every other tag is dropped, and the common entities are decoded. */
    internal fun stripDocXml(xml: String): String {
        var s = xml
        s = s.replace(Regex("<w:tab\\b[^>]*/?>", RegexOption.IGNORE_CASE), "\t")
        s = s.replace(Regex("</w:p>|<w:br\\b[^>]*/?>|</text:p>|<text:line-break\\b[^>]*/?>", RegexOption.IGNORE_CASE), "\n")
        s = s.replace(Regex("<[^>]+>"), "")
        s = s.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'")
        return s.split("\n").map { it.trim() }.filter { it.isNotEmpty() }.joinToString("\n").trim()
    }

    /** Several PDFs joined page after page, in the order given. Null if one of them can't be opened. */
    fun joinPdfs(ctx: Context, parts: List<ByteArray>): ByteArray? = try {
        if (!pdfboxReady) { PDFBoxResourceLoader.init(ctx.applicationContext); pdfboxReady = true }
        val out = PDDocument()
        val open = ArrayList<PDDocument>()
        try {
            for (p in parts) {
                val d = PDDocument.load(p); open.add(d)
                for (i in 0 until d.numberOfPages) out.importPage(d.getPage(i))
            }
            java.io.ByteArrayOutputStream().also { out.save(it) }.toByteArray()
        } finally { open.forEach { runCatching { it.close() } }; runCatching { out.close() } }
    } catch (_: Throwable) { null }
}
