package com.handytools.app.tools.power

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipInputStream

/**
 * The engine behind the universal File Viewer: identify ANY file by its real content (magic bytes,
 * not just the extension) and read it on-device — no upload, no account. Everything here is pure
 * logic (no Compose) and meant to run off the main thread.
 *
 * Deliberately stdlib-only (java.util.zip, android.database.sqlite, PackageManager, MessageDigest,
 * MediaMetadataRetriever) so it adds no dependency and can open things other apps hand off to us.
 */
object FileViewer {

    enum class Kind { IMAGE, PDF, TEXT, JSON, XML, CSV, ARCHIVE, SQLITE, APK, AUDIO, VIDEO, EBOOK, BINARY }

    data class Meta(
        val name: String,
        val size: Long,
        val mime: String,
        val kind: Kind,
        val typeLabel: String,   // human: "PNG image", "ZIP archive", "SQLite database"…
        val detail: String?,     // extra: dimensions, page/entry/row count…
    )

    data class ZEntry(val name: String, val size: Long, val isDir: Boolean)
    data class ApkInfo(
        val label: String, val pkg: String, val versionName: String, val versionCode: Long,
        val minSdk: Int, val targetSdk: Int, val permissions: List<String>, val signature: String,
    )

    // ---- display helpers (reuse the Documents engine where it already does the work) ----
    fun displayName(ctx: Context, uri: Uri): String = DocEngine.displayName(ctx, uri)

    fun sizeOf(ctx: Context, uri: Uri): Long {
        try {
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) return c.getLong(0)
            }
        } catch (_: Exception) {}
        return try { ctx.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L } catch (_: Exception) { -1L }
    }

    fun humanSize(bytes: Long): String {
        if (bytes < 0) return "unknown size"
        if (bytes < 1024) return "$bytes B"
        val u = arrayOf("KB", "MB", "GB", "TB")
        var v = bytes.toDouble(); var i = -1
        while (v >= 1024 && i < u.size - 1) { v /= 1024; i++ }
        return String.format("%.1f %s", v, u[i])
    }

    private fun header(ctx: Context, uri: Uri, n: Int = 64): ByteArray =
        try {
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                val buf = ByteArray(n); val read = ins.read(buf)
                if (read <= 0) ByteArray(0) else buf.copyOf(read)
            } ?: ByteArray(0)
        } catch (_: Exception) { ByteArray(0) }

    private fun startsWith(b: ByteArray, vararg sig: Int): Boolean {
        if (b.size < sig.size) return false
        for (i in sig.indices) if ((b[i].toInt() and 0xFF) != sig[i]) return false
        return true
    }

    /** Identify the file by content first, extension second. Safe to call off the main thread. */
    fun probe(ctx: Context, uri: Uri): Meta {
        val name = displayName(ctx, uri)
        val size = sizeOf(ctx, uri)
        val ext = name.substringAfterLast('.', "").lowercase()
        val h = header(ctx, uri, 64)
        val declared = (ctx.contentResolver.getType(uri) ?: "").lowercase()

        // --- content signatures (magic numbers) ---
        when {
            startsWith(h, 0x25, 0x50, 0x44, 0x46) -> // %PDF
                return Meta(name, size, "application/pdf", Kind.PDF, "PDF document", pdfDetail(ctx, uri))
            startsWith(h, 0x89, 0x50, 0x4E, 0x47) -> return img(ctx, uri, name, size, "image/png", "PNG image")
            startsWith(h, 0xFF, 0xD8, 0xFF) -> return img(ctx, uri, name, size, "image/jpeg", "JPEG image")
            startsWith(h, 0x47, 0x49, 0x46, 0x38) -> return img(ctx, uri, name, size, "image/gif", "GIF image")
            startsWith(h, 0x42, 0x4D) && ext == "bmp" -> return img(ctx, uri, name, size, "image/bmp", "Bitmap image")
            h.size >= 12 && startsWith(h, 0x52, 0x49, 0x46, 0x46) && h[8].toInt() == 0x57 && h[9].toInt() == 0x45 ->
                return img(ctx, uri, name, size, "image/webp", "WebP image")
            String(h.copyOf(minOf(16, h.size))).startsWith("SQLite format 3") ->
                return Meta(name, size, "application/x-sqlite3", Kind.SQLITE, "SQLite database", null)
            startsWith(h, 0x50, 0x4B, 0x03, 0x04) || startsWith(h, 0x50, 0x4B, 0x05, 0x06) -> // PK.. (zip family)
                return zipFamily(ctx, uri, name, size, ext)
            // Non-zip archives: recognised and given real metadata/hex + "Open with" an extractor, but
            // not browsed inline yet (that lands with the archive-library pass).
            startsWith(h, 0x1F, 0x8B) -> return Meta(name, size, "application/gzip", Kind.BINARY, "Gzip archive", "open with an extractor to unpack")
            startsWith(h, 0x37, 0x7A, 0xBC, 0xAF) -> return Meta(name, size, "application/x-7z-compressed", Kind.BINARY, "7-Zip archive", "open with an extractor to unpack")
            startsWith(h, 0x52, 0x61, 0x72, 0x21) -> return Meta(name, size, "application/vnd.rar", Kind.BINARY, "RAR archive", "open with an extractor to unpack")
            startsWith(h, 0x42, 0x5A, 0x68) -> return Meta(name, size, "application/x-bzip2", Kind.BINARY, "Bzip2 archive", "open with an extractor to unpack")
            startsWith(h, 0xFD, 0x37, 0x7A, 0x58) -> return Meta(name, size, "application/x-xz", Kind.BINARY, "XZ archive", "open with an extractor to unpack")
            startsWith(h, 0x28, 0xB5, 0x2F, 0xFD) -> return Meta(name, size, "application/zstd", Kind.BINARY, "Zstandard archive", "open with an extractor to unpack")
            startsWith(h, 0x4D, 0x5A) -> return Meta(name, size, "application/x-msdownload", Kind.BINARY, "Windows executable (PE)", "can't run on Android — showing its bytes") // MZ
            startsWith(h, 0x7F, 0x45, 0x4C, 0x46) -> return Meta(name, size, "application/x-elf", Kind.BINARY, "ELF executable", null) // .ELF
        }

        // --- by declared MIME / extension ---
        if (ext in RAW_EXT) return Meta(name, size, "image/x-raw", Kind.IMAGE, "${ext.uppercase()} camera RAW", "showing the embedded preview")
        if (ext in EBOOK_EXT) return Meta(name, size, "application/epub+zip", Kind.EBOOK, EBOOK_LABEL[ext] ?: "eBook", null)
        if (declared.startsWith("image/") || ext in IMAGE_EXT) return img(ctx, uri, name, size, declared.ifEmpty { "image/*" }, (ext.uppercase().ifEmpty { "Image" }) + " image")
        if (declared.startsWith("audio/") || ext in AUDIO_EXT) return Meta(name, size, declared.ifEmpty { "audio/*" }, Kind.AUDIO, (ext.uppercase().ifEmpty { "Audio" }) + " audio", null)
        if (declared.startsWith("video/") || ext in VIDEO_EXT) return Meta(name, size, declared.ifEmpty { "video/*" }, Kind.VIDEO, (ext.uppercase().ifEmpty { "Video" }) + " video", null)
        if (ext == "apk") return Meta(name, size, "application/vnd.android.package-archive", Kind.APK, "Android app (APK)", null)
        if (ext in SQLITE_EXT) return Meta(name, size, "application/x-sqlite3", Kind.SQLITE, "SQLite database", null)
        if (ext == "json") return Meta(name, size, "application/json", Kind.JSON, "JSON data", null)
        if (ext == "xml" || declared.endsWith("xml")) return Meta(name, size, "application/xml", Kind.XML, "XML document", null)
        if (ext in CSV_EXT) return Meta(name, size, "text/csv", Kind.CSV, "${ext.uppercase()} table", null)
        // Archives we recognise by extension but don't browse inline yet: real label + metadata/hex.
        ARCHIVE_LABEL[ext]?.let { return Meta(name, size, "application/octet-stream", Kind.BINARY, it, "open with an extractor to unpack") }
        if (ext in TEXT_EXT || declared.startsWith("text/")) return Meta(name, size, declared.ifEmpty { "text/plain" }, Kind.TEXT, textLabel(ext), null)

        // --- fall back: is it actually text? sniff the head for printable bytes ---
        if (looksLikeText(h)) {
            val headAll = header(ctx, uri, 4096)
            if (looksLikeText(headAll)) {
                val t = String(headAll).trimStart()
                return when {
                    t.startsWith("{") || t.startsWith("[") -> Meta(name, size, "application/json", Kind.JSON, "JSON data", null)
                    t.startsWith("<") -> Meta(name, size, "application/xml", Kind.XML, "XML/markup", null)
                    else -> Meta(name, size, "text/plain", Kind.TEXT, "Text", null)
                }
            }
        }
        return Meta(name, size, declared.ifEmpty { "application/octet-stream" }, Kind.BINARY,
            if (ext.isEmpty()) "Unknown binary" else "${ext.uppercase()} file", null)
    }

    private fun img(ctx: Context, uri: Uri, name: String, size: Long, mime: String, label: String): Meta {
        val dim = try {
            val o = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
            ctx.contentResolver.openInputStream(uri)?.use { android.graphics.BitmapFactory.decodeStream(it, null, o) }
            if (o.outWidth > 0) "${o.outWidth} × ${o.outHeight}px" else null
        } catch (_: Exception) { null }
        return Meta(name, size, mime, Kind.IMAGE, label, dim)
    }

    private fun pdfDetail(ctx: Context, uri: Uri): String? = try {
        val n = DocEngine.pdfPageCount(ctx, uri)
        if (n > 0) "$n page${if (n == 1) "" else "s"}" else null
    } catch (_: Exception) { null }

    private fun zipFamily(ctx: Context, uri: Uri, name: String, size: Long, ext: String): Meta {
        val label = when (ext) {
            "apk" -> "Android app (APK)"
            "jar" -> "Java archive (JAR)"
            "epub" -> "EPUB book"
            "docx" -> "Word document"
            "xlsx" -> "Excel spreadsheet"
            "pptx" -> "PowerPoint deck"
            "odt", "ods", "odp" -> "OpenDocument file"
            else -> "ZIP archive"
        }
        if (ext == "apk") return Meta(name, size, "application/vnd.android.package-archive", Kind.APK, label, null)
        val count = try { zipEntries(ctx, uri).size } catch (_: Exception) { 0 }
        return Meta(name, size, "application/zip", Kind.ARCHIVE, label, if (count > 0) "$count item${if (count == 1) "" else "s"}" else null)
    }

    // ---- loaders ----
    fun loadBitmap(ctx: Context, uri: Uri, maxEdge: Int = 2400): Bitmap? = DocEngine.loadBitmap(ctx, uri, maxEdge)

    /** Decode up to maxBytes as UTF-8 text; pretty-print JSON/XML when the kind says so. */
    fun textHead(ctx: Context, uri: Uri, kind: Kind, maxBytes: Int = 1_000_000): Pair<String, Boolean> {
        val raw = readBytes(ctx, uri, maxBytes)
        val truncated = raw.size >= maxBytes
        var text = String(raw, Charsets.UTF_8)
        text = when (kind) {
            Kind.JSON -> try { prettyJson(text) } catch (_: Exception) { text }
            Kind.XML -> try { prettyXml(text) } catch (_: Exception) { text }
            else -> text
        }
        return text to truncated
    }

    fun csvRows(ctx: Context, uri: Uri, maxBytes: Int = 1_000_000): List<List<String>> {
        val text = String(readBytes(ctx, uri, maxBytes), Charsets.UTF_8)
        // Auto-detect the delimiter from the first line (handles csv / tsv / psv / ssv).
        val firstLine = text.lineSequence().firstOrNull { it.isNotBlank() } ?: ""
        val sep = listOf('\t', '|', ';', ',').maxByOrNull { c -> firstLine.count { it == c } } ?: ','
        return parseCsv(text, if (firstLine.count { it == sep } == 0) ',' else sep)
    }

    fun hexDump(ctx: Context, uri: Uri, maxBytes: Int = 64 * 1024): String {
        val b = readBytes(ctx, uri, maxBytes)
        val sb = StringBuilder()
        var i = 0
        while (i < b.size) {
            sb.append(String.format("%08X  ", i))
            val row = minOf(16, b.size - i)
            for (j in 0 until 16) {
                if (j < row) sb.append(String.format("%02X ", b[i + j].toInt() and 0xFF)) else sb.append("   ")
                if (j == 7) sb.append(" ")
            }
            sb.append(" |")
            for (j in 0 until row) { val c = b[i + j].toInt() and 0xFF; sb.append(if (c in 0x20..0x7E) c.toChar() else '.') }
            sb.append("|\n")
            i += 16
        }
        if (b.size >= maxBytes) sb.append("…(truncated)\n")
        return sb.toString()
    }

    fun strings(ctx: Context, uri: Uri, min: Int = 4, maxBytes: Int = 1_000_000): List<String> {
        val b = readBytes(ctx, uri, maxBytes)
        val out = ArrayList<String>()
        val cur = StringBuilder()
        for (byte in b) {
            val c = byte.toInt() and 0xFF
            if (c in 0x20..0x7E) cur.append(c.toChar())
            else { if (cur.length >= min) out.add(cur.toString()); cur.setLength(0) }
            if (out.size >= 2000) break
        }
        if (cur.length >= min) out.add(cur.toString())
        return out
    }

    fun hashes(ctx: Context, uri: Uri): Map<String, String> {
        val md5 = MessageDigest.getInstance("MD5")
        val sha1 = MessageDigest.getInstance("SHA-1")
        val sha256 = MessageDigest.getInstance("SHA-256")
        try {
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val r = ins.read(buf); if (r <= 0) break
                    md5.update(buf, 0, r); sha1.update(buf, 0, r); sha256.update(buf, 0, r)
                }
            }
        } catch (_: Exception) { return emptyMap() }
        fun hex(d: ByteArray) = d.joinToString("") { String.format("%02x", it) }
        return linkedMapOf("MD5" to hex(md5.digest()), "SHA-1" to hex(sha1.digest()), "SHA-256" to hex(sha256.digest()))
    }

    fun zipEntries(ctx: Context, uri: Uri): List<ZEntry> {
        val out = ArrayList<ZEntry>()
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            ZipInputStream(ins).use { zis ->
                var e = zis.nextEntry
                while (e != null) {
                    out.add(ZEntry(e.name, e.size, e.isDirectory))
                    if (out.size >= 5000) break
                    zis.closeEntry(); e = zis.nextEntry
                }
            }
        }
        return out.sortedWith(compareBy({ !it.isDir }, { it.name }))
    }

    /** Pull one entry's bytes out of a zip (for previewing a file inside an archive). */
    fun zipEntryBytes(ctx: Context, uri: Uri, entryName: String, maxBytes: Int = 1_000_000): ByteArray? {
        ctx.contentResolver.openInputStream(uri)?.use { ins ->
            ZipInputStream(ins).use { zis ->
                var e = zis.nextEntry
                while (e != null) {
                    if (e.name == entryName) {
                        val bos = java.io.ByteArrayOutputStream()
                        val buf = ByteArray(32 * 1024); var total = 0
                        while (total < maxBytes) {
                            val r = zis.read(buf); if (r <= 0) break
                            bos.write(buf, 0, r); total += r
                        }
                        return bos.toByteArray()
                    }
                    zis.closeEntry(); e = zis.nextEntry
                }
            }
        }
        return null
    }

    /** Extract the whole archive into a cache folder; returns the folder (for "extract & share"). */
    fun extractZip(ctx: Context, uri: Uri): File? {
        val dir = File(ctx.cacheDir, "extract-${System.currentTimeMillis()}").apply { mkdirs() }
        try {
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                ZipInputStream(ins).use { zis ->
                    var e = zis.nextEntry
                    while (e != null) {
                        val target = File(dir, e.name)
                        // Zip-slip guard: never let an entry escape the extract dir.
                        if (!target.canonicalPath.startsWith(dir.canonicalPath + File.separator)) { zis.closeEntry(); e = zis.nextEntry; continue }
                        if (e.isDirectory) target.mkdirs()
                        else { target.parentFile?.mkdirs(); target.outputStream().use { zis.copyTo(it) } }
                        zis.closeEntry(); e = zis.nextEntry
                    }
                }
            }
            return dir
        } catch (_: Exception) { return null }
    }

    fun copyToCache(ctx: Context, uri: Uri, ext: String): File? {
        return try {
            val f = File(ctx.cacheDir, "open-${System.currentTimeMillis()}.$ext")
            ctx.contentResolver.openInputStream(uri)?.use { input -> f.outputStream().use { input.copyTo(it) } }
            f
        } catch (_: Exception) { null }
    }

    // ---- SQLite ----
    fun sqliteTables(dbFile: File): List<Pair<String, Int>> {
        val out = ArrayList<Pair<String, Int>>()
        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name", null).use { c ->
                while (c.moveToNext()) {
                    val t = c.getString(0)
                    val n = try { db.rawQuery("SELECT COUNT(*) FROM \"$t\"", null).use { if (it.moveToFirst()) it.getInt(0) else 0 } } catch (_: Exception) { -1 }
                    out.add(t to n)
                }
            }
        } catch (_: Exception) {} finally { try { db?.close() } catch (_: Exception) {} }
        return out
    }

    fun sqliteRows(dbFile: File, table: String, limit: Int = 100): Pair<List<String>, List<List<String>>> {
        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery("SELECT * FROM \"$table\" LIMIT $limit", null).use { c ->
                val cols = c.columnNames.toList()
                val rows = ArrayList<List<String>>()
                while (c.moveToNext()) {
                    val r = ArrayList<String>(cols.size)
                    for (i in cols.indices) {
                        r.add(when (c.getType(i)) {
                            android.database.Cursor.FIELD_TYPE_NULL -> "∅"
                            android.database.Cursor.FIELD_TYPE_BLOB -> "⟨blob ${c.getBlob(i)?.size ?: 0}B⟩"
                            else -> c.getString(i) ?: ""
                        })
                    }
                    rows.add(r)
                }
                return cols to rows
            }
        } catch (_: Exception) { return emptyList<String>() to emptyList() } finally { try { db?.close() } catch (_: Exception) {} }
    }

    // ---- APK ----
    @Suppress("DEPRECATION")
    fun apkInfo(ctx: Context, apkFile: File): ApkInfo? {
        val pm = ctx.packageManager
        val flags = PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNATURES
        val pi: PackageInfo = pm.getPackageArchiveInfo(apkFile.path, flags) ?: return null
        pi.applicationInfo?.let { it.sourceDir = apkFile.path; it.publicSourceDir = apkFile.path }
        val label = try { pi.applicationInfo?.loadLabel(pm)?.toString() ?: pi.packageName } catch (_: Exception) { pi.packageName }
        val perms = pi.requestedPermissions?.toList() ?: emptyList()
        val min = pi.applicationInfo?.minSdkVersion ?: 0
        val target = pi.applicationInfo?.targetSdkVersion ?: 0
        val vcode = if (android.os.Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
        val sig = try {
            val digest = MessageDigest.getInstance("SHA-256")
            pi.signatures?.firstOrNull()?.let { digest.digest(it.toByteArray()).joinToString("") { b -> String.format("%02x", b) } } ?: "—"
        } catch (_: Exception) { "—" }
        return ApkInfo(label, pi.packageName ?: "—", pi.versionName ?: "—", vcode, min, target, perms.sorted(), sig)
    }

    // ---- media ----
    fun mediaMeta(ctx: Context, uri: Uri): List<Pair<String, String>> {
        val out = ArrayList<Pair<String, String>>()
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(ctx, uri)
            fun add(label: String, key: Int, suffix: String = "") {
                val v = r.extractMetadata(key); if (!v.isNullOrBlank()) out.add(label to (v + suffix))
            }
            val durMs = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            if (durMs != null) out.add("Duration" to formatMs(durMs))
            add("Title", MediaMetadataRetriever.METADATA_KEY_TITLE)
            add("Artist", MediaMetadataRetriever.METADATA_KEY_ARTIST)
            add("Album", MediaMetadataRetriever.METADATA_KEY_ALBUM)
            add("Bitrate", MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val hgt = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            if (!w.isNullOrBlank() && !hgt.isNullOrBlank()) out.add("Resolution" to "$w × $hgt")
        } catch (_: Exception) {} finally { try { r.release() } catch (_: Exception) {} }
        return out
    }

    fun videoFrame(ctx: Context, uri: Uri): Bitmap? {
        val r = MediaMetadataRetriever()
        return try { r.setDataSource(ctx, uri); r.getFrameAtTime(0) } catch (_: Exception) { null } finally { try { r.release() } catch (_: Exception) {} }
    }

    // ---- low-level + formatting ----
    private fun readBytes(ctx: Context, uri: Uri, maxBytes: Int): ByteArray {
        return try {
            ctx.contentResolver.openInputStream(uri)?.use { ins ->
                val bos = java.io.ByteArrayOutputStream()
                val buf = ByteArray(32 * 1024); var total = 0
                while (total < maxBytes) {
                    val r = ins.read(buf); if (r <= 0) break
                    bos.write(buf, 0, r); total += r
                }
                bos.toByteArray()
            } ?: ByteArray(0)
        } catch (_: Exception) { ByteArray(0) }
    }

    private fun looksLikeText(b: ByteArray): Boolean {
        if (b.isEmpty()) return false
        var printable = 0
        val n = minOf(b.size, 512)
        for (i in 0 until n) {
            val c = b[i].toInt() and 0xFF
            if (c == 0) return false // a NUL byte → treat as binary
            if (c in 0x20..0x7E || c == 0x09 || c == 0x0A || c == 0x0D) printable++
        }
        return printable.toDouble() / n > 0.85
    }

    private fun textLabel(ext: String): String = when (ext) {
        "md" -> "Markdown"; "log" -> "Log file"; "kt" -> "Kotlin source"; "java" -> "Java source"
        "py" -> "Python source"; "js", "ts" -> "JavaScript/TS source"; "html", "htm" -> "HTML"
        "css" -> "CSS"; "sh" -> "Shell script"; "yml", "yaml" -> "YAML"; "ini", "cfg", "conf" -> "Config"
        "" -> "Text"; else -> "${ext.uppercase()} text"
    }

    private fun formatMs(ms: Long): String {
        val s = ms / 1000; return String.format("%d:%02d", s / 60, s % 60)
    }

    fun parseCsv(text: String, sep: Char = ','): List<List<String>> {
        val rows = ArrayList<List<String>>()
        val row = ArrayList<String>()
        val field = StringBuilder()
        var inQuotes = false; var i = 0
        while (i < text.length) {
            val c = text[i]
            when {
                inQuotes -> when {
                    c == '"' && i + 1 < text.length && text[i + 1] == '"' -> { field.append('"'); i++ }
                    c == '"' -> inQuotes = false
                    else -> field.append(c)
                }
                c == '"' -> inQuotes = true
                c == sep -> { row.add(field.toString()); field.setLength(0) }
                c == '\n' -> { row.add(field.toString()); field.setLength(0); rows.add(ArrayList(row)); row.clear() }
                c == '\r' -> {}
                else -> field.append(c)
            }
            i++
            if (rows.size >= 1000) break
        }
        if (field.isNotEmpty() || row.isNotEmpty()) { row.add(field.toString()); rows.add(ArrayList(row)) }
        return rows
    }

    private fun prettyJson(src: String): String {
        val sb = StringBuilder(); var indent = 0; var inStr = false; var i = 0
        fun nl() { sb.append('\n'); repeat(indent) { sb.append("  ") } }
        while (i < src.length) {
            val c = src[i]
            if (inStr) { sb.append(c); if (c == '\\' && i + 1 < src.length) { sb.append(src[i + 1]); i++ } else if (c == '"') inStr = false }
            else when (c) {
                '"' -> { inStr = true; sb.append(c) }
                '{', '[' -> { sb.append(c); indent++; nl() }
                '}', ']' -> { indent--; nl(); sb.append(c) }
                ',' -> { sb.append(c); nl() }
                ':' -> sb.append(": ")
                ' ', '\t', '\n', '\r' -> {}
                else -> sb.append(c)
            }
            i++
        }
        return sb.toString()
    }

    private fun prettyXml(src: String): String {
        val sb = StringBuilder(); var indent = 0; var i = 0
        val t = src.replace(">", ">\n").replace("<", "\n<")
        for (line in t.split("\n")) {
            val l = line.trim(); if (l.isEmpty()) continue
            if (l.startsWith("</")) indent = maxOf(0, indent - 1)
            repeat(indent) { sb.append("  ") }; sb.append(l).append('\n')
            if (l.startsWith("<") && !l.startsWith("</") && !l.endsWith("/>") && !l.startsWith("<?") && !l.startsWith("<!") && l.contains(">") && !l.substringAfter(">").isNotBlank()) indent++
        }
        return sb.toString()
    }

    /** Try the OS image decoders first; if those can't (RAW, some exotic formats), fall back to the
     *  JPEG preview that cameras embed inside RAW files — that's how you view a RAW on a phone. */
    fun decodeImageSmart(ctx: Context, uri: Uri): Bitmap? {
        loadBitmap(ctx, uri, 2400)?.let { return it }
        return rawEmbeddedPreview(ctx, uri)
    }

    /** Scan the file for the largest embedded JPEG (SOI … EOI) and decode it — works for most RAW. */
    fun rawEmbeddedPreview(ctx: Context, uri: Uri): Bitmap? {
        val b = readBytes(ctx, uri, 24 * 1024 * 1024)
        var best: Bitmap? = null; var bestPx = 0
        var i = 0
        while (i < b.size - 3) {
            if ((b[i].toInt() and 0xFF) == 0xFF && (b[i + 1].toInt() and 0xFF) == 0xD8 && (b[i + 2].toInt() and 0xFF) == 0xFF) {
                var j = i + 2
                while (j < b.size - 1) {
                    if ((b[j].toInt() and 0xFF) == 0xFF && (b[j + 1].toInt() and 0xFF) == 0xD9) { j += 2; break }
                    j++
                }
                val bmp = runCatching { android.graphics.BitmapFactory.decodeByteArray(b, i, j - i) }.getOrNull()
                if (bmp != null && bmp.width * bmp.height > bestPx) { best = bmp; bestPx = bmp.width * bmp.height }
                i = j
            } else i++
        }
        return best
    }

    /** EPUB (and other zip e-books): pull the readable text out of the XHTML, in spine/name order. */
    fun ebookText(ctx: Context, uri: Uri): String {
        return try {
            val entries = zipEntries(ctx, uri).filter { !it.isDir && it.name.substringAfterLast('.', "").lowercase() in setOf("xhtml", "html", "htm") }
            if (entries.isEmpty()) return "(no readable text found — this e-book format isn't supported yet; try “Open with” a reader app)"
            val sb = StringBuilder()
            for (e in entries.take(300)) {
                val bytes = zipEntryBytes(ctx, uri, e.name, 2_000_000) ?: continue
                sb.append(stripHtml(String(bytes, Charsets.UTF_8))).append("\n\n")
                if (sb.length > 2_000_000) break
            }
            sb.toString().trim().ifEmpty { "(this e-book had no extractable text)" }
        } catch (_: Exception) { "(couldn't read this e-book)" }
    }

    private fun stripHtml(html: String): String {
        val noScript = html.replace(Regex("(?is)<(script|style)[^>]*>.*?</\\1>"), " ")
        val text = noScript.replace(Regex("(?is)<(/p|/div|/h[1-6]|br|/li)[^>]*>"), "\n").replace(Regex("(?s)<[^>]+>"), " ")
        return text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&#39;", "'").replace("&quot;", "\"")
            .replace(Regex("[ \\t]+"), " ").replace(Regex("\\n{3,}"), "\n\n")
    }

    private val IMAGE_EXT = setOf("png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "heif", "avif", "avifs",
        "ico", "jp2", "wbmp", "dds", "tga", "targa", "pbm", "pgm", "ppm", "pcx", "ras", "sgi", "xbm", "xpm", "jng", "mng")
    private val RAW_EXT = setOf("3fr", "arw", "bay", "cr2", "cr3", "crw", "dcr", "dng", "erf", "kdc", "mos",
        "mrw", "nef", "nrw", "orf", "pef", "raf", "raw", "rw2", "rwl", "sr2", "srf", "srw", "x3f")
    private val EBOOK_EXT = setOf("epub", "mobi", "azw", "azw3", "pdb", "kf8")
    private val EBOOK_LABEL = mapOf("epub" to "EPUB book", "mobi" to "Mobipocket book", "azw" to "Kindle book",
        "azw3" to "Kindle KF8 book", "pdb" to "Palm book", "kf8" to "Kindle KF8 book")
    private val CSV_EXT = setOf("csv", "tsv", "psv", "ssv")
    private val AUDIO_EXT = setOf("mp3", "wav", "ogg", "oga", "m4a", "flac", "aac", "opus", "amr", "mid", "midi", "mka", "3ga", "ota", "imy")
    private val VIDEO_EXT = setOf("mp4", "mkv", "webm", "avi", "mov", "3gp", "m4v", "ts")
    private val SQLITE_EXT = setOf("db", "sqlite", "sqlite3", "db3")
    private val ARCHIVE_LABEL = mapOf(
        "7z" to "7-Zip archive", "rar" to "RAR archive", "r00" to "RAR archive", "tar" to "TAR archive",
        "gz" to "Gzip archive", "gzip" to "Gzip archive", "tgz" to "Gzipped TAR", "bz2" to "Bzip2 archive",
        "bzip2" to "Bzip2 archive", "tbz" to "Bzip2 TAR", "tbz2" to "Bzip2 TAR", "xz" to "XZ archive",
        "txz" to "XZ TAR", "zst" to "Zstandard archive", "zstd" to "Zstandard archive", "tzst" to "Zstd TAR",
        "lz4" to "LZ4 archive", "lzma" to "LZMA archive", "lzh" to "LZH archive", "lha" to "LZH archive",
        "cab" to "Windows Cabinet", "arj" to "ARJ archive", "cpio" to "CPIO archive", "ar" to "Unix archive",
        "deb" to "Debian package", "rpm" to "RPM package", "cbr" to "Comic Book RAR", "cbz" to "Comic Book ZIP",
        "iso" to "ISO disc image", "dmg" to "macOS disk image", "img" to "Disk image", "vhd" to "Virtual hard disk",
        "vhdx" to "Hyper-V disk", "vmdk" to "VMware disk", "vdi" to "VirtualBox disk", "qcow" to "QEMU disk",
        "qcow2" to "QEMU disk", "wim" to "Windows image", "xar" to "XAR archive", "z" to "Unix compressed",
        "squashfs" to "SquashFS image", "ext4" to "Ext4 image", "ntfs" to "NTFS image", "fat" to "FAT image",
        "hfs" to "HFS+ image", "apfs" to "APFS image", "udf" to "UDF image", "chm" to "Compiled HTML Help")
    private val TEXT_EXT = setOf("txt", "text", "md", "log", "kt", "kts", "java", "py", "js", "ts", "html", "htm",
        "xhtml", "css", "scss", "sass", "less", "sh", "yml", "yaml", "ini", "cfg", "conf", "htaccess", "c", "cpp",
        "cxx", "cppm", "h", "rs", "go", "rb", "rbp", "php", "sql", "gradle", "groovy", "properties", "toml", "env",
        "gitignore", "lua", "swift", "dart", "scala", "pl", "r", "ada", "ahk", "as", "aspx", "bas", "bicep",
        "coffee", "cs", "f", "for", "f90", "haml", "lisp", "m", "makefile", "mk", "nim", "nsi", "pas", "ps1",
        "tcl", "vb", "wat", "xq", "xquery")
}
