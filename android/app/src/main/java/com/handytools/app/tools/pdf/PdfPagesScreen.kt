package com.handytools.app.tools.pdf

import android.content.Context
import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import com.tom_roush.pdfbox.pdmodel.PDDocument
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** One page in the new order: which file it comes from, which page, and how far it's turned. Pure. */
data class PageItem(val source: Int, val page: Int, val turn: Int = 0)

object PdfPages {
    fun start(pages: Int, source: Int = 0) = (0 until pages).map { PageItem(source, it) }
    fun move(items: List<PageItem>, from: Int, by: Int): List<PageItem> {
        val to = (from + by).coerceIn(0, items.lastIndex)
        if (to == from) return items
        return items.toMutableList().apply { add(to, removeAt(from)) }
    }
    fun turn(items: List<PageItem>, i: Int) = items.mapIndexed { j, p -> if (j == i) p.copy(turn = (p.turn + 90) % 360) else p }

    /** Builds the new PDF from [sources] in [items] order. Pages are copied, not redrawn, so text stays sharp. */
    fun build(ctx: Context, sources: List<File>, items: List<PageItem>, out: File): Boolean = runCatching {
        PdfCore.init(ctx)
        val docs = sources.map { PDDocument.load(it) }
        try {
            PDDocument().use { dst ->
                items.forEach { item ->
                    val p = dst.importPage(docs[item.source].getPage(item.page))
                    if (item.turn != 0) p.rotation = (p.rotation + item.turn) % 360
                }
                dst.save(out)
            }
        } finally { docs.forEach { it.close() } }
        true
    }.getOrDefault(false)

    /** One PDF per page, for "split". */
    fun split(ctx: Context, sources: List<File>, items: List<PageItem>, base: String): List<File> = items.mapIndexedNotNull { i, it ->
        val f = PdfCore.out(ctx, "$base - page ${i + 1}.pdf")
        if (build(ctx, sources, listOf(it), f)) f else null
    }
}

@Composable
fun PdfPagesScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var sources by remember { mutableStateOf(listOf<File>()) }
    var thumbs by remember { mutableStateOf(mapOf<Pair<Int, Int>, Bitmap?>()) }
    var items by remember { mutableStateOf(listOf<PageItem>()) }
    var name by remember { mutableStateOf("Document") }
    var result by remember { mutableStateOf<File?>(null) }
    var working by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf<String?>(null) }

    fun add(uri: android.net.Uri, first: Boolean) {
        working = true
        scope.launch {
            val f = withContext(Dispatchers.IO) { PdfCore.copy(ctx, uri) }
            val n = f?.let { PdfCore.pageCount(it) } ?: 0
            if (f == null || n == 0) { note = I18n.t("That PDF couldn't be opened. It may be damaged or locked with a password."); working = false; return@launch }
            val src = if (first) 0 else sources.size
            val t = withContext(Dispatchers.IO) { (0 until n).associate { (src to it) to PdfCore.render(f, it, 240) } }
            if (first) { sources = listOf(f); thumbs = t; items = PdfPages.start(n); name = PdfCore.name(ctx, uri) }
            else { sources = sources + f; thumbs = thumbs + t; items = items + PdfPages.start(n, src); note = I18n.t("Added") + ": $n " + I18n.t("pages") }
            working = false
        }
    }
    val more = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { it?.let { u -> add(u, false) } }

    PowerToolPage("pdfpages") {
        val r = result
        when {
            r != null -> ResultCard(r, "application/pdf", remember(r) { PdfCore.render(r, 0, 900) },
                "${items.size} " + I18n.t("pages") + " · " + r.name) { result = null }
            sources.isEmpty() -> PdfPicker("Choose a PDF, then move, turn or remove its pages.") { add(it, true) }
            else -> {
                Text("${items.size} " + I18n.t("pages"), fontSize = 13.sp, color = Handy.palette.textSecondary)
                Spacer(Modifier.size(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HSecondaryButton("Add a PDF", modifier = Modifier.weight(1f)) { more.launch(arrayOf("application/pdf")) }
                    HSecondaryButton("Drop blank pages", modifier = Modifier.weight(1f)) {
                        val before = items.size
                        items = items.filterNot { p -> thumbs[p.source to p.page]?.let { PdfCore.isBlank(it) } ?: false }
                        note = I18n.t("Removed") + " ${before - items.size} " + I18n.t("blank pages")
                    }
                }
                Spacer(Modifier.size(6.dp))
                HSecondaryButton("Reverse the order") { items = items.reversed() }
                note?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(vertical = 6.dp)) }
                items.forEachIndexed { i, p ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        val b = thumbs[p.source to p.page]
                        if (b != null) Image(remember(b) { b.asImageBitmap() }, null,
                            Modifier.width(64.dp).height(84.dp).clip(RoundedCornerShape(6.dp)).border(1.dp, Handy.palette.border, RoundedCornerShape(6.dp)).rotate(p.turn.toFloat()))
                        Spacer(Modifier.width(12.dp))
                        Text("${i + 1}", fontSize = 16.sp, color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.weight(1f))
                        Ctl("↑", "Move up") { items = PdfPages.move(items, i, -1) }
                        Ctl("↓", "Move down") { items = PdfPages.move(items, i, 1) }
                        Ctl("⟳", "Turn") { items = PdfPages.turn(items, i) }
                        if (items.size > 1) Ctl("✕", "Remove") { items = items.filterIndexed { j, _ -> j != i } }
                    }
                }
                Spacer(Modifier.size(12.dp))
                HPrimaryButton(if (working) "Working…" else "Make the new PDF", enabled = !working && items.isNotEmpty(), modifier = Modifier.testTag("pdfpages-make")) {
                    working = true
                    scope.launch {
                        val out = PdfCore.out(ctx, "$name (organized).pdf")
                        val ok = withContext(Dispatchers.IO) { PdfPages.build(ctx, sources, items, out) }
                        working = false
                        if (ok) result = out else note = I18n.t("Couldn't make the PDF. Try again.")
                    }
                }
                Spacer(Modifier.size(8.dp))
                if (items.size > 1) HSecondaryButton("Split into one PDF per page") {
                    working = true
                    scope.launch {
                        val files = withContext(Dispatchers.IO) { PdfPages.split(ctx, sources, items, name) }
                        working = false
                        if (files.isNotEmpty()) Share.files(ctx, files, "application/pdf")
                    }
                }
            }
        }
    }
}

@Composable
private fun Ctl(symbol: String, label: String, onClick: () -> Unit) {
    Text(symbol, fontSize = 18.sp, color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.size(44.dp).clickable(onClickLabel = I18n.t(label), onClick = onClick).padding(top = 10.dp),
        textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}
