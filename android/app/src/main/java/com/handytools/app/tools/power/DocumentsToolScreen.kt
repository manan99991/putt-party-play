package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material.icons.outlined.Draw
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

// ------------------------------------------------------------------------------------------------
// Documents — Scan / Sign & fill / Merge & split / Word Finder. State is hoisted here so switching
// tabs never loses the pages, signature or picked files (the prototype keeps every panel alive).
// ------------------------------------------------------------------------------------------------

internal class ScanState {
    val pages = mutableStateListOf<ScanPage>()
    var current by mutableIntStateOf(-1)
    var filter by mutableStateOf(ScanFilter.COLOR)
    var status by mutableStateOf<String?>(null)
    var working by mutableStateOf(false)
}

internal class SignState {
    var uri by mutableStateOf<Uri?>(null)
    var isPdf by mutableStateOf(false)
    var pageCount by mutableIntStateOf(0)
    var pageIndex by mutableIntStateOf(0)
    var page by mutableStateOf<Bitmap?>(null)
    val items = mutableStateMapOf<Int, List<Placed>>()
    val strokes = mutableStateListOf<List<Offset>>()
    var pending by mutableStateOf<Placed?>(null)
    var name by mutableStateOf("")
    var status by mutableStateOf<String?>(null)
    var loading by mutableStateOf(false)
}

@Composable
fun DocumentsToolScreen() {
    var tab by remember { mutableIntStateOf(0) }
    val scan = remember { ScanState() }
    val sign = remember { SignState() }
    val merge = remember { MergeState() }
    val finder = remember { FinderState() }
    PowerToolPage("documents", listOf("Scan", "Sign & fill", "Merge & split", "Word Finder"), tab, { tab = it }) {
        when (tab) {
            0 -> ScanPanel(scan)
            1 -> SignPanel(sign)
            2 -> MergePanel(merge)
            else -> FinderPanel(finder)
        }
    }
}

// ------------------------------------------------------------------------------------------------
// Scan
// ------------------------------------------------------------------------------------------------

@Composable
private fun ScanPanel(st: ScanState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val hasRoom = Usage.hasRoom(ctx, "scan", Limits.FREE_SCAN_PAGES)

    fun addPages(uris: List<Uri>) {
        if (uris.isEmpty()) return
        st.working = true
        scope.launch {
            val bitmaps = withContext(Dispatchers.IO) { uris.mapNotNull { DocEngine.loadBitmap(ctx, it) } }
            bitmaps.forEach { st.pages += ScanPage(it) }
            if (bitmaps.isNotEmpty()) st.current = st.pages.lastIndex
            st.status = if (bitmaps.isEmpty()) "Couldn't read that image — try another." else "Page ${st.pages.size} added"
            st.working = false
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        val result = GmsDocumentScanningResult.fromActivityResultIntent(res.data)
        addPages(result?.pages?.map { it.imageUri } ?: emptyList())
    }
    val libraryPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(10)) { addPages(it) }

    fun scan() {
        val activity = DocEngine.findActivity(ctx)
        if (activity == null) { libraryPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)); return }
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(10)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender -> scanLauncher.launch(IntentSenderRequest.Builder(sender).build()) }
            .addOnFailureListener {
                st.status = "The camera scanner isn't available on this phone — pick a photo from Library instead."
                libraryPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
    }

    val page = st.pages.getOrNull(st.current)
    val shown by produceState<Bitmap?>(null, page, st.filter, page?.rotation) {
        value = if (page == null) null else withContext(Dispatchers.Default) { DocEngine.process(page.source, page.rotation, st.filter) }
    }

    // Preview-first: the current page, big.
    if (page == null) {
        PreviewBox(minHeight = 190.dp) {
            Text("Scan a page — edges are found automatically.", color = Handy.palette.textSecondary,
                style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(24.dp))
        }
    } else {
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface), contentAlignment = Alignment.Center) {
            val bmp = shown
            if (bmp != null) Image(bmp.asImageBitmap(), "Page ${st.current + 1}", Modifier.fillMaxWidth().aspectRatio(bmp.width.toFloat() / bmp.height), contentScale = ContentScale.Fit)
            else Box(Modifier.fillMaxWidth().height(220.dp))
        }
    }

    // Page strip.
    if (st.pages.isNotEmpty()) {
        Spacer(Modifier.height(10.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            itemsIndexed(st.pages) { i, p ->
                val thumb = remember(p) { DocEngine.thumbnail(p.source) }
                Box(
                    Modifier.size(56.dp, 74.dp).clip(RoundedCornerShape(8.dp))
                        .border(if (i == st.current) 2.dp else 1.dp, if (i == st.current) HandyColors.Accent else Handy.palette.border, RoundedCornerShape(8.dp))
                        .background(Color.White)
                        .pointerInput(i) { detectTapGestures { st.current = i } },
                    contentAlignment = Alignment.Center
                ) { Image(thumb.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
            }
        }
    }

    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HPrimaryButton(if (st.pages.isEmpty()) "Scan page" else "Add page", Modifier.weight(1f), enabled = !st.working, icon = Icons.Outlined.DocumentScanner) { scan() }
        HSecondaryButton("Library", Modifier.weight(1f), enabled = !st.working) {
            libraryPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }

    Spacer(Modifier.height(10.dp))
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        ScanFilter.values().forEach { f -> HChip(f.label, st.filter == f) { st.filter = f } }
        HChip("↻ Rotate", false) {
            val i = st.current
            if (i in st.pages.indices) { val p = st.pages[i]; st.pages[i] = ScanPage(p.source, (p.rotation + 90) % 360) }
            else st.status = "Scan or pick a page first."
        }
        HChip("Remove page", false) {
            val i = st.current
            if (i in st.pages.indices) { st.pages.removeAt(i); st.current = minOf(i, st.pages.lastIndex); st.status = "Page removed" }
            else st.status = "Nothing to remove yet."
        }
    }

    Spacer(Modifier.height(12.dp))
    val n = st.pages.size
    HPrimaryButton(
        if (st.working) "Working…" else if (n == 0) "Export PDF (searchable)" else "Export PDF ($n page${if (n > 1) "s" else ""}, searchable)",
        enabled = n > 0 && !st.working && hasRoom
    ) {
        st.working = true; st.status = "Recognising text…"
        scope.launch {
            val file = withContext(Dispatchers.Default) {
                val bitmaps = st.pages.map { DocEngine.process(it.source, it.rotation, st.filter) }
                DocEngine.exportSearchablePdf(ctx, bitmaps)
            }
            st.working = false
            if (file != null) {
                Usage.use(ctx, "scan", Limits.FREE_SCAN_PAGES)
                st.status = "PDF exported · ${DocEngine.prettySize(file.length())}"
                HandyHaptics.success(ctx)
                Share.file(ctx, file, "application/pdf")
            } else st.status = "Couldn't write the PDF. Try again, or remove a page."
        }
    }
    if (!hasRoom) Text("You've used today's ${Limits.FREE_SCAN_PAGES} free exports. Go Pro for unlimited.",
        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 10.dp)) }
    NoteText("Edge detection and the text layer run on the phone. The PDF is searchable — the recognised text sits invisibly under each page.")
}

// ------------------------------------------------------------------------------------------------
// Sign & fill
// ------------------------------------------------------------------------------------------------

@Composable
private fun SignPanel(st: SignState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val ink = Color(0xFF14148A)
    val hasRoom = Usage.hasRoom(ctx, "sign", Limits.FREE_SIGN_PER_DAY)

    fun loadPage(index: Int) {
        val uri = st.uri ?: return
        st.loading = true
        scope.launch {
            val bmp = withContext(Dispatchers.IO) { DocEngine.loadPage(ctx, uri, st.isPdf, index) }
            st.page = bmp; st.pageIndex = index; st.loading = false
            if (bmp == null) st.status = "Couldn't open that file. Try a PDF or an image."
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        st.loading = true; st.status = null; st.items.clear(); st.pending = null; st.page = null
        scope.launch {
            val info = withContext(Dispatchers.IO) {
                val pdf = DocEngine.isPdf(ctx, uri)
                Pair(pdf, if (pdf) DocEngine.pdfPageCount(ctx, uri) else 1)
            }
            st.uri = uri; st.isPdf = info.first; st.pageCount = info.second
            loadPage(0)
        }
    }

    val page = st.page
    var boxSize by remember { mutableStateOf(IntSize.Zero) }
    var dragId by remember { mutableStateOf<Long?>(null) }
    val pageItems = st.items[st.pageIndex] ?: emptyList()

    fun rectOf(p: Placed, w: Int, h: Int): FloatArray {
        val sig = p.bitmap
        return if (p.isSignature && sig != null) {
            val pw = p.w * w; val ph = pw * sig.height / sig.width
            floatArrayOf(p.cx * w - pw / 2, p.cy * h - ph / 2, p.cx * w + pw / 2, p.cy * h + ph / 2)
        } else {
            val fh = p.textFrac * h; val fw = fh * 0.55f * p.text.length + fh
            floatArrayOf(p.cx * w - fw / 2, p.cy * h - fh * 0.8f, p.cx * w + fw / 2, p.cy * h + fh * 0.8f)
        }
    }

    // Preview-first: the page with everything placed on it.
    if (page == null) {
        PreviewBox(minHeight = 200.dp) {
            Text(
                if (st.loading) "Opening…" else "Pick a PDF or a photo of a form, then sign and fill it right here.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(24.dp)
            )
        }
    } else {
        Box(
            Modifier.fillMaxWidth().aspectRatio(page.width.toFloat() / page.height).clip(RoundedCornerShape(12.dp))
                .background(Color.White).clipToBounds().onSizeChanged { boxSize = it }
                .pointerInput(st.pageIndex, pageItems.size) {
                    detectDragGestures(
                        onDragStart = { o ->
                            dragId = (st.items[st.pageIndex] ?: emptyList()).lastOrNull { p ->
                                val r = rectOf(p, size.width, size.height); o.x >= r[0] && o.x <= r[2] && o.y >= r[1] && o.y <= r[3]
                            }?.id
                        },
                        onDrag = { change, delta ->
                            val id = dragId ?: return@detectDragGestures
                            change.consume()
                            val list = st.items[st.pageIndex] ?: return@detectDragGestures
                            st.items[st.pageIndex] = list.map { if (it.id == id) it.copy(cx = (it.cx + delta.x / size.width).coerceIn(0f, 1f), cy = (it.cy + delta.y / size.height).coerceIn(0f, 1f)) else it }
                        },
                        onDragEnd = { dragId = null }, onDragCancel = { dragId = null }
                    )
                }
                .pointerInput(st.pending) {
                    detectTapGestures { o ->
                        val p = st.pending ?: return@detectTapGestures
                        val placed = p.copy(id = System.currentTimeMillis(), cx = o.x / size.width, cy = o.y / size.height)
                        st.items[st.pageIndex] = (st.items[st.pageIndex] ?: emptyList()) + placed
                        st.pending = null
                        st.status = if (p.isSignature) "Signature placed — drag it to adjust." else "“${p.text}” placed — drag to adjust."
                        HandyHaptics.light(ctx)
                    }
                }
        ) {
            Image(page.asImageBitmap(), "Document", Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            val bw = boxSize.width; val bh = boxSize.height
            if (bw > 0 && bh > 0) pageItems.forEach { p ->
                val sig = p.bitmap
                if (p.isSignature && sig != null) {
                    val w = p.w * bw; val h = w * sig.height / sig.width
                    Image(
                        sig.asImageBitmap(), null,
                        Modifier.offset { IntOffset((p.cx * bw - w / 2).roundToInt(), (p.cy * bh - h / 2).roundToInt()) }
                            .size(with(density) { w.toDp() }, with(density) { h.toDp() })
                    )
                } else if (!p.isSignature) {
                    val fh = p.textFrac * bh
                    Box(
                        Modifier.offset { IntOffset((p.cx * bw).roundToInt() - 600, (p.cy * bh - fh * 0.75f).roundToInt()) }
                            .width(with(density) { 1200.toDp() }).height(with(density) { (fh * 1.5f).toDp() }),
                        contentAlignment = Alignment.Center
                    ) { Text(p.text, color = ink, fontSize = with(density) { fh.toSp() }, maxLines = 1) }
                }
            }
        }
        if (st.pageCount > 1) {
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                for (i in 0 until minOf(st.pageCount, 60)) HChip("Page ${i + 1}", st.pageIndex == i) { if (!st.loading) loadPage(i) }
            }
        }
    }

    Spacer(Modifier.height(10.dp))
    if (page == null) {
        HPrimaryButton(if (st.loading) "Opening…" else "Choose a PDF or photo", enabled = !st.loading) { picker.launch(arrayOf("application/pdf", "image/*")) }
    } else {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HSecondaryButton("Change file", Modifier.weight(1f)) { picker.launch(arrayOf("application/pdf", "image/*")) }
            HSecondaryButton("Undo last", Modifier.weight(1f), enabled = pageItems.isNotEmpty()) {
                st.items[st.pageIndex] = pageItems.dropLast(1); HandyHaptics.light(ctx)
            }
        }
    }
    st.pending?.let {
        Text(
            if (it.isSignature) "Now tap the page where the signature goes." else "Now tap the page where “${it.text}” goes.",
            color = HandyColors.Accent, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 10.dp)
        )
    }

    // Signature pad.
    SectionLabel("Draw your signature")
    var padSize by remember { mutableStateOf(IntSize.Zero) }
    var currentStroke by remember { mutableStateOf<List<Offset>?>(null) }
    Box(
        Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(12.dp)).background(Color.White)
            .border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).onSizeChanged { padSize = it }
    ) {
        Canvas(
            Modifier.fillMaxSize().pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { currentStroke = listOf(it) },
                    onDrag = { change, _ -> change.consume(); currentStroke = (currentStroke ?: emptyList()) + change.position },
                    onDragEnd = { currentStroke?.let { if (it.isNotEmpty()) st.strokes.add(it) }; currentStroke = null },
                    onDragCancel = { currentStroke = null }
                )
            }
        ) {
            (st.strokes + listOfNotNull(currentStroke)).forEach { s ->
                if (s.size > 1) {
                    val path = Path()
                    path.moveTo(s[0].x, s[0].y)
                    for (i in 1 until s.size) path.lineTo(s[i].x, s[i].y)
                    drawPath(path, ink, style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                } else if (s.size == 1) drawCircle(ink, 2.dp.toPx(), s[0])
            }
        }
        if (st.strokes.isEmpty() && currentStroke == null) Text("Sign here with your finger", color = Handy.palette.textSecondary,
            style = MaterialTheme.typography.bodySmall, modifier = Modifier.align(Alignment.Center))
    }
    Spacer(Modifier.height(10.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HSecondaryButton("Clear", Modifier.weight(1f), enabled = st.strokes.isNotEmpty()) { st.strokes.clear() }
        HPrimaryButton("Place signature", Modifier.weight(1f), enabled = page != null) {
            if (st.strokes.isEmpty()) { st.status = "Draw a signature first."; return@HPrimaryButton }
            val bmp = signatureBitmap(st.strokes.toList(), padSize.width, padSize.height, with(density) { 4.dp.toPx() })
            if (bmp == null) { st.status = "Draw a signature first."; return@HPrimaryButton }
            st.pending = Placed(0L, true, 0.5f, 0.5f, 0.32f, 0f, "", bmp)
            st.status = null
        }
    }
    if (page == null) Text("Choose a document above to place it.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))

    // Fill fields.
    SectionLabel("Fill fields")
    OutlinedTextField(st.name, { st.name = it }, label = { Text("Your name (for Name / Initials)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    Spacer(Modifier.height(8.dp))
    fun field(text: String) {
        if (page == null) { st.status = "Choose a document first."; return }
        st.pending = Placed(0L, false, 0.5f, 0.5f, 0f, 0.022f, text, null); st.status = null
    }
    val pendingText = st.pending?.takeIf { !it.isSignature }?.text
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        HChip("Name", pendingText != null && pendingText == st.name.trim() && st.name.isNotBlank()) {
            if (st.name.isBlank()) st.status = "Type your name above first." else field(st.name.trim())
        }
        val today = remember { SimpleDateFormat("d MMM yyyy", Locale.getDefault()).format(Date()) }
        HChip("Date", pendingText == today) { field(today) }
        val initials = st.name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString("") { it.first().uppercase() }
        HChip("Initials", pendingText != null && initials.isNotEmpty() && pendingText == initials) {
            if (initials.isEmpty()) st.status = "Type your name above first." else field(initials)
        }
        HChip("Checkbox ✓", pendingText == "✓") { field("✓") }
    }

    Spacer(Modifier.height(14.dp))
    val total = st.items.values.sumOf { it.size }
    HPrimaryButton(if (st.loading) "Working…" else "Export signed PDF", enabled = page != null && !st.loading && hasRoom, icon = Icons.Outlined.Draw) {
        val uri = st.uri ?: return@HPrimaryButton
        if (total == 0) { st.status = "Place a signature or a field first — then export."; return@HPrimaryButton }
        st.loading = true; st.status = "Flattening…"
        scope.launch {
            val file = withContext(Dispatchers.IO) { DocEngine.exportSigned(ctx, uri, st.isPdf, st.pageCount, st.items.toMap()) }
            st.loading = false
            if (file != null) {
                Usage.use(ctx, "sign", Limits.FREE_SIGN_PER_DAY)
                st.status = "Signed PDF exported · ${DocEngine.prettySize(file.length())}"
                HandyHaptics.success(ctx)
                Share.file(ctx, file, "application/pdf")
            } else st.status = "Couldn't save the PDF. Please try again."
        }
    }
    if (!hasRoom) Text("You've used today's ${Limits.FREE_SIGN_PER_DAY} free signed exports. Go Pro for unlimited.",
        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 10.dp)) }
    NoteText("The signed copy is flattened on the phone and never uploaded. Tap a placed item and drag to move it.")
}

/** Rasterise the pad strokes into a transparent bitmap cropped to the ink. */
private fun signatureBitmap(strokes: List<List<Offset>>, w: Int, h: Int, strokePx: Float): Bitmap? {
    if (strokes.isEmpty() || w <= 0 || h <= 0) return null
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val c = android.graphics.Canvas(bmp)
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF14148A.toInt(); style = android.graphics.Paint.Style.STROKE
        strokeWidth = strokePx; strokeCap = android.graphics.Paint.Cap.ROUND; strokeJoin = android.graphics.Paint.Join.ROUND
    }
    var minX = w.toFloat(); var minY = h.toFloat(); var maxX = 0f; var maxY = 0f
    strokes.forEach { s ->
        val path = android.graphics.Path()
        s.forEachIndexed { i, o ->
            if (i == 0) path.moveTo(o.x, o.y) else path.lineTo(o.x, o.y)
            minX = minOf(minX, o.x); minY = minOf(minY, o.y); maxX = maxOf(maxX, o.x); maxY = maxOf(maxY, o.y)
        }
        if (s.size == 1) c.drawCircle(s[0].x, s[0].y, strokePx / 2, paint.apply { style = android.graphics.Paint.Style.FILL })
        else c.drawPath(path, paint.apply { style = android.graphics.Paint.Style.STROKE })
    }
    if (maxX <= minX || maxY <= minY) return null
    val pad = strokePx * 2
    val l = (minX - pad).toInt().coerceIn(0, w - 1)
    val t = (minY - pad).toInt().coerceIn(0, h - 1)
    val r = (maxX + pad).toInt().coerceIn(l + 1, w)
    val b = (maxY + pad).toInt().coerceIn(t + 1, h)
    return Bitmap.createBitmap(bmp, l, t, r - l, b - t)
}
