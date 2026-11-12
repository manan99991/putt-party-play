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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import com.handytools.app.tools.power.MediaEngine
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

    /** The tool last run on something shared to Tenzy, offered first next time. */
    fun lastShared(ctx: Context): String? = ctx.getSharedPreferences("builder", Context.MODE_PRIVATE).getString("lastShared", null)
    fun setLastShared(ctx: Context, id: String) { ctx.getSharedPreferences("builder", Context.MODE_PRIVATE).edit().putString("lastShared", id).apply() }
}

/**
 * "Share to Tenzy": a photo shared from Gallery, Photos or any other app lands here. Pick a tool and it runs on that
 * photo straight away; the result screen has Share, so it can go on to WhatsApp, email or anywhere else.
 */
@Composable
fun ShareToToolScreen(uri: Uri?, onOpenInstead: () -> Unit) {
    val ctx = LocalContext.current
    val tools = remember { ChainOffers.forKind(Kind.IMAGE, ChainStore.load(ctx), ChainStore.lastShared(ctx)) }
    var running by remember { mutableStateOf<Chain?>(null) }
    running?.let { c -> ChainRunScreen(c, initial = uri) { running = null }; return }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("Run a tool on this photo", "Pick one. It runs right away, and the result is ready to share on.")
        tools.forEach { c ->
            HCard(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(HandyTokens.Space12), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(c.name, style = MaterialTheme.typography.titleSmall)
                        Text(c.steps.joinToString("  ›  ") { it.block.title }, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                    TextButton({ ChainStore.setLastShared(ctx, c.id); running = c }) { Text("Run") }
                }
            }
        }
        HSecondaryButton("Just open the photo") { onOpenInstead() }
    }
}

private fun defaults(b: Block): Map<String, String> = when (b) {
    Block.SHRINK -> mapOf("mb" to "2"); Block.SUMMARIZE -> mapOf("sentences" to "3"); Block.CONVERT -> mapOf("format" to "JPG")
    Block.WATERMARK -> mapOf("text" to "For verification only"); Block.STAMP -> mapOf("marks" to StampPlan.STANDARD); Block.RETURN_BY -> mapOf("days" to "30"); Block.RESIZE_PHOTO -> mapOf("size" to "413x531")
    Block.ADD_TO_LIST -> mapOf("list" to TextTidy.DEFAULT_LIST)
    Block.CHAT_LINK -> mapOf("cc" to TextTidy.callingCode(java.util.Locale.getDefault().country)); else -> emptyMap()
}

@Composable
fun BuilderScreen() {
    val ctx = LocalContext.current
    val mine = remember { mutableStateListOf<Chain>().also { it.addAll(ChainStore.load(ctx)) } }
    var editing by remember { mutableStateOf<Chain?>(null) }
    var running by remember { mutableStateOf<Chain?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    var ask by remember { mutableStateOf("") }

    fun saveAll() { ChainStore.save(ctx, mine.toList()); ToolReminders.sync(ctx, mine.toList()); PhotoWatch.arm(ctx) }
    var showSheets by remember { mutableStateOf(false) }
    val prefs = remember { ctx.getSharedPreferences("builder", Context.MODE_PRIVATE) }
    var introSeen by remember { mutableStateOf(prefs.getBoolean("introSeen", false)) }
    fun setIntro(seen: Boolean) { introSeen = seen; prefs.edit().putBoolean("introSeen", seen).apply() }
    var have by remember { mutableStateOf<Kind?>(null) }     // "What do you have?": narrows the starters
    var runOn by remember { mutableStateOf<Uri?>(null) }      // the new photo a tapped "run this tool" notification came with

    // A tapped reminder lands here: open that tool ready to run.
    val reminded = ToolReminders.pending
    LaunchedEffect(reminded) {
        if (reminded != null) {
            mine.firstOrNull { it.id == reminded }?.let { editing = null; runOn = ToolReminders.pendingPhoto; running = it }
            ToolReminders.pending = null; ToolReminders.pendingPhoto = null
        }
    }

    editing?.let { c ->
        ChainEditor(c, onCancel = { editing = null }) { saved ->
            val i = mine.indexOfFirst { it.id == saved.id }
            if (i >= 0) mine[i] = saved else mine.add(saved)
            saveAll(); editing = null
        }
        return
    }
    running?.let { c -> ChainRunScreen(c, initial = runOn) { running = null; runOn = null }; return }
    if (showSheets) { SheetsScreen { showSheets = false }; return }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("Build your own", "Snap small steps together into a tool that does exactly what you need. Runs on your phone.")
        if (!introSeen) HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(HandyTokens.Space16), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                Text("Make a tool that does the whole job", style = MaterialTheme.typography.titleMedium)
                BuilderIntro.PAGES.forEach { (title, body) ->
                    Text(title, style = MaterialTheme.typography.titleSmall)
                    Text(body, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                }
                HPrimaryButton("Show me one") {
                    ChainTemplates.all.firstOrNull { it.id == BuilderIntro.DEMO_ID }?.let { editing = it.copy(id = java.util.UUID.randomUUID().toString(), name = it.name + " (mine)") }
                }
                TextButton({ setIntro(true) }) { Text("Got it") }
            }
        }
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
                ChainRow(c, onRun = { running = c }, onEdit = { editing = c }, onCopy = { copy(ctx, c); note = "Copied. Paste it into Tenzy on another phone." }, onDelete = { mine.removeAll { it.id == c.id }; saveAll() },
                    onDuplicate = { val k = c.copy(id = java.util.UUID.randomUUID().toString(), name = c.name + " copy", schedule = null, auto = AutoRun.OFF); mine.add(k); saveAll(); note = "Duplicated as ${k.name}." })
            }
        }
        val sheetCount = remember { SheetStore.all(ctx).size }
        if (sheetCount > 0) HCard(Modifier.fillMaxWidth(), onClick = { showSheets = true }) {
            Column(Modifier.padding(HandyTokens.Space12)) {
                Text("My sheets", style = MaterialTheme.typography.titleSmall)
                Text(if (sheetCount == 1) "1 sheet your tools add to" else "$sheetCount sheets your tools add to", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            listOf<Pair<String, Kind?>>("Everything" to null, "A photo or scan" to Kind.IMAGE, "Text" to Kind.TEXT).forEach { (label, k) ->
                if (have == k) Button({ have = k }) { Text(label) } else OutlinedButton({ have = k }) { Text(label) }
            }
        }
        BuilderIntro.starters(have).forEach { c ->
            ChainRow(c, onRun = { running = c }, onEdit = { editing = c.copy(id = java.util.UUID.randomUUID().toString(), name = c.name + " (mine)") }, onCopy = { copy(ctx, c); note = "Copied." }, onDelete = null)
        }
        if (introSeen) TextButton({ setIntro(false) }) { Text("How does this work?") }
    }
}

private fun copy(ctx: Context, c: Chain) {
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy tool", c.shareText))
}
private fun paste(ctx: Context): String =
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString().orEmpty()

@Composable
private fun ChainRow(c: Chain, onRun: () -> Unit, onEdit: () -> Unit, onCopy: () -> Unit, onDelete: (() -> Unit)?, onDuplicate: (() -> Unit)? = null) {
    var menu by remember { mutableStateOf(false) }
    HCard(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(HandyTokens.Space12), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(c.name, style = MaterialTheme.typography.titleSmall)
                Text(c.steps.joinToString("  ›  ") { it.block.title }, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                if (c.auto.isNotEmpty()) Text(AutoRun.label(c.auto), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                c.schedule?.let { w -> Text("Reminder: " + w.label(android.text.format.DateFormat.is24HourFormat(LocalContext.current)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary) }
            }
            TextButton(onRun) { Text("Run") }
            TextButton({ menu = true }) { Text("More") }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text(if (onDelete == null) "Edit a copy" else "Edit") }, onClick = { menu = false; onEdit() })
                if (onDuplicate != null) DropdownMenuItem(text = { Text("Duplicate") }, onClick = { menu = false; onDuplicate() })
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
    // What the person said they start with, before there is a first step to tell us.
    var startChoice by remember { mutableStateOf<Kind?>(null) }
    val options = chain.end?.let { e -> Block.values().filter { e.feeds(it.takes) } } ?: startChoice?.let { BlockGoals.starting(it) } ?: emptyList()
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
            when (val r = ChainRunner.apply(s, v, dryRun = true)) {   // a preview never saves anything
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
        if (chain.steps.isEmpty() && startChoice == null) {
            // First question of a new tool: what do you have? Everything offered after this fits the answer.
            Text("What do you start with?", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                Button({ startChoice = Kind.IMAGE }, Modifier.weight(1f)) { Text("A photo") }
                Button({ startChoice = Kind.TEXT }, Modifier.weight(1f)) { Text("Text") }
            }
            Text("Video, voice, contacts and files are coming next.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        } else {
            if (chain.steps.isEmpty()) {
                Text("You start with ${startChoice?.label}. You only see steps that work with it.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                TextButton({ startChoice = null }) { Text("Start with something else") }
            }
            HSecondaryButton(if (chain.steps.isEmpty()) "Add the first step" else "Add a step") { addMenu = true }
            DropdownMenu(addMenu, { addMenu = false }) {
                // Grouped by what you want to get done; only steps that fit what the tool has at this point.
                BlockGoals.grouped(options).forEach { (goal, blocks) ->
                    Text(goal, style = MaterialTheme.typography.labelMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = HandyTokens.Space12, vertical = HandyTokens.Space4))
                    blocks.forEach { b -> DropdownMenuItem(text = { Text(b.title) }, onClick = { addMenu = false; chain = chain.copy(steps = chain.steps + Step(b, defaults(b))) }) }
                }
            }
        }
        chain.end?.let {
            Text("You get ${it.label}. Then:", style = MaterialTheme.typography.titleSmall)
            val fin = chain.finish ?: Finish()
            // "Open" only makes sense when the tool ends with text (a link).
            Finish.KINDS.filter { k -> k != "open" || it == Kind.TEXT }.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    pair.forEach { k ->
                        if (k == fin.kind) Button({}, Modifier.weight(1f)) { Text(Finish.title(k)) }
                        else OutlinedButton({ chain = chain.copy(finish = fin.copy(kind = k)) }, Modifier.weight(1f)) { Text(Finish.title(k)) }
                    }
                }
            }
            if (fin.kind == "mail" || fin.kind == "message") {
                OutlinedTextField(fin.to, { v -> chain = chain.copy(finish = fin.copy(to = v)) }, Modifier.fillMaxWidth(), singleLine = true,
                    label = { Text(if (fin.kind == "mail") "Email address (optional)" else "Phone number (optional)") })
            }
            if (it != Kind.TEXT) {
                OutlinedTextField(chain.fileName, { v -> chain = chain.copy(fileName = v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("File name (optional), e.g. Signed form {date}") })
                Text("Write {date} where today's date should go.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            if (chain.start == Kind.IMAGE && it != Kind.TEXT) {
                Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.combine, { on -> chain = chain.copy(combine = on, onePage = on && chain.onePage) })
                    Text("  Put all pages or photos into one PDF", style = MaterialTheme.typography.bodyMedium)
                }
                if (chain.combine) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.onePage, { on -> chain = chain.copy(onePage = on) })
                    Text("  All on a single page (both sides of an ID)", style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (fin.kind != "share") Text(
                when (fin.kind) { "mail" -> "When the tool finishes, an email opens with the result attached. You tap Send."
                    "message" -> "When the tool finishes, a message opens with the result attached. You tap Send."
                    "open" -> "When the tool finishes, the link it made opens."
                    else -> "When the tool finishes, WhatsApp opens with the result attached. You pick the chat and tap Send." },
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        if (chain.end != null) ScheduleCard(chain.schedule) { w -> chain = chain.copy(schedule = w) }
        if (chain.end != null && chain.start == Kind.IMAGE) AutoRunCard(chain.auto) { a -> chain = chain.copy(auto = a) }
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
            // Steps through a short list of limits, down to the 20-50 KB that government and bank upload forms ask for.
            val mb = s.settings["mb"]?.toDoubleOrNull() ?: 2.0
            val i = TextTidy.LIMITS.indexOfFirst { it >= mb }.let { if (it < 0) TextTidy.LIMITS.lastIndex else it }
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                TextButton({ set("mb", TextTidy.LIMITS[(i - 1).coerceAtLeast(0)].toString()) }) { Text("−") }
                Text("Under ${TextTidy.limitLabel(mb)}", style = MaterialTheme.typography.bodyMedium)
                TextButton({ set("mb", TextTidy.LIMITS[(i + 1).coerceAtMost(TextTidy.LIMITS.lastIndex)].toString()) }) { Text("+") }
            }
        }
        Block.CHAT_LINK -> {
            OutlinedTextField(s.settings["cc"] ?: "1", { v -> set("cc", v.filter { it.isDigit() }) }, singleLine = true, label = { Text("Country code (without +)") })
            Text("Used when the number is written without one.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.ADD_TO_LIST -> {
            OutlinedTextField(s.settings["list"] ?: TextTidy.DEFAULT_LIST, { v -> set("list", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Sheet name") })
            Text("Write {month} to start a fresh sheet each month. The sample shown here is not saved.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.STAMP -> StampSettings(s.settings["marks"] ?: StampPlan.STANDARD) { v -> set("marks", v) }
        Block.WATERMARK -> {
            OutlinedTextField(s.settings["text"] ?: "", { v -> set("text", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Words to write across it") })
            Text("Today's date is added each time it runs.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.PASSPORT_PHOTO -> Column {
            PriceDeal.PASSPORT.forEach { (id, label, _) ->
                TextButton({ set("country", id) }) { Text(if ((s.settings["country"] ?: "us") == id) "● $label" else label) }
            }
        }
        Block.RETURN_BY -> Row {
            val days = TextTidy.returnDays(s.settings["days"])
            TextTidy.RETURN_WINDOWS.forEach { d -> TextButton({ set("days", d.toString()) }) { Text(if (d == days) "● $d days" else "$d days") } }
        }
        Block.RESIZE_PHOTO -> Column {
            TextTidy.SIZES.forEach { (label, value) ->
                TextButton({ set("size", value) }) { Text(if ((s.settings["size"] ?: "413x531") == value) "● $label" else label) }
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
            is Payload.Doc ->
                if (p.ext in listOf("csv", "vcf", "ics")) Words(String(p.bytes))
                else BitmapFactory.decodeByteArray(p.bytes, 0, p.bytes.size)?.takeIf { p.kind == Kind.PHOTO_FILE }?.let { Pic(it) }
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
private fun ChainRunScreen(chain: Chain, initial: Uri? = null, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<Payload?>(null) }
    var batch by remember { mutableStateOf<List<BatchItem>>(emptyList()) }
    var progress by remember { mutableStateOf("") }

    fun go(input: Payload) {
        busy = true; result = null; message = null; batch = emptyList()
        scope.launch {
            when (val r = ChainRunner.run(chain, input)) {
                is Outcome.Done -> result = r.value
                is Outcome.Stopped -> message = r.why
            }
            busy = false
        }
    }
    // Opened from "Share to Tenzy": the shared photo runs straight away, no picking needed.
    LaunchedEffect(initial) {
        if (initial != null) {
            val bmp = withContext(Dispatchers.IO) { runCatching { ctx.contentResolver.openInputStream(initial)?.use { BitmapFactory.decodeStream(it) } }.getOrNull() }
            if (bmp != null) go(Payload.Pic(bmp)) else message = "That photo couldn't be opened. Try another."
        }
    }
    /** One result per photo. A photo that can't be processed never stops the others; it just gets its own note. */
    fun runBatch(uris: List<Uri>) {
        val picked = uris.take(MAX_BATCH)
        busy = true; result = null; message = null; batch = emptyList()
        scope.launch {
            val dir = File(ctx.cacheDir, "batch-${System.currentTimeMillis()}").also { it.mkdirs() }
            val out = ArrayList<BatchItem>()
            // For "one PDF for everything" each page keeps its picture and the pictures are joined at the end.
            val perPage = chain.copy(steps = chain.stepsPerPage)
            val pages = ArrayList<android.graphics.Bitmap>()
            var joinable = chain.combine
            picked.forEachIndexed { i, uri ->
                progress = "Working… ${i + 1} of ${picked.size}"
                val bmp = withContext(Dispatchers.IO) { runCatching { ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } }.getOrNull() }
                if (bmp == null) { out.add(BatchItem(i + 1, note = "Couldn't open this photo.")); return@forEachIndexed }
                val r = if (perPage.steps.isEmpty()) Outcome.Done(Payload.Pic(bmp)) else ChainRunner.run(perPage, Payload.Pic(bmp))
                when (r) {
                    is Outcome.Done -> {
                        if (chain.combine) when (val v = r.value) {
                            is Payload.Pic -> pages.add(v.bmp)
                            is Payload.Doc -> BitmapFactory.decodeByteArray(v.bytes, 0, v.bytes.size)?.takeIf { v.kind == Kind.PHOTO_FILE }?.let { pages.add(it) } ?: run { joinable = false }
                            else -> joinable = false
                        }
                        out.add(BatchItem.of(i + 1, r.value, dir))
                    }
                    is Outcome.Stopped -> out.add(BatchItem(i + 1, note = r.why))
                }
            }
            if (chain.combine && joinable && pages.isNotEmpty()) {
                val skipped = out.count { it.note != null }
                result = Payload.Doc(withContext(Dispatchers.Default) { ChainRunner.onePdf(pages, chain.onePage) }, "pdf")
                if (skipped > 0) message = "$skipped of ${picked.size} couldn't be used and were left out."
                busy = false; progress = ""
                return@launch
            }
            batch = out; busy = false; progress = ""
        }
    }
    // Google's document scanner: finds the page edges, straightens it, takes several pages. It can be missing or stale
    // on some phones and can throw as well as fail, so every path falls back to choosing photos.
    val scanLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        val uris = com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult.fromActivityResultIntent(res.data)?.pages?.map { it.imageUri } ?: emptyList()
        if (uris.isNotEmpty()) runBatch(uris)
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris: List<Uri> ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        if (uris.size == 1 && !chain.combine) {
            val bmp = runCatching { ctx.contentResolver.openInputStream(uris[0])?.use { BitmapFactory.decodeStream(it) } }.getOrNull()
            if (bmp != null) go(Payload.Pic(bmp)) else message = "That photo couldn't be opened. Try another."
        } else runBatch(uris)
    }

    // More ways in: what you say, one contact, a PDF (its words for a text tool, its pages for a photo tool).
    val speak = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
        val said = res.data?.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)?.firstOrNull().orEmpty()
        if (said.isNotBlank()) text = TextTidy.joined(text, said)
    }
    val contact = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
        val picked = res.data?.data?.let { BuilderInputs.contact(ctx, it) }.orEmpty()
        if (picked.isNotBlank()) text = TextTidy.joined(text, picked)
    }
    val pdf = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; message = null
        scope.launch {
            if (chain.start == Kind.TEXT) {
                val words = withContext(Dispatchers.IO) { BuilderInputs.pdfText(ctx, uri) }
                busy = false
                if (words.isNullOrBlank()) message = "That PDF has no words Tenzy can read (it may be a scan). Use a photo tool with Read text, and choose the PDF there."
                else text = TextTidy.joined(text, words)
            } else {
                val pages = withContext(Dispatchers.IO) { BuilderInputs.pdfPages(ctx, uri, MAX_BATCH) }
                busy = false
                if (pages.isEmpty()) message = "That PDF couldn't be opened. Try another." else runBatch(pages)
            }
        }
    }

    fun scan() {
        val noScanner = { message = "The camera scanner isn't available on this phone, so choose photos instead."; picker.launch("image/*") }
        val activity = com.handytools.app.tools.power.DocEngine.findActivity(ctx) ?: return noScanner()
        try {
            val options = com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.Builder()
                .setGalleryImportAllowed(true).setPageLimit(MAX_BATCH)
                .setResultFormats(com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
                .setScannerMode(com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
            com.google.mlkit.vision.documentscanner.GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
                .addOnSuccessListener { sender ->
                    try { scanLauncher.launch(androidx.activity.result.IntentSenderRequest.Builder(sender).build()) } catch (_: Throwable) { noScanner() }
                }
                .addOnFailureListener { noScanner() }
        } catch (_: Throwable) { noScanner() }
    }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader(chain.name, chain.steps.joinToString("  ›  ") { it.block.title })
        if (chain.start == Kind.TEXT) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton({
                    val c = paste(ctx)
                    if (c.isBlank()) message = "There is nothing copied to paste." else text = TextTidy.joined(text, c)
                }) { Text("Paste") }
                TextButton({
                    try {
                        speak.launch(android.content.Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                            .putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM))
                    } catch (_: Throwable) { message = "This phone has no voice typing set up. Type or paste instead." }
                }) { Text("Speak") }
                TextButton({
                    try { contact.launch(android.content.Intent(android.content.Intent.ACTION_PICK, android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI)) }
                    catch (_: Throwable) { message = "This phone has no contacts app to pick from." }
                }) { Text("Contact") }
                TextButton({ pdf.launch("application/pdf") }) { Text("PDF") }
            }
            OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp), label = { Text("Your text") })
            HPrimaryButton("Run", enabled = text.isNotBlank() && !busy) { go(Payload.Words(text)) }
        } else {
            HPrimaryButton("Choose photos", enabled = !busy) { picker.launch("image/*") }
            HSecondaryButton("Scan a document") { scan() }
            HSecondaryButton("Choose a PDF") { pdf.launch("application/pdf") }
            Text(if (chain.combine) "Pick or scan as many pages as you need. They all go into one PDF." else "Pick one, or up to $MAX_BATCH at once. Each one gets the same steps.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        if (busy) Text(progress.ifEmpty { "Working…" }, color = Handy.palette.textSecondary)
        message?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
        when (val r = result) {
            is Payload.Words -> {
                Text(r.text, style = MaterialTheme.typography.bodyMedium)
                HSecondaryButton("Copy") { (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", r.text)) }
            }
            is Payload.Pic -> {
                Image(r.bmp.asImageBitmap(), null, Modifier.heightIn(max = 320.dp))
                HPrimaryButton("Save or share") {
                    val f = File(ctx.cacheDir, TextTidy.fileName(chain.fileName, chain.name, ext = "jpg")).also { it.writeBytes(MediaEngine.jpeg(r.bmp, 92)) }
                    Share.file(ctx, f, "image/jpeg")
                }
            }
            is Payload.Doc -> {
                Text("${r.bytes.size / 1024} KB · ${r.ext.uppercase()}", style = MaterialTheme.typography.bodySmall)
                HPrimaryButton("Save or share") {
                    val f = File(ctx.cacheDir, TextTidy.fileName(chain.fileName, chain.name, ext = r.ext)).also { it.writeBytes(r.bytes) }
                    Share.file(ctx, f, mimeFor(r.ext))
                }
            }
            null -> {}
        }
        // The tool's own ending: open email, messages or WhatsApp already filled in. If that app isn't on this phone,
        // fall back to the share menu so the result always has somewhere to go.
        val fin = chain.finish
        val okItems = batch.filter { it.note == null }
        if (fin != null && fin.kind != "share" && (result != null || okItems.isNotEmpty())) {
            HPrimaryButton(fin.label) {
                if (fin.kind == "open") {
                    // "Open it": follow the link the tool made (a WhatsApp chat, a cleaned link). No link: say so; the result stays on screen.
                    val t = (result as? Payload.Words)?.text ?: ""
                    val found = TextTidy.details(t).links.firstOrNull() ?: t.trim()
                    val url = if (found.startsWith("http", ignoreCase = true)) found else "https://$found"
                    val opened = found.isNotEmpty() && !found.contains(' ') && runCatching {
                        ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, Uri.parse(url)).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
                    }.isSuccess
                    if (!opened) message = "There was no link to open. The result is shown above to copy."
                    return@HPrimaryButton
                }
                val files = ArrayList<File>(); var text: String? = null
                when (val r = result) {
                    is Payload.Words -> text = r.text
                    is Payload.Pic -> files.add(File(ctx.cacheDir, TextTidy.fileName(chain.fileName, chain.name, ext = "jpg")).also { it.writeBytes(MediaEngine.jpeg(r.bmp, 92)) })
                    is Payload.Doc -> files.add(File(ctx.cacheDir, TextTidy.fileName(chain.fileName, chain.name, ext = r.ext)).also { it.writeBytes(r.bytes) })
                    null -> { files.addAll(okItems.mapNotNull { it.file }); text = okItems.mapNotNull { it.text }.joinToString("\n\n").ifEmpty { null } }
                }
                val mime = files.map { it.extension }.distinct().singleOrNull()?.let { mimeFor(it) } ?: "*/*"
                if (!Share.sendTo(ctx, fin.kind, fin.recipients, chain.name, text, files, mime)) {
                    message = "${Finish.title(fin.kind)} isn't available on this phone, so here is the share menu instead."
                    if (files.isNotEmpty()) Share.files(ctx, files, mime) else if (text != null) Share.text(ctx, text)
                }
            }
        }
        if (batch.isNotEmpty()) {
            val ok = batch.filter { it.note == null }
            Text("${ok.size} of ${batch.size} done", style = MaterialTheme.typography.titleMedium)
            batch.forEach { b ->
                HCard(Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(HandyTokens.Space12), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        Text("Photo ${b.n}", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                        Text(b.note ?: b.summary, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                }
            }
            val files = ok.mapNotNull { it.file }
            if (files.isNotEmpty()) {
                val mime = files.map { it.extension }.distinct().singleOrNull()?.let { mimeFor(it) } ?: "*/*"
                HPrimaryButton("Save or share all (${files.size})") { Share.files(ctx, files, mime) }
            }
            val texts = ok.mapNotNull { b -> b.text?.let { "Photo ${b.n}\n$it" } }
            if (texts.isNotEmpty()) HSecondaryButton("Copy all text") {
                (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", texts.joinToString("\n\n")))
            }
        }
        HSecondaryButton("Done") { onDone() }
    }
}

private const val MAX_BATCH = 20

internal fun mimeFor(ext: String): String = when (ext) {
    "jpg", "jpeg" -> "image/jpeg"; "png" -> "image/png"; "vcf" -> "text/x-vcard"; "ics" -> "text/calendar"; "csv" -> "text/csv"; "pdf" -> "application/pdf"; else -> "*/*"
}

/** One photo's outcome in a batch run. Results are written to a cache folder straight away so twenty full-size
 *  results never sit in memory together. */
internal class BatchItem(val n: Int, val file: File? = null, val text: String? = null, val summary: String = "", val note: String? = null) {
    companion object {
        fun of(n: Int, p: Payload, dir: File): BatchItem = try {
            when (p) {
                is Payload.Words -> BatchItem(n, text = p.text, summary = "${p.text.length} characters")
                is Payload.Pic -> File(dir, "Tenzy-$n.jpg").also { it.writeBytes(MediaEngine.jpeg(p.bmp, 92)) }.let { BatchItem(n, file = it, summary = "${it.length() / 1024} KB · JPG") }
                is Payload.Doc -> File(dir, "Tenzy-$n.${p.ext}").also { it.writeBytes(p.bytes) }.let { BatchItem(n, file = it, summary = "${p.bytes.size / 1024} KB · ${p.ext.uppercase()}") }
            }
        } catch (_: Exception) { BatchItem(n, note = "Couldn't save this result.") }
    }
}
