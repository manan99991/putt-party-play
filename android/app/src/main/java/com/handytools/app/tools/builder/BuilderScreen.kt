package com.handytools.app.tools.builder

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color as AColor
import android.graphics.Paint
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import java.io.File

/** Saved chains, kept on the phone as JSON. */
object ChainStore {
    private const val FILE = "builder-chains.json"
    fun load(ctx: Context): List<Chain> = runCatching {
        val a = JSONArray(File(ctx.filesDir, FILE).readText())
        (0 until a.length()).mapNotNull { Chain.fromJson(a.getJSONObject(it)) }
    }.getOrDefault(emptyList())

    fun save(ctx: Context, chains: List<Chain>) {
        runCatching { File(ctx.filesDir, FILE).writeText(JSONArray().also { a -> chains.forEach { a.put(it.toJson()) } }.toString()) }
    }
}

private fun defaults(b: Block): Map<String, String> = when (b) {
    Block.SHRINK -> mapOf("mb" to "2"); Block.SUMMARIZE -> mapOf("sentences" to "3"); Block.CONVERT -> mapOf("format" to "JPG"); else -> emptyMap()
}

@Composable
fun BuilderScreen() {
    val ctx = LocalContext.current
    val mine = remember { mutableStateListOf<Chain>().also { it.addAll(ChainStore.load(ctx)) } }
    var editing by remember { mutableStateOf<Chain?>(null) }
    var running by remember { mutableStateOf<Chain?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    var ask by remember { mutableStateOf("") }

    fun saveAll() = ChainStore.save(ctx, mine.toList())

    editing?.let { c ->
        ChainEditor(c, onCancel = { editing = null }) { saved ->
            val i = mine.indexOfFirst { it.id == saved.id }
            if (i >= 0) mine[i] = saved else mine.add(saved)
            saveAll(); editing = null
        }
        return
    }
    running?.let { c -> ChainRunScreen(c) { running = null }; return }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("Build your own", "Snap small steps together into a tool that does exactly what you need. Runs on your phone.")
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(HandyTokens.Space16), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                Text("Describe it", style = MaterialTheme.typography.titleMedium)
                Text("Say what you want in your own words. Tenzy lines up the steps and shows you before anything runs.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                OutlinedTextField(ask, { ask = it }, Modifier.fillMaxWidth(), placeholder = { Text("e.g. shrink a photo under 1 MB and remove its location") }, minLines = 1, maxLines = 3)
                HPrimaryButton("Build it for me", enabled = ask.isNotBlank()) {
                    val p = ChainPlanner.plan(ask)
                    if (p != null) { editing = p; note = null }
                    else note = "I couldn't turn that into steps yet. Try a template below, or say what you start with (a photo, a receipt, some text) and what you want out."
                }
            }
        }
        note?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
        if (mine.isNotEmpty()) {
            Text("My tools", style = MaterialTheme.typography.titleMedium)
            mine.toList().forEach { c ->
                ChainRow(c, onRun = { running = c }, onEdit = { editing = c }, onCopy = { copy(ctx, c); note = "Copied. Paste it into Tenzy on another phone." }, onDelete = { mine.removeAll { it.id == c.id }; saveAll() })
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Start from a template", style = MaterialTheme.typography.titleMedium)
            Row {
                TextButton({ editing = Chain.blank() }) { Text("Blank") }
                TextButton({
                    val c = Chain.imported(paste(ctx))
                    if (c != null) { mine.add(c); saveAll(); note = "Added ${c.name}." } else note = "Copy a tool from another Tenzy first, then tap Paste. Tools that use steps this phone doesn't have can't be added."
                }) { Text("Paste") }
            }
        }
        ChainTemplates.all.forEach { c ->
            ChainRow(c, onRun = { running = c }, onEdit = { editing = c.copy(id = java.util.UUID.randomUUID().toString(), name = c.name + " (mine)") }, onCopy = { copy(ctx, c); note = "Copied." }, onDelete = null)
        }
    }
}

private fun copy(ctx: Context, c: Chain) {
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy tool", c.shareText))
}
private fun paste(ctx: Context): String =
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString().orEmpty()

@Composable
private fun ChainRow(c: Chain, onRun: () -> Unit, onEdit: () -> Unit, onCopy: () -> Unit, onDelete: (() -> Unit)?) {
    var menu by remember { mutableStateOf(false) }
    HCard(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(HandyTokens.Space12), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(c.name, style = MaterialTheme.typography.titleSmall)
                Text(c.steps.joinToString("  ›  ") { it.block.title }, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            TextButton(onRun) { Text("Run") }
            TextButton({ menu = true }) { Text("More") }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text(if (onDelete == null) "Edit a copy" else "Edit") }, onClick = { menu = false; onEdit() })
                DropdownMenuItem(text = { Text("Copy to share") }, onClick = { menu = false; onCopy() })
                if (onDelete != null) DropdownMenuItem(text = { Text("Delete") }, onClick = { menu = false; onDelete() })
            }
        }
    }
}

/** A flow from what you give, through each step, to what you get, with each step tried on a sample as you build. */
@Composable
private fun ChainEditor(start: Chain, onCancel: () -> Unit, onSave: (Chain) -> Unit) {
    var chain by remember { mutableStateOf(start) }
    var addMenu by remember { mutableStateOf(false) }
    val previews = remember { mutableStateListOf<Preview?>() }
    val options = chain.end?.let { e -> Block.values().filter { e.feeds(it.takes) } } ?: Block.values().toList()
    val problem = chain.problem()

    LaunchedEffect(chain.steps) {
        previews.clear(); chain.steps.forEach { previews.add(null) }
        val first = chain.steps.firstOrNull() ?: return@LaunchedEffect
        delay(250)
        var v: Payload = when {
            first.block == Block.READ_TEXT -> Payload.Pic(sampleReceipt())
            first.block.takes == Kind.TEXT -> Payload.Words(SAMPLE_TEXT)
            else -> Payload.Pic(samplePhoto())
        }
        for ((i, s) in chain.steps.withIndex()) {
            if (!v.kind.feeds(s.block.takes)) { previews[i] = Preview.Bad("Needs ${s.block.takes.label} from the step above."); continue }
            when (val r = ChainRunner.apply(s, v)) {
                is Outcome.Done -> { v = r.value; previews[i] = Preview.of(r.value) }
                is Outcome.Stopped -> { previews[i] = Preview.Bad(r.why); return@LaunchedEffect }
            }
        }
    }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        ToolHeader("Build a tool", "Each step is tried on a sample so you can see it work.")
        OutlinedTextField(chain.name, { chain = chain.copy(name = it) }, Modifier.fillMaxWidth(), label = { Text("Name your tool") }, singleLine = true)
        Text(if (chain.steps.isEmpty()) "You give it a photo or text. The first step decides which." else "You give it ${chain.start.label}", style = MaterialTheme.typography.titleSmall)
        chain.steps.forEachIndexed { i, s ->
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    Text("${i + 1}. ${s.block.title}", style = MaterialTheme.typography.titleSmall)
                    Text(s.block.blurb, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    StepSettings(s) { ns -> chain = chain.copy(steps = chain.steps.toMutableList().also { it[i] = ns }) }
                    PreviewStrip(previews.getOrNull(i))
                    Row {
                        if (i > 0) TextButton({ chain = chain.copy(steps = chain.steps.toMutableList().also { it.add(i - 1, it.removeAt(i)) }) }) { Text("Up") }
                        if (i < chain.steps.size - 1) TextButton({ chain = chain.copy(steps = chain.steps.toMutableList().also { it.add(i + 1, it.removeAt(i)) }) }) { Text("Down") }
                        TextButton({ chain = chain.copy(steps = chain.steps.toMutableList().also { it.removeAt(i) }) }) { Text("Remove") }
                    }
                }
            }
        }
        HSecondaryButton(if (chain.steps.isEmpty()) "Add the first step" else "Add a step") { addMenu = true }
        DropdownMenu(addMenu, { addMenu = false }) {
            options.forEach { b -> DropdownMenuItem(text = { Text(b.title) }, onClick = { addMenu = false; chain = chain.copy(steps = chain.steps + Step(b, defaults(b))) }) }
        }
        chain.end?.let { Text("You get ${it.label}. Then copy it, save it or share it.", style = MaterialTheme.typography.titleSmall) }
        if (problem != null && chain.steps.isNotEmpty()) Text(problem, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        HPrimaryButton("Save", enabled = problem == null && chain.name.isNotBlank()) { onSave(chain) }
        HSecondaryButton("Cancel") { onCancel() }
        Spacer(Modifier.heightIn(min = 24.dp))
    }
}

@Composable
private fun StepSettings(s: Step, onChange: (Step) -> Unit) {
    fun set(k: String, v: String) = onChange(s.copy(settings = s.settings + (k to v)))
    when (s.block) {
        Block.SHRINK -> {
            val mb = s.settings["mb"]?.toDoubleOrNull() ?: 2.0
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                TextButton({ set("mb", (mb - 0.25).coerceAtLeast(0.25).toString()) }) { Text("−") }
                Text("Under ${"%.2f".format(mb).trimEnd('0').trimEnd('.')} MB", style = MaterialTheme.typography.bodyMedium)
                TextButton({ set("mb", (mb + 0.25).coerceAtMost(20.0).toString()) }) { Text("+") }
            }
        }
        Block.SUMMARIZE -> {
            val n = s.settings["sentences"]?.toIntOrNull() ?: 3
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                TextButton({ set("sentences", (n - 1).coerceAtLeast(1).toString()) }) { Text("−") }
                Text("$n sentences", style = MaterialTheme.typography.bodyMedium)
                TextButton({ set("sentences", (n + 1).coerceAtMost(8).toString()) }) { Text("+") }
            }
        }
        Block.CONVERT -> Row {
            listOf("JPG", "PNG").forEach { f -> TextButton({ set("format", f) }) { Text(if ((s.settings["format"] ?: "JPG") == f) "● $f" else f) } }
        }
        else -> {}
    }
}

sealed class Preview {
    class Words(val t: String) : Preview()
    class Pic(val b: Bitmap) : Preview()
    class Doc(val d: String) : Preview()
    class Bad(val w: String) : Preview()
    companion object {
        fun of(p: Payload): Preview = when (p) {
            is Payload.Words -> Words(p.text)
            is Payload.Pic -> Pic(p.bmp)
            is Payload.Doc -> BitmapFactory.decodeByteArray(p.bytes, 0, p.bytes.size)?.takeIf { p.kind == Kind.PHOTO_FILE }?.let { Pic(it) }
                ?: Doc("${p.ext.uppercase()} file · ${p.bytes.size / 1024} KB")
        }
    }
}

@Composable
private fun PreviewStrip(p: Preview?) {
    Column(Modifier.fillMaxWidth()) {
        when (p) {
            null -> Text("Trying it on a sample…", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            is Preview.Words -> Text(p.t.lines().take(6).joinToString("\n"), style = MaterialTheme.typography.bodySmall)
            is Preview.Pic -> Image(p.b.asImageBitmap(), null, Modifier.heightIn(max = 120.dp))
            is Preview.Doc -> Text(p.d, style = MaterialTheme.typography.bodySmall)
            is Preview.Bad -> Text(p.w, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }
}

private const val SAMPLE_TEXT = "Team sync Friday at 3pm in Room 4. Please send the budget to Ana by Thursday. Call the vendor about the invoice. Review the launch checklist before noon. Priya Rao, Design Lead, priya@studio.example, 555 010 2030."

private fun samplePhoto(): Bitmap = Bitmap.createBitmap(1200, 1600, Bitmap.Config.ARGB_8888).also { b ->
    val c = Canvas(b)
    c.drawColor(AColor.rgb(90, 140, 215))
    val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AColor.rgb(217, 166, 128) }
    c.drawCircle(600f, 640f, 220f, p)
    p.color = AColor.rgb(50, 64, 102); c.drawRect(300f, 900f, 900f, 1600f, p)
}

private fun sampleReceipt(): Bitmap = Bitmap.createBitmap(900, 1100, Bitmap.Config.ARGB_8888).also { b ->
    val c = Canvas(b); c.drawColor(AColor.WHITE)
    val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AColor.BLACK; textSize = 48f }
    listOf("CORNER CAFE" to "", "Latte" to "4.50", "Croissant" to "3.25", "Sandwich" to "5.97", "Subtotal" to "13.72", "Tax" to "1.10", "Total" to "14.82").forEachIndexed { i, (l, r) ->
        val y = 120f + i * 90f
        c.drawText(l, 60f, y, p); if (r.isNotEmpty()) c.drawText(r, 640f, y, p)
    }
}

/** Give it a photo or some text, see the result, share it. */
@Composable
private fun ChainRunScreen(chain: Chain, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<Payload?>(null) }

    fun go(input: Payload) {
        busy = true; result = null; message = null
        scope.launch {
            when (val r = ChainRunner.run(chain, input)) {
                is Outcome.Done -> result = r.value
                is Outcome.Stopped -> message = r.why
            }
            busy = false
        }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = runCatching { ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } }.getOrNull()
        if (bmp != null) go(Payload.Pic(bmp)) else message = "That photo couldn't be opened. Try another."
    }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader(chain.name, chain.steps.joinToString("  ›  ") { it.block.title })
        if (chain.start == Kind.TEXT) {
            OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp), label = { Text("Your text") })
            HPrimaryButton("Run", enabled = text.isNotBlank() && !busy) { go(Payload.Words(text)) }
        } else HPrimaryButton("Choose a photo", enabled = !busy) { picker.launch("image/*") }
        if (busy) Text("Working…", color = Handy.palette.textSecondary)
        message?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
        when (val r = result) {
            is Payload.Words -> {
                Text(r.text, style = MaterialTheme.typography.bodyMedium)
                HSecondaryButton("Copy") { (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", r.text)) }
            }
            is Payload.Pic -> {
                Image(r.bmp.asImageBitmap(), null, Modifier.heightIn(max = 320.dp))
            }
            is Payload.Doc -> {
                Text("${r.bytes.size / 1024} KB · ${r.ext.uppercase()}", style = MaterialTheme.typography.bodySmall)
                HPrimaryButton("Save or share") {
                    val f = File(ctx.cacheDir, "Tenzy-result.${r.ext}").also { it.writeBytes(r.bytes) }
                    Share.file(ctx, f, when (r.ext) { "jpg" -> "image/jpeg"; "png" -> "image/png"; "vcf" -> "text/x-vcard"; "ics" -> "text/calendar"; else -> "*/*" })
                }
            }
            null -> {}
        }
        HSecondaryButton("Done") { onDone() }
    }
}
