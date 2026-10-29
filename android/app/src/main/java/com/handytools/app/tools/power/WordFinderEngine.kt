package com.handytools.app.tools.power

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipInputStream

internal data class FinderSource(val uri: String, val tree: Boolean, val label: String)
internal data class FinderDoc(val uri: Uri, val name: String, val text: String, val noText: Boolean)
internal data class FinderHit(val doc: FinderDoc, val snippet: String, val matchStart: Int, val matchEnd: Int)
internal data class SavedPassage(val name: String, val uri: String, val passage: String)

/**
 * Word Finder: indexes the text of the user's own documents (txt/md/csv, docx/xlsx/pptx, pdf) and
 * searches it. Extracted text is cached per file in cacheDir so re-opening is instant. Everything
 * runs on the phone — no account, nothing uploaded.
 */
internal object WordFinder {
    private const val PREFS = "wordfinder"
    private const val MAX_DOCS = 400
    private const val MAX_TEXT = 2_000_000
    private val supportedExt = setOf("txt", "md", "csv", "log", "json", "docx", "xlsx", "pptx", "pdf")

    /** Process-level cache so switching tabs/screens doesn't re-index. */
    @Volatile var cached: List<FinderDoc> = emptyList()
    @Volatile var cachedKey: String = ""

    fun isSupported(name: String) = name.substringAfterLast('.', "").lowercase() in supportedExt

    // ------------------------------------------------------------------ sources + saved passages (prefs)

    fun sources(ctx: Context): List<FinderSource> = runCatching {
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, 0).getString("sources", "[]"))
        (0 until arr.length()).map { val o = arr.getJSONObject(it); FinderSource(o.getString("uri"), o.getBoolean("tree"), o.optString("label", "")) }
    }.getOrDefault(emptyList())

    fun saveSources(ctx: Context, list: List<FinderSource>) {
        val arr = JSONArray()
        list.forEach { arr.put(JSONObject().put("uri", it.uri).put("tree", it.tree).put("label", it.label)) }
        ctx.getSharedPreferences(PREFS, 0).edit().putString("sources", arr.toString()).apply()
    }

    fun savedPassages(ctx: Context): List<SavedPassage> = runCatching {
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, 0).getString("saved", "[]"))
        (0 until arr.length()).map { val o = arr.getJSONObject(it); SavedPassage(o.getString("name"), o.getString("uri"), o.getString("passage")) }
    }.getOrDefault(emptyList())

    fun saveSaved(ctx: Context, list: List<SavedPassage>) {
        val arr = JSONArray()
        list.forEach { arr.put(JSONObject().put("name", it.name).put("uri", it.uri).put("passage", it.passage)) }
        ctx.getSharedPreferences(PREFS, 0).edit().putString("saved", arr.toString()).apply()
    }

    fun treeLabel(uri: Uri): String {
        val id = runCatching { DocumentsContract.getTreeDocumentId(uri) }.getOrNull() ?: return "Folder"
        val tail = id.substringAfter(':', id).trimEnd('/')
        return if (tail.isBlank()) "Folder" else tail.substringAfterLast('/')
    }

    // ------------------------------------------------------------------ enumeration

    private data class Entry(val uri: Uri, val name: String, val modified: Long)

    private fun listTree(ctx: Context, tree: Uri, out: MutableList<Entry>) {
        val root = runCatching { DocumentsContract.getTreeDocumentId(tree) }.getOrNull() ?: return
        listChildren(ctx, tree, DocumentsContract.buildChildDocumentsUriUsingTree(tree, root), out, 0)
    }

    private fun listChildren(ctx: Context, tree: Uri, childrenUri: Uri, out: MutableList<Entry>, depth: Int) {
        val cols = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val dirs = ArrayList<String>()
        try {
            ctx.contentResolver.query(childrenUri, cols, null, null, null)?.use { c ->
                while (c.moveToNext() && out.size < MAX_DOCS) {
                    val id = c.getString(0) ?: continue
                    val name = c.getString(1) ?: continue
                    val mime = c.getString(2) ?: ""
                    val mod = if (c.isNull(3)) 0L else c.getLong(3)
                    if (name.startsWith(".")) continue
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) dirs += id
                    else if (isSupported(name)) out += Entry(DocumentsContract.buildDocumentUriUsingTree(tree, id), name, mod)
                }
            }
        } catch (_: Exception) {}
        if (depth < 5) dirs.forEach { id ->
            if (out.size < MAX_DOCS) listChildren(ctx, tree, DocumentsContract.buildChildDocumentsUriUsingTree(tree, id), out, depth + 1)
        }
    }

    private fun fileEntry(ctx: Context, uri: Uri): Entry? {
        var name: String? = null; var mod = 0L
        try {
            ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni)
                    val mi = c.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                    if (mi >= 0 && !c.isNull(mi)) mod = c.getLong(mi)
                }
            }
        } catch (_: Exception) {}
        val n = name ?: uri.lastPathSegment?.substringAfterLast('/') ?: return null
        return Entry(uri, n, mod)
    }

    // ------------------------------------------------------------------ indexing

    /** Builds the index for [sources]; [onProgress] gets (done, total, currentName). */
    suspend fun index(ctx: Context, sources: List<FinderSource>, onProgress: (Int, Int, String) -> Unit): List<FinderDoc> {
        val key = sources.joinToString("|") { it.uri }
        if (key == cachedKey && cached.isNotEmpty()) return cached
        val entries = ArrayList<Entry>()
        sources.forEach { s ->
            val uri = Uri.parse(s.uri)
            if (s.tree) listTree(ctx, uri, entries) else fileEntry(ctx, uri)?.let { entries += it }
        }
        val distinct = entries.distinctBy { it.uri.toString() }
        val docs = ArrayList<FinderDoc>()
        distinct.forEachIndexed { i, e ->
            onProgress(i, distinct.size, e.name)
            val (text, noText) = cachedText(ctx, e) ?: extractAndCache(ctx, e)
            docs += FinderDoc(e.uri, e.name, text, noText)
        }
        onProgress(distinct.size, distinct.size, "")
        cached = docs; cachedKey = key
        return docs
    }

    fun invalidate() { cachedKey = ""; cached = emptyList() }

    private fun cacheFile(ctx: Context, e: Entry): File {
        val dir = File(ctx.cacheDir, "wordfinder").apply { mkdirs() }
        val k = "${e.uri}|${e.modified}|${e.name}"
        return File(dir, "${k.hashCode()}_${k.length}.txt")
    }

    private fun cachedText(ctx: Context, e: Entry): Pair<String, Boolean>? {
        val f = cacheFile(ctx, e)
        if (!f.exists()) return null
        return try {
            val raw = f.readText()
            if (raw.startsWith("\u0001NOTEXT\n")) raw.removePrefix("\u0001NOTEXT\n") to true else raw to false
        } catch (_: Exception) { null }
    }

    private suspend fun extractAndCache(ctx: Context, e: Entry): Pair<String, Boolean> {
        val r = try { extract(ctx, e.uri, e.name) } catch (_: Throwable) { "" to false }
        try { cacheFile(ctx, e).writeText((if (r.second) "\u0001NOTEXT\n" else "") + r.first) } catch (_: Exception) {}
        return r
    }

    /** Returns (text, noTextLayer). */
    private suspend fun extract(ctx: Context, uri: Uri, name: String): Pair<String, Boolean> {
        val ext = name.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "txt", "md", "csv", "log", "json" -> readText(ctx, uri) to false
            "docx" -> {
                val entries = zipEntries(ctx, uri) { it == "word/document.xml" }
                docxToText(entries["word/document.xml"] ?: "") to false
            }
            "xlsx" -> xlsxToText(zipEntries(ctx, uri) { it == "xl/sharedStrings.xml" || (it.startsWith("xl/worksheets/sheet") && it.endsWith(".xml")) }) to false
            "pptx" -> {
                val slides = zipEntries(ctx, uri) { it.startsWith("ppt/slides/slide") && it.endsWith(".xml") }
                slides.toSortedMap(compareBy<String>({ it.length }, { it })).values.joinToString("\n\n") { pptxSlideToText(it) } to false
            }
            "pdf" -> pdfText(ctx, uri)
            else -> "" to false
        }
    }

    private fun readText(ctx: Context, uri: Uri): String =
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            val bytes = ins.readBytes()
            String(bytes, 0, minOf(bytes.size, MAX_TEXT), Charsets.UTF_8)
        } ?: ""

    private fun zipEntries(ctx: Context, uri: Uri, want: (String) -> Boolean): Map<String, String> {
        val out = HashMap<String, String>()
        var total = 0
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            ZipInputStream(ins).use { zip ->
                var entry = zip.nextEntry
                while (entry != null && total < 12_000_000) {
                    if (!entry.isDirectory && want(entry.name)) {
                        val bos = ByteArrayOutputStream()
                        val buf = ByteArray(32 * 1024)
                        var n = zip.read(buf)
                        while (n >= 0 && bos.size() < 8_000_000) { bos.write(buf, 0, n); n = zip.read(buf) }
                        total += bos.size()
                        out[entry.name] = bos.toString("UTF-8")
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
        }
        return out
    }

    private val tagRe = Regex("<[^>]+>")
    private val spaceRe = Regex("[ \\t\\u00A0]+")

    internal fun unescape(s: String): String {
        if (!s.contains('&')) return s
        var t = s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'")
        t = Regex("&#x([0-9a-fA-F]+);").replace(t) { m -> m.groupValues[1].toIntOrNull(16)?.let { String(Character.toChars(it)) } ?: m.value }
        t = Regex("&#(\\d+);").replace(t) { m -> m.groupValues[1].toIntOrNull()?.let { String(Character.toChars(it)) } ?: m.value }
        return t.replace("&amp;", "&")
    }

    private fun stripTags(s: String): String = unescape(tagRe.replace(s, "")).replace(spaceRe, " ")

    private fun docxToText(xml: String): String {
        val t = xml.replace("</w:p>", "\n").replace("<w:tab/>", "\t").replace("<w:br/>", "\n").replace("</w:tc>", "\t")
        return stripTags(t).lines().joinToString("\n") { it.trim() }.replace(Regex("\n{3,}"), "\n\n").trim()
    }

    private fun pptxSlideToText(xml: String): String {
        val t = xml.replace("</a:p>", "\n").replace("</a:t>", " ")
        return stripTags(t).lines().map { it.trim() }.filter { it.isNotEmpty() }.joinToString("\n")
    }

    private fun xlsxToText(entries: Map<String, String>): String {
        val shared = ArrayList<String>()
        entries["xl/sharedStrings.xml"]?.let { ss ->
            Regex("<si>(.*?)</si>", RegexOption.DOT_MATCHES_ALL).findAll(ss).forEach { shared += stripTags(it.groupValues[1]).trim() }
        }
        val sb = StringBuilder()
        val cellRe = Regex("<c\\b([^>]*?)(?:/>|>(.*?)</c>)", RegexOption.DOT_MATCHES_ALL)
        val vRe = Regex("<v>(.*?)</v>", RegexOption.DOT_MATCHES_ALL)
        entries.keys.filter { it.startsWith("xl/worksheets/") }.sortedWith(compareBy<String>({ it.length }, { it })).forEach { sheet ->
            val xml = entries[sheet] ?: return@forEach
            sb.append(sheet.substringAfterLast('/').substringBeforeLast('.')).append('\n')
            Regex("<row\\b[^>]*>(.*?)</row>", RegexOption.DOT_MATCHES_ALL).findAll(xml).forEach { row ->
                val cells = cellRe.findAll(row.groupValues[1]).mapNotNull { c ->
                    val attrs = c.groupValues[1]; val body = c.groupValues[2]
                    if (body.isEmpty()) null
                    else if (attrs.contains("t=\"s\"")) vRe.find(body)?.groupValues?.get(1)?.toIntOrNull()?.let { shared.getOrNull(it) }
                    else if (attrs.contains("t=\"inlineStr\"")) stripTags(body).trim()
                    else vRe.find(body)?.groupValues?.get(1)?.let { unescape(it) }
                }.filter { it.isNotBlank() }.toList()
                if (cells.isNotEmpty()) sb.append(cells.joinToString("  ")).append('\n')
            }
            sb.append('\n')
            if (sb.length > MAX_TEXT) return sb.toString()
        }
        return sb.toString().trim()
    }

    @Volatile private var pdfboxReady = false

    private suspend fun pdfText(ctx: Context, uri: Uri): Pair<String, Boolean> {
        var text = ""
        try {
            if (!pdfboxReady) { PDFBoxResourceLoader.init(ctx.applicationContext); pdfboxReady = true }
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                PDDocument.load(ins).use { doc ->
                    val stripper = PDFTextStripper()
                    stripper.startPage = 1
                    stripper.endPage = minOf(doc.numberOfPages, 150)
                    text = stripper.getText(doc) ?: ""
                }
            }
        } catch (_: Throwable) { text = "" }
        if (text.isNotBlank() && text.count { it.isLetterOrDigit() } > 20) return text.take(MAX_TEXT) to false
        // Scanned PDF: no text layer. Best effort — OCR the first few pages on-device.
        val ocr = StringBuilder()
        try {
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            try {
                val pages = DocEngine.pdfPageCount(ctx, uri)
                for (i in 0 until minOf(pages, 6)) {
                    val bmp: Bitmap = DocEngine.renderPdfPage(ctx, uri, i, 1400) ?: continue
                    val t = recognizer.process(InputImage.fromBitmap(bmp, 0)).await().text
                    bmp.recycle()
                    if (t.isNotBlank()) ocr.append(t).append("\n\n")
                }
            } finally { recognizer.close() }
        } catch (_: Throwable) {}
        return if (ocr.isNotBlank()) ocr.toString() to false else "" to true
    }

    // ------------------------------------------------------------------ search

    fun search(docs: List<FinderDoc>, raw: String, context: Int = 80, max: Int = 80): List<FinderHit> {
        val q = raw.trim()
        if (q.isEmpty()) return emptyList()
        val re = Regex(Regex.escape(q), RegexOption.IGNORE_CASE)
        val hits = ArrayList<FinderHit>()
        for (d in docs) {
            if (d.text.isEmpty()) continue
            for (m in re.findAll(d.text)) {
                val a = maxOf(0, m.range.first - context)
                val b = minOf(d.text.length, m.range.last + 1 + context)
                val prefix = if (a > 0) "…" else ""
                val body = d.text.substring(a, b).replace('\n', ' ').replace('\t', ' ')
                val suffix = if (b < d.text.length) "…" else ""
                val start = prefix.length + (m.range.first - a)
                hits += FinderHit(d, prefix + body + suffix, start, start + (m.range.last + 1 - m.range.first))
                if (hits.size >= max) return hits
            }
        }
        return hits
    }
}
