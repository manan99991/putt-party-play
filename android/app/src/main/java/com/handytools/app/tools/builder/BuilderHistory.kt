package com.handytools.app.tools.builder

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.tools.Share
import com.handytools.app.tools.power.MediaEngine
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.ToolHeader
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** One finished run, kept so a result isn't lost when its screen is closed. [files] are names inside the run's own folder. */
data class HistoryItem(val id: String, val tool: String, val whenMs: Long, val files: List<String> = emptyList(), val text: String? = null)

/**
 * The last results your tools made. Kept on this phone only, in the app's own folder; the oldest drop off after
 * twenty, and Clear removes them all.
 */
object RunHistory {
    const val LIMIT = 20
    /** A result bigger than this is not kept (a long video would fill the phone); it is still shown and shared as usual. */
    const val BIGGEST = 150L * 1_048_576L

    private fun dir(ctx: Context): File = File(ctx.filesDir, "history").also { it.mkdirs() }
    private fun index(ctx: Context): File = File(dir(ctx), "index.json")
    private fun home(ctx: Context, id: String): File = File(dir(ctx), id)

    /** The newest first, at most [limit]. Pure, so it is unit-tested. */
    fun kept(items: List<HistoryItem>, limit: Int = LIMIT): List<HistoryItem> = items.sortedByDescending { it.whenMs }.take(limit.coerceAtLeast(0))

    fun all(ctx: Context): List<HistoryItem> = runCatching {
        val a = JSONArray(index(ctx).readText())
        (0 until a.length()).map { i ->
            val o = a.getJSONObject(i)
            val f = o.optJSONArray("files")
            HistoryItem(o.getString("id"), o.optString("tool", "Tool"), o.optLong("when", 0L),
                if (f == null) emptyList() else (0 until f.length()).map { f.getString(it) }, if (o.has("text")) o.getString("text") else null)
        }
    }.getOrDefault(emptyList())

    private fun save(ctx: Context, items: List<HistoryItem>) {
        runCatching {
            index(ctx).writeText(JSONArray().also { a ->
                items.forEach { i -> a.put(JSONObject().put("id", i.id).put("tool", i.tool).put("when", i.whenMs).put("files", JSONArray(i.files)).also { o -> i.text?.let { o.put("text", it) } }) }
            }.toString())
        }
    }

    fun files(ctx: Context, item: HistoryItem): List<File> = item.files.map { File(home(ctx, item.id), it) }.filter { it.exists() }

    /** Keeps a copy of what a run made. Never fails the run: anything that can't be copied is simply not kept. */
    fun add(ctx: Context, tool: String, files: List<File>, text: String?) {
        runCatching {
            val id = java.util.UUID.randomUUID().toString()
            val names = ArrayList<String>(); var total = 0L
            for (src in files) {
                if (!src.exists() || total + src.length() > BIGGEST) continue
                val to = File(home(ctx, id).also { it.mkdirs() }, src.name)
                if (runCatching { src.copyTo(to, overwrite = true) }.isSuccess) { names.add(src.name); total += src.length() }
            }
            val words = text?.trim()?.take(50_000)?.takeIf { it.isNotEmpty() }
            if (names.isEmpty() && words == null) return
            val before = all(ctx)
            val now = kept(before + HistoryItem(id, tool.ifBlank { "Tool" }, System.currentTimeMillis(), names, words))
            before.filter { old -> now.none { it.id == old.id } }.forEach { home(ctx, it.id).deleteRecursively() }
            save(ctx, now)
        }
    }

    /** The same for a result still in memory. */
    fun add(ctx: Context, tool: String, fileName: String, result: Payload) {
        runCatching {
            val tmp = File(ctx.cacheDir, "history-in").also { it.mkdirs() }
            when (result) {
                is Payload.Words -> add(ctx, tool, emptyList(), result.text)
                is Payload.Pic -> add(ctx, tool, listOf(File(tmp, "$fileName.jpg").also { it.writeBytes(MediaEngine.jpeg(result.bmp, 92)) }), null)
                is Payload.Doc -> add(ctx, tool, listOf(File(tmp, "$fileName.${result.ext}").also { it.writeBytes(result.bytes) }), null)
                is Payload.Clip -> add(ctx, tool, listOfNotNull(result.uri.path?.let { File(it) }), null)
            }
            tmp.listFiles()?.forEach { it.delete() }
        }
    }

    fun remove(ctx: Context, item: HistoryItem) { home(ctx, item.id).deleteRecursively(); save(ctx, all(ctx).filter { it.id != item.id }) }
    fun clear(ctx: Context) { all(ctx).forEach { home(ctx, it.id).deleteRecursively() }; save(ctx, emptyList()) }

    /** "3 files · 2.1 MB", "JPG · 640 KB" or the first words of a text result. */
    fun summary(ctx: Context, item: HistoryItem): String {
        val found = files(ctx, item)
        if (found.isEmpty()) return (item.text ?: "").replace('\n', ' ').take(80)
        return (if (found.size == 1) found[0].extension.uppercase() else "${found.size} files") + " · " + MediaEngine.human(found.sumOf { it.length() })
    }
}

/** Recent results: share or copy one again, remove one, or clear them all. */
@Composable
fun HistoryScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    var items by remember { mutableStateOf(RunHistory.all(ctx)) }
    var clearing by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler { onBack() }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("Recent results", "The last ${RunHistory.LIMIT} things your tools made. They stay on this phone until you clear them.")
        if (items.isEmpty()) Text("Nothing yet. Run a tool and its result appears here.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
        items.forEach { item ->
            val found = remember(item.id) { RunHistory.files(ctx, item) }
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    Text(item.tool, style = MaterialTheme.typography.titleSmall)
                    Text(android.text.format.DateUtils.getRelativeTimeSpanString(item.whenMs, System.currentTimeMillis(), android.text.format.DateUtils.MINUTE_IN_MILLIS).toString() + " · " + RunHistory.summary(ctx, item),
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    val thumb = remember(item.id) {
                        found.firstOrNull { it.extension.lowercase() in listOf("jpg", "jpeg", "png", "gif") }?.let { f ->
                            runCatching { BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = 4 }) }.getOrNull()
                        }
                    }
                    thumb?.let { Image(it.asImageBitmap(), null, Modifier.heightIn(max = 120.dp)) }
                    Row {
                        if (found.isNotEmpty()) TextButton({
                            val mime = found.map { it.extension.lowercase() }.distinct().singleOrNull()?.let { mimeFor(it) } ?: "*/*"
                            Share.files(ctx, found, mime)
                        }) { Text("Save or share") }
                        else item.text?.let { t ->
                            TextButton({ (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", t)) }) { Text("Copy") }
                        }
                        TextButton({ RunHistory.remove(ctx, item); items = RunHistory.all(ctx) }) { Text("Remove") }
                    }
                }
            }
        }
        if (items.isNotEmpty()) HSecondaryButton("Clear them all") { clearing = true }
        HSecondaryButton("Back") { onBack() }
    }
    if (clearing) AlertDialog(
        onDismissRequest = { clearing = false },
        title = { Text("Clear every recent result?") },
        text = { Text("They are removed from this phone. Anything you already saved or sent is not touched.") },
        confirmButton = { TextButton({ RunHistory.clear(ctx); items = emptyList(); clearing = false }) { Text("Clear them all") } },
        dismissButton = { TextButton({ clearing = false }) { Text("Keep them") } },
    )
}
