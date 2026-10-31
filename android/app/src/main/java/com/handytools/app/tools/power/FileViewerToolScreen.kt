package com.handytools.app.tools.power

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.media.MediaPlayer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.Dataset
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.Memory
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Pause
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Universal File Viewer — "open anything". Hand it any file (from the picker, a share, or the
 * system "Open with" chooser) and it identifies the real type by content and reads it on-device:
 * images, PDFs, text/JSON/XML/CSV, zip-family archives (browse + peek inside), SQLite databases,
 * APKs, audio/video, and a hex/strings view for anything unknown. Nothing is uploaded.
 */
@Composable
fun FileViewerToolScreen(initialUri: Uri? = null) {
    val ctx = LocalContext.current
    var uri by remember { mutableStateOf(initialUri) }
    var meta by remember { mutableStateOf<FileViewer.Meta?>(null) }
    var loading by remember { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { picked ->
        if (picked != null) { uri = picked; meta = null }
    }

    LaunchedEffect(uri) {
        val u = uri ?: return@LaunchedEffect
        loading = true
        meta = withContext(Dispatchers.IO) { runCatching { FileViewer.probe(ctx, u) }.getOrNull() }
        loading = false
    }

    PowerToolPage("fileviewer") {
        HPrimaryButton("Open a file", icon = Icons.Outlined.Folder) { picker.launch(arrayOf("*/*")) }
        NoteText("Any file type — PDF, image, archive, database, APK, code, or something with no extension at all. It's read on your phone; nothing is uploaded. Tenzy also shows up in other apps' “Open with” list.")

        val u = uri
        val m = meta
        if (loading) {
            Box(Modifier.fillMaxWidth().padding(top = HandyTokens.Space24), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = HandyColors.Accent) }
        } else if (u != null && m != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            HeaderCard(u, m)
            Spacer(Modifier.height(HandyTokens.Space12))
            when (m.kind) {
                FileViewer.Kind.IMAGE -> ImageRenderer(u)
                FileViewer.Kind.PDF -> PdfView(u)
                FileViewer.Kind.TEXT, FileViewer.Kind.JSON, FileViewer.Kind.XML -> TextRenderer(u, m.kind)
                FileViewer.Kind.CSV -> CsvRenderer(u)
                FileViewer.Kind.ARCHIVE -> ArchiveRenderer(u)
                FileViewer.Kind.SQLITE -> SqliteRenderer(u)
                FileViewer.Kind.APK -> ApkRenderer(u)
                FileViewer.Kind.AUDIO -> AudioRenderer(u, m)
                FileViewer.Kind.VIDEO -> VideoRenderer(u, m)
                FileViewer.Kind.EBOOK -> EbookRenderer(u)
                FileViewer.Kind.BINARY -> BinaryRenderer(u)
            }
        }
    }
}

/* ---------------- header + actions ---------------- */

@Composable
private fun HeaderCard(uri: Uri, m: FileViewer.Meta) {
    val ctx = LocalContext.current
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(kindIcon(m.kind), null, Modifier.size(34.dp), tint = HandyColors.Accent)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(m.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurface)
                    Text(
                        m.typeLabel + " · " + FileViewer.humanSize(m.size) + (m.detail?.let { " · $it" } ?: ""),
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("↗  Open with", false) { openExternally(ctx, uri, m.mime) }
                HChip("⇪  Share", false) { shareFile(ctx, uri, m.mime) }
            }
        }
    }
}

private fun kindIcon(k: FileViewer.Kind) = when (k) {
    FileViewer.Kind.ARCHIVE -> Icons.Outlined.Folder
    FileViewer.Kind.SQLITE -> Icons.Outlined.Dataset
    FileViewer.Kind.APK -> Icons.Outlined.Memory
    FileViewer.Kind.TEXT, FileViewer.Kind.JSON, FileViewer.Kind.XML, FileViewer.Kind.CSV -> Icons.Outlined.Article
    else -> Icons.Outlined.InsertDriveFile
}

private fun openExternally(ctx: android.content.Context, uri: Uri, mime: String) {
    try {
        val i = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime.ifEmpty { "*/*" }).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(Intent.createChooser(i, "Open with").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: Exception) {}
}

private fun shareFile(ctx: android.content.Context, uri: Uri, mime: String) {
    try {
        val i = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uri).setType(mime.ifEmpty { "*/*" }).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        ctx.startActivity(Intent.createChooser(i, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: Exception) {}
}

/* ---------------- a bounded, scrollable mono panel used by text/hex ---------------- */

@Composable
private fun MonoPanel(text: String, lineNumbers: Boolean = false, maxHeight: Int = 460) {
    val scrollV = rememberScrollState()
    val scrollH = rememberScrollState()
    Box(
        Modifier.fillMaxWidth().heightIn(max = maxHeight.dp).clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp))
            .verticalScroll(scrollV)
    ) {
        Row(Modifier.horizontalScroll(scrollH).padding(10.dp)) {
            if (lineNumbers) {
                val lines = text.count { it == '\n' } + 1
                Text((1..lines).joinToString("\n"), style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace, color = Handy.palette.textSecondary, textAlign = androidx.compose.ui.text.style.TextAlign.End, modifier = Modifier.padding(end = 10.dp))
            }
            Text(text, style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurface, softWrap = false)
        }
    }
}

/* ---------------- renderers ---------------- */

@Composable
private fun ImageRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var bmp by remember(uri) { mutableStateOf<Bitmap?>(null) }
    var done by remember(uri) { mutableStateOf(false) }
    LaunchedEffect(uri) { bmp = withContext(Dispatchers.IO) { FileViewer.decodeImageSmart(ctx, uri) }; done = true }
    var scale by remember { mutableStateOf(1f) }
    var ox by remember { mutableStateOf(0f) }
    var oy by remember { mutableStateOf(0f) }
    val b = bmp
    Box(
        Modifier.fillMaxWidth().height(380.dp).clip(RoundedCornerShape(12.dp)).background(HandyColors.SurfaceDark)
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    scale = (scale * zoom).coerceIn(1f, 6f)
                    ox += pan.x; oy += pan.y
                    if (scale == 1f) { ox = 0f; oy = 0f }
                }
            },
        contentAlignment = Alignment.Center
    ) {
        when {
            b != null -> Image(b.asImageBitmap(), "Image preview", Modifier.fillMaxWidth().graphicsLayer(scaleX = scale, scaleY = scale, translationX = ox, translationY = oy))
            !done -> CircularProgressIndicator(color = HandyColors.Accent)
            else -> Text("This device can't decode this image format — try “Open with” above.", style = MaterialTheme.typography.bodySmall, color = androidx.compose.ui.graphics.Color.White, modifier = Modifier.padding(24.dp))
        }
    }
    if (b != null) NoteText("Pinch to zoom, drag to pan.")
}

@Composable
private fun PdfView(uri: Uri) {
    val ctx = LocalContext.current
    var page by remember(uri) { mutableStateOf(0) }
    var count by remember(uri) { mutableStateOf(0) }
    var bmp by remember(uri) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(uri, page) {
        bmp = withContext(Dispatchers.IO) {
            runCatching {
                ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                    PdfRenderer(pfd).use { r ->
                        count = r.pageCount
                        if (page !in 0 until r.pageCount) return@use null
                        r.openPage(page).use { p ->
                            val w = 1400; val h = (w.toFloat() / p.width * p.height).toInt().coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(android.graphics.Color.WHITE)
                            p.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            bitmap
                        }
                    }
                }
            }.getOrNull()
        }
    }
    val b = bmp
    Box(Modifier.fillMaxWidth().heightIn(min = 240.dp, max = 560.dp).clip(RoundedCornerShape(12.dp)).background(HandyColors.SurfaceDark), contentAlignment = Alignment.Center) {
        if (b != null) Image(b.asImageBitmap(), "PDF page ${page + 1}", Modifier.fillMaxWidth().verticalScroll(rememberScrollState()))
        else CircularProgressIndicator(color = HandyColors.Accent)
    }
    if (count > 0) {
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            HSecondaryButton("‹ Prev", Modifier.weight(1f), enabled = page > 0) { if (page > 0) page-- }
            Text("Page ${page + 1} / $count", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            HSecondaryButton("Next ›", Modifier.weight(1f), enabled = page < count - 1) { if (page < count - 1) page++ }
        }
    }
}

@Composable
private fun TextRenderer(uri: Uri, kind: FileViewer.Kind) {
    val ctx = LocalContext.current
    var text by remember(uri) { mutableStateOf<String?>(null) }
    var truncated by remember(uri) { mutableStateOf(false) }
    LaunchedEffect(uri) {
        val r = withContext(Dispatchers.IO) { FileViewer.textHead(ctx, uri, kind) }
        text = r.first; truncated = r.second
    }
    val t = text
    if (t == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    MonoPanel(t, lineNumbers = kind == FileViewer.Kind.TEXT)
    if (truncated) NoteText("Showing the first part of a large file.")
}

@Composable
private fun CsvRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var rows by remember(uri) { mutableStateOf<List<List<String>>?>(null) }
    LaunchedEffect(uri) { rows = withContext(Dispatchers.IO) { FileViewer.csvRows(ctx, uri) } }
    val data = rows
    if (data == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    if (data.isEmpty()) { NoteText("No rows found."); return }
    val scrollV = rememberScrollState(); val scrollH = rememberScrollState()
    Box(Modifier.fillMaxWidth().heightIn(max = 460.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).verticalScroll(scrollV)) {
        Column(Modifier.horizontalScroll(scrollH).padding(8.dp)) {
            data.forEachIndexed { ri, row ->
                Row {
                    row.forEach { cell ->
                        Text(
                            cell, style = MaterialTheme.typography.bodySmall,
                            fontWeight = if (ri == 0) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (ri == 0) HandyColors.Accent else MaterialTheme.colorScheme.onSurface,
                            maxLines = 1, modifier = Modifier.width(130.dp).padding(horizontal = 6.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }
    }
    NoteText("${data.size} row${if (data.size == 1) "" else "s"} · scroll sideways for more columns.")
}

@Composable
private fun ArchiveRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var entries by remember(uri) { mutableStateOf<List<FileViewer.ZEntry>?>(null) }
    var peekName by remember(uri) { mutableStateOf<String?>(null) }
    var peekText by remember(uri) { mutableStateOf<String?>(null) }
    var peekBmp by remember(uri) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(uri) { entries = withContext(Dispatchers.IO) { runCatching { FileViewer.zipEntries(ctx, uri) }.getOrNull() ?: emptyList() } }
    val list = entries
    if (list == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    SectionLabel("${list.count { !it.isDir }} files in this archive")
    Box(Modifier.fillMaxWidth().heightIn(max = 420.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).verticalScroll(rememberScrollState())) {
        Column(Modifier.padding(4.dp)) {
            list.take(600).forEach { e ->
                Row(
                    Modifier.fillMaxWidth().clickable(enabled = !e.isDir) {
                        peekName = e.name; peekText = null; peekBmp = null
                    }.padding(horizontal = 8.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(if (e.isDir) "📁" else "📄", fontSize = 15.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(e.name, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
                    if (!e.isDir) Text(FileViewer.humanSize(e.size), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                }
            }
            if (list.size > 600) Text("…and ${list.size - 600} more", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(8.dp))
        }
    }
    val pn = peekName
    if (pn != null) {
        LaunchedEffect(pn) {
            val bytes = withContext(Dispatchers.IO) { FileViewer.zipEntryBytes(ctx, uri, pn, 1_000_000) }
            if (bytes != null) {
                val ext = pn.substringAfterLast('.', "").lowercase()
                if (ext in setOf("png", "jpg", "jpeg", "gif", "webp", "bmp")) {
                    peekBmp = withContext(Dispatchers.IO) { runCatching { android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }.getOrNull() }
                } else {
                    peekText = String(bytes, Charsets.UTF_8)
                }
            } else peekText = "(couldn't read this entry)"
        }
        Spacer(Modifier.height(10.dp))
        SectionLabel("Inside: ${pn.substringAfterLast('/')}")
        val pb = peekBmp; val pt = peekText
        when {
            pb != null -> Image(pb.asImageBitmap(), "Archive image", Modifier.fillMaxWidth().heightIn(max = 320.dp).clip(RoundedCornerShape(10.dp)).background(HandyColors.SurfaceDark))
            pt != null -> MonoPanel(pt.take(60_000), maxHeight = 320)
            else -> CircularProgressIndicator(color = HandyColors.Accent)
        }
    }
}

@Composable
private fun SqliteRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var dbFile by remember(uri) { mutableStateOf<File?>(null) }
    var tables by remember(uri) { mutableStateOf<List<Pair<String, Int>>?>(null) }
    var selected by remember(uri) { mutableStateOf<String?>(null) }
    var cols by remember(uri) { mutableStateOf<List<String>>(emptyList()) }
    var rows by remember(uri) { mutableStateOf<List<List<String>>>(emptyList()) }
    LaunchedEffect(uri) {
        val f = withContext(Dispatchers.IO) { FileViewer.copyToCache(ctx, uri, "db") }
        dbFile = f
        tables = if (f != null) withContext(Dispatchers.IO) { FileViewer.sqliteTables(f) } else emptyList()
    }
    val tl = tables
    if (tl == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    if (tl.isEmpty()) { NoteText("No readable tables (the file may be encrypted or not a database)."); return }
    SectionLabel("${tl.size} table${if (tl.size == 1) "" else "s"}")
    Box(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            tl.forEach { (name, n) -> HChip("$name · $n", selected == name) { selected = name } }
        }
    }
    val sel = selected; val f = dbFile
    if (sel != null && f != null) {
        LaunchedEffect(sel) {
            val r = withContext(Dispatchers.IO) { FileViewer.sqliteRows(f, sel, 100) }
            cols = r.first; rows = r.second
        }
        Spacer(Modifier.height(8.dp))
        if (cols.isEmpty()) { NoteText("(empty)"); return }
        val sv = rememberScrollState(); val sh = rememberScrollState()
        Box(Modifier.fillMaxWidth().heightIn(max = 420.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).verticalScroll(sv)) {
            Column(Modifier.horizontalScroll(sh).padding(8.dp)) {
                Row { cols.forEach { Text(it, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = HandyColors.Accent, maxLines = 1, modifier = Modifier.width(140.dp).padding(horizontal = 6.dp, vertical = 4.dp)) } }
                rows.forEach { row -> Row { row.forEach { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(140.dp).padding(horizontal = 6.dp, vertical = 4.dp)) } } }
            }
        }
        NoteText("First ${rows.size} row${if (rows.size == 1) "" else "s"} of \"$sel\".")
    }
}

@Composable
private fun ApkRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var info by remember(uri) { mutableStateOf<FileViewer.ApkInfo?>(null) }
    var failed by remember(uri) { mutableStateOf(false) }
    LaunchedEffect(uri) {
        val f = withContext(Dispatchers.IO) { FileViewer.copyToCache(ctx, uri, "apk") }
        val i = if (f != null) withContext(Dispatchers.IO) { FileViewer.apkInfo(ctx, f) } else null
        info = i; failed = i == null
    }
    val a = info
    if (failed) { NoteText("Couldn't parse this APK."); return }
    if (a == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            kv("App", a.label); kv("Package", a.pkg); kv("Version", "${a.versionName} (${a.versionCode})")
            kv("Min / Target SDK", "${a.minSdk} / ${a.targetSdk}")
            kv("Signature (SHA-256)", a.signature)
        }
    }
    Spacer(Modifier.height(10.dp))
    SectionLabel("${a.permissions.size} permission${if (a.permissions.size == 1) "" else "s"}")
    Box(Modifier.fillMaxWidth().heightIn(max = 300.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).verticalScroll(rememberScrollState())) {
        Column(Modifier.padding(10.dp)) {
            if (a.permissions.isEmpty()) Text("None requested.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            a.permissions.forEach { Text("• ${it.substringAfterLast('.')}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(vertical = 2.dp)) }
        }
    }
}

@Composable
private fun AudioRenderer(uri: Uri, m: FileViewer.Meta) {
    val ctx = LocalContext.current
    var meta by remember(uri) { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var playing by remember(uri) { mutableStateOf(false) }
    val player = remember(uri) { MediaPlayer() }
    LaunchedEffect(uri) {
        meta = withContext(Dispatchers.IO) { FileViewer.mediaMeta(ctx, uri) }
        runCatching { player.setDataSource(ctx, uri); player.prepare() }
    }
    DisposableEffect(uri) { onDispose { runCatching { player.stop(); player.release() } } }
    HPrimaryButton(if (playing) "Pause" else "Play", icon = if (playing) Icons.Outlined.Pause else Icons.Outlined.PlayArrow) {
        runCatching { if (playing) player.pause() else player.start(); playing = !playing }
    }
    if (meta.isNotEmpty()) {
        Spacer(Modifier.height(10.dp))
        HCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(14.dp)) { meta.forEach { kv(it.first, it.second) } } }
    }
}

@Composable
private fun VideoRenderer(uri: Uri, m: FileViewer.Meta) {
    val ctx = LocalContext.current
    var frame by remember(uri) { mutableStateOf<Bitmap?>(null) }
    var meta by remember(uri) { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    LaunchedEffect(uri) {
        frame = withContext(Dispatchers.IO) { FileViewer.videoFrame(ctx, uri) }
        meta = withContext(Dispatchers.IO) { FileViewer.mediaMeta(ctx, uri) }
    }
    val f = frame
    Box(Modifier.fillMaxWidth().height(320.dp).clip(RoundedCornerShape(12.dp)).background(HandyColors.SurfaceDark), contentAlignment = Alignment.Center) {
        if (f != null) Image(f.asImageBitmap(), "Video still", Modifier.fillMaxWidth())
        Icon(Icons.Outlined.PlayArrow, "Play", Modifier.size(56.dp), tint = androidx.compose.ui.graphics.Color.White)
    }
    Spacer(Modifier.height(8.dp))
    HPrimaryButton("Play video", icon = Icons.Outlined.OpenInNew) { openExternally(ctx, uri, m.mime) }
    if (meta.isNotEmpty()) {
        Spacer(Modifier.height(10.dp))
        HCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(14.dp)) { meta.forEach { kv(it.first, it.second) } } }
    }
}

@Composable
private fun EbookRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var text by remember(uri) { mutableStateOf<String?>(null) }
    LaunchedEffect(uri) { text = withContext(Dispatchers.IO) { FileViewer.ebookText(ctx, uri) } }
    val t = text
    if (t == null) { CircularProgressIndicator(color = HandyColors.Accent); return }
    Box(
        Modifier.fillMaxWidth().heightIn(max = 520.dp).clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp))
            .verticalScroll(rememberScrollState())
    ) {
        Text(t, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(16.dp), lineHeight = 22.sp)
    }
    NoteText("Reading the book's text on-device. Tap “Open with” for a full e-reader.")
}

@Composable
private fun BinaryRenderer(uri: Uri) {
    val ctx = LocalContext.current
    var showStrings by remember(uri) { mutableStateOf(false) }
    var hex by remember(uri) { mutableStateOf<String?>(null) }
    var strings by remember(uri) { mutableStateOf<List<String>?>(null) }
    var hashes by remember(uri) { mutableStateOf<Map<String, String>?>(null) }
    var computing by remember(uri) { mutableStateOf(false) }
    LaunchedEffect(uri) {
        hex = withContext(Dispatchers.IO) { FileViewer.hexDump(ctx, uri) }
        strings = withContext(Dispatchers.IO) { FileViewer.strings(ctx, uri) }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        HChip("Hex", !showStrings) { showStrings = false }
        HChip("Strings", showStrings) { showStrings = true }
    }
    Spacer(Modifier.height(8.dp))
    if (!showStrings) {
        val h = hex
        if (h == null) CircularProgressIndicator(color = HandyColors.Accent) else MonoPanel(h)
    } else {
        val s = strings
        if (s == null) CircularProgressIndicator(color = HandyColors.Accent)
        else MonoPanel(if (s.isEmpty()) "(no printable strings found)" else s.joinToString("\n"))
    }
    Spacer(Modifier.height(10.dp))
    val hh = hashes
    if (hh == null) {
        HSecondaryButton(if (computing) "Computing…" else "Compute checksums", enabled = !computing) {
            computing = true
        }
        if (computing) LaunchedEffect(Unit) { hashes = withContext(Dispatchers.IO) { FileViewer.hashes(ctx, uri) }; computing = false }
    } else {
        HCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(14.dp)) { hh.forEach { kv(it.key, it.value) } } }
    }
}

/* ---------------- tiny shared row ---------------- */

@Composable
private fun kv(label: String, value: String) {
    Column(Modifier.padding(vertical = 4.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
        Text(value, style = MaterialTheme.typography.bodySmall, fontFamily = if (label.contains("SHA") || label.contains("MD5")) FontFamily.Monospace else FontFamily.Default, color = MaterialTheme.colorScheme.onSurface)
    }
}
