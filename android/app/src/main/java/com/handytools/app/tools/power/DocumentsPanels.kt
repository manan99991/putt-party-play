package com.handytools.app.tools.power

import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowDownward
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.FolderOpen
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

// ------------------------------------------------------------------------------------------------
// Merge & split
// ------------------------------------------------------------------------------------------------

internal class DocMergeState {
    val files = mutableStateListOf<DocPdfInfo>()
    var working by mutableStateOf(false)
    var status by mutableStateOf<String?>(null)
    var range by mutableStateOf("")
}

@Composable
internal fun DocMergePanel(st: DocMergeState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val hasRoom = Usage.hasRoom(ctx, "pdftools", Limits.FREE_PDF_OPS_PER_DAY)

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        st.working = true; st.status = null
        scope.launch {
            val infos = withContext(Dispatchers.IO) { uris.map { DocEngine.pdfInfo(ctx, it) } }
            val bad = infos.count { it.pages == 0 }
            st.files += infos.filter { it.pages > 0 }
            st.status = if (bad > 0) "Skipped $bad file${if (bad > 1) "s" else ""} that couldn't be read as PDF." else null
            st.working = false
        }
    }

    fun runOp(label: String, mime: String, block: suspend () -> List<File>) {
        if (st.working) return
        st.working = true; st.status = "$label…"
        scope.launch {
            val out = withContext(Dispatchers.IO) { try { block() } catch (_: Exception) { emptyList() } }
            st.working = false
            if (out.isEmpty()) { st.status = "Couldn't complete that. Check the files and try again."; return@launch }
            Usage.use(ctx, "pdftools", Limits.FREE_PDF_OPS_PER_DAY)
            val total = out.sumOf { it.length() }
            st.status = "Done · ${out.size} file${if (out.size > 1) "s" else ""} · ${DocEngine.prettySize(total)}"
            HandyHaptics.success(ctx)
            Share.files(ctx, out, mime)
        }
    }

    // Preview-first: the stack of picked PDFs.
    if (st.files.isEmpty()) {
        PreviewBox(minHeight = 150.dp) {
            Text(
                if (st.working) "Reading…" else "Pick 2 or more PDFs to merge, or one to split.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(24.dp)
            )
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            st.files.forEachIndexed { i, f ->
                HCard(Modifier.fillMaxWidth()) {
                    Row(Modifier.fillMaxWidth().padding(start = 14.dp, end = 4.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("📄", fontSize = 22.sp)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(f.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text("${f.pages} page${if (f.pages != 1) "s" else ""}${if (f.size > 0) " · ${DocEngine.prettySize(f.size)}" else ""}",
                                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        }
                        IconButton(onClick = { if (i > 0) { val x = st.files.removeAt(i); st.files.add(i - 1, x) } }, enabled = i > 0, modifier = Modifier.size(36.dp)) {
                            Icon(Icons.Outlined.ArrowUpward, "Move up", Modifier.size(18.dp))
                        }
                        IconButton(onClick = { if (i < st.files.lastIndex) { val x = st.files.removeAt(i); st.files.add(i + 1, x) } }, enabled = i < st.files.lastIndex, modifier = Modifier.size(36.dp)) {
                            Icon(Icons.Outlined.ArrowDownward, "Move down", Modifier.size(18.dp))
                        }
                        IconButton(onClick = { st.files.removeAt(i) }, modifier = Modifier.size(36.dp)) {
                            Icon(Icons.Outlined.Close, "Remove", Modifier.size(18.dp))
                        }
                    }
                }
            }
        }
    }

    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HPrimaryButton("＋ Pick PDFs", Modifier.weight(1f), enabled = !st.working) { picker.launch(arrayOf("application/pdf")) }
        HSecondaryButton("Clear list", Modifier.weight(1f), enabled = st.files.isNotEmpty() && !st.working) { st.files.clear(); st.status = null }
    }
    Spacer(Modifier.height(10.dp))
    val one = st.files.size == 1
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HPrimaryButton("Merge → one PDF", Modifier.weight(1f), enabled = st.files.size >= 2 && !st.working && hasRoom) {
            runOp("Merging", "application/pdf") { listOfNotNull(DocEngine.merge(ctx, st.files.map { it.uri })) }
        }
        HSecondaryButton("Split pages", Modifier.weight(1f), enabled = one && !st.working && hasRoom) {
            val f = st.files.first()
            val pages = DocEngine.parseRange(st.range, f.pages)
            runOp(if (pages.isEmpty()) "Splitting into ${f.pages} PDFs" else "Pulling out ${pages.size} page${if (pages.size > 1) "s" else ""}", "application/pdf") {
                DocEngine.split(ctx, f.uri, if (pages.isEmpty()) null else pages)
            }
        }
    }
    if (one) {
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(st.range, { st.range = it }, label = { Text("Pages to keep (optional, e.g. 1-3, 5)") }, singleLine = true,
            placeholder = { Text("Empty = one PDF per page") }, modifier = Modifier.fillMaxWidth())
    }

    Spacer(Modifier.height(10.dp))
    val canChip = st.files.isNotEmpty() && !st.working && hasRoom
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        HChip("Compress", false) {
            if (!canChip) st.status = "Pick a PDF first." else runOp("Compressing", "application/pdf") { st.files.mapNotNull { DocEngine.compress(ctx, it.uri) } }
        }
        HChip("Rotate 90°", false) {
            if (!canChip) st.status = "Pick a PDF first." else runOp("Rotating", "application/pdf") { st.files.mapNotNull { DocEngine.rotate(ctx, it.uri, 90) } }
        }
        HChip("Rotate 180°", false) {
            if (!canChip) st.status = "Pick a PDF first." else runOp("Rotating", "application/pdf") { st.files.mapNotNull { DocEngine.rotate(ctx, it.uri, 180) } }
        }
        HChip("PDF → images", false) {
            if (!canChip) st.status = "Pick a PDF first." else runOp("Rendering pages", "image/jpeg") {
                val out = ArrayList<File>()
                st.files.forEach { out += DocEngine.toImages(ctx, it.uri, 20 - out.size) }
                out
            }
        }
    }
    if (!hasRoom) Text("You've done today's ${Limits.FREE_PDF_OPS_PER_DAY} free PDF jobs. Go Pro for unlimited.",
        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 10.dp)) }
    NoteText("Reorder with the arrows. Everything is rebuilt page by page on the phone; PDF → images shares up to 20 pages as JPEGs.")
}

// ------------------------------------------------------------------------------------------------
// Word Finder
// ------------------------------------------------------------------------------------------------

internal class DocFinderState {
    var query by mutableStateOf("")
    val sources = mutableStateListOf<FinderSource>()
    var docs by mutableStateOf<List<FinderDoc>>(emptyList())
    var indexing by mutableStateOf(false)
    var progress by mutableStateOf("")
    var done by mutableIntStateOf(0)
    var total by mutableIntStateOf(0)
    val saved = mutableStateListOf<SavedPassage>()
    var loaded = false
    var job: Job? = null
}

@Composable
internal fun DocFinderPanel(st: DocFinderState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    fun reindex(force: Boolean = false) {
        st.job?.cancel()
        if (force) WordFinder.invalidate()
        val sources = st.sources.toList()
        if (sources.isEmpty()) { st.docs = emptyList(); st.indexing = false; return }
        st.indexing = true; st.done = 0; st.total = 0; st.progress = "Looking for documents…"
        st.job = scope.launch {
            val docs = withContext(Dispatchers.IO) {
                WordFinder.index(ctx, sources) { d, t, name -> st.done = d; st.total = t; st.progress = if (name.isEmpty()) "" else "Reading $name" }
            }
            st.docs = docs; st.indexing = false; st.progress = ""
        }
    }

    LaunchedEffect(Unit) {
        if (!st.loaded) {
            st.loaded = true
            st.sources.clear(); st.sources += WordFinder.sources(ctx)
            st.saved.clear(); st.saved += WordFinder.savedPassages(ctx)
            reindex()
        }
    }

    fun addSources(list: List<FinderSource>) {
        val fresh = list.filter { s -> st.sources.none { it.uri == s.uri } }
        if (fresh.isEmpty()) { Toast.makeText(ctx, "Already added", Toast.LENGTH_SHORT).show(); return }
        st.sources += fresh
        WordFinder.saveSources(ctx, st.sources.toList())
        reindex(force = true)
    }

    val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        try { ctx.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
        addSources(listOf(FinderSource(uri.toString(), true, WordFinder.treeLabel(uri))))
    }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        val list = uris.map { u ->
            try { ctx.contentResolver.takePersistableUriPermission(u, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
            FinderSource(u.toString(), false, DocEngine.displayName(ctx, u))
        }
        val unsupported = list.count { !WordFinder.isSupported(it.label) }
        if (unsupported > 0) Toast.makeText(ctx, "$unsupported file${if (unsupported > 1) "s" else ""} skipped — PDF, Word, Excel, PowerPoint and text files work here.", Toast.LENGTH_LONG).show()
        addSources(list.filter { WordFinder.isSupported(it.label) })
    }

    fun openDoc(uri: Uri) {
        try {
            ctx.startActivity(Intent(Intent.ACTION_VIEW).setData(uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) { Toast.makeText(ctx, "No app on this phone can open that file.", Toast.LENGTH_SHORT).show() }
    }

    OutlinedTextField(
        st.query, { st.query = it }, modifier = Modifier.fillMaxWidth(), singleLine = true,
        placeholder = { Text("Find a word or phrase across all your documents…") },
        leadingIcon = { Icon(Icons.Outlined.Search, null) },
        trailingIcon = { if (st.query.isNotEmpty()) IconButton(onClick = { st.query = "" }) { Icon(Icons.Outlined.Close, "Clear") } }
    )
    Spacer(Modifier.height(8.dp))
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        HChip("＋ Add folder", false) { folderPicker.launch(null) }
        HChip("＋ Add files", false) { filePicker.launch(arrayOf("*/*")) }
        if (st.sources.isNotEmpty()) HChip("↻ Re-index", false) { reindex(force = true) }
    }

    if (st.indexing) {
        Spacer(Modifier.height(10.dp))
        val frac = if (st.total > 0) st.done.toFloat() / st.total else 0f
        if (st.total > 0) LinearProgressIndicator(progress = { frac }, modifier = Modifier.fillMaxWidth(), color = HandyColors.Accent)
        else LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = HandyColors.Accent)
        Text(
            if (st.total > 0) "Indexing ${st.done} of ${st.total}${if (st.progress.isNotEmpty()) " · ${st.progress}" else ""}" else st.progress,
            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp), maxLines = 1, overflow = TextOverflow.Ellipsis
        )
    }

    Spacer(Modifier.height(6.dp))
    val hits = remember(st.query, st.docs) { WordFinder.search(st.docs, st.query) }
    if (st.sources.isEmpty()) {
        EmptyState(Icons.Outlined.FolderOpen, "Nothing indexed yet.", "Add a folder or a few files — Tenzy reads them on the phone, nothing is uploaded.")
        Spacer(Modifier.height(HandyTokens.Space16))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HPrimaryButton("Add folder", Modifier.weight(1f)) { folderPicker.launch(null) }
            HSecondaryButton("Add files", Modifier.weight(1f)) { filePicker.launch(arrayOf("*/*")) }
        }
        Text("Searches every PDF, Word, Excel, PowerPoint and text file you add — no account, nothing uploaded.",
            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 12.dp))
    } else if (st.query.isBlank()) {
        val noText = st.docs.count { it.noText }
        PreviewBox(minHeight = 110.dp) {
            Text(
                if (st.indexing && st.docs.isEmpty()) "Reading your documents…"
                else "${st.docs.size} document${if (st.docs.size != 1) "s" else ""} indexed" + (if (noText > 0) " · $noText scanned PDF${if (noText > 1) "s" else ""} had no text layer" else "") + ".\nType a word or phrase.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(20.dp)
            )
        }
    } else if (hits.isEmpty()) {
        PreviewBox(minHeight = 110.dp) {
            Text(if (st.indexing) "Still indexing — results appear as files are read." else "No matches for “${st.query.trim()}”.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(20.dp))
        }
    } else {
        val files = hits.map { it.doc.uri }.distinct().size
        SectionLabel("${hits.size}${if (hits.size >= 80) "+" else ""} passage${if (hits.size > 1) "s" else ""} in $files file${if (files > 1) "s" else ""}")
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            hits.forEach { hit ->
                HCard(Modifier.fillMaxWidth(), onClick = { openDoc(hit.doc.uri) }) {
                    Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.Top) {
                        Text(iconFor(hit.doc.name), fontSize = 20.sp)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(hit.doc.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(
                                buildAnnotatedString {
                                    append(hit.snippet)
                                    addStyle(SpanStyle(background = HandyColors.Accent.copy(alpha = 0.28f), fontWeight = FontWeight.SemiBold), hit.matchStart, hit.matchEnd.coerceAtMost(hit.snippet.length))
                                },
                                style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 3.dp)
                            )
                        }
                        Spacer(Modifier.width(6.dp))
                        HChip("Save", false) {
                            st.saved.add(0, SavedPassage(hit.doc.name, hit.doc.uri.toString(), hit.snippet))
                            WordFinder.saveSaved(ctx, st.saved.toList())
                            Toast.makeText(ctx, "Passage saved", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
        }
    }

    // Indexed sources, removable.
    if (st.sources.isNotEmpty()) {
        SectionLabel("Indexed")
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            st.sources.forEach { s ->
                HChip("${if (s.tree) "📁 " else ""}${s.label.ifBlank { "Source" }}  ✕", false) {
                    st.sources.remove(s)
                    WordFinder.saveSources(ctx, st.sources.toList())
                    try { ctx.contentResolver.releasePersistableUriPermission(Uri.parse(s.uri), Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
                    reindex(force = true)
                }
            }
        }
    }

    SectionLabel("Saved passages")
    if (st.saved.isEmpty()) {
        Text("Nothing saved yet.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(start = 2.dp))
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            st.saved.forEachIndexed { i, s ->
                HCard(Modifier.fillMaxWidth(), onClick = { openDoc(Uri.parse(s.uri)) }) {
                    Row(Modifier.fillMaxWidth().padding(start = 12.dp, top = 10.dp, bottom = 10.dp, end = 2.dp), verticalAlignment = Alignment.Top) {
                        Text("🔖", fontSize = 20.sp)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(s.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(s.passage, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 3.dp))
                        }
                        IconButton(onClick = { st.saved.removeAt(i); WordFinder.saveSaved(ctx, st.saved.toList()) }, modifier = Modifier.size(36.dp)) {
                            Icon(Icons.Outlined.Close, "Remove", Modifier.size(18.dp))
                        }
                    }
                }
            }
        }
    }
    NoteText("Tap a result to open the file. Scanned PDFs without a text layer get a quick on-device OCR of their first pages.")
}

private fun iconFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
    "pdf" -> "📕"
    "xlsx", "csv" -> "📗"
    "pptx" -> "📙"
    else -> "📘"
}
