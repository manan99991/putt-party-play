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
 * "Share to Tenzy" and "Start with what you have": a photo, video, recording, PDF, link or text is already in hand.
 * Pick a tool and it runs on it straight away; the result screen has Share, so it can go on to WhatsApp, email or
 * anywhere else. The person's own tools come first, and only tools this phone can run are listed.
 */
@Composable
fun ShareToToolScreen(uri: Uri?, mime: String? = "image/*", text: String? = null, otherWay: String = "Just open the file", onOpenInstead: () -> Unit) {
    val ctx = LocalContext.current
    val kind = kindOf(if (uri != null) mime else null, !text.isNullOrBlank()) ?: Kind.IMAGE
    val tools = remember(kind) { ChainOffers.forKind(kind, ChainStore.load(ctx), ChainStore.lastShared(ctx)).filter { ExtraSteps.unavailable(ctx, it) == null } }
    var running by remember { mutableStateOf<Chain?>(null) }
    running?.let { c -> ChainRunScreen(c, initial = uri, initialKind = kind, initialText = if (kind == Kind.TEXT) text else null) { running = null }; return }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("What to do with ${if (kind == Kind.TEXT) "this" else "this " + kind.label.removePrefix("a ")}", "Pick one. It runs right away, and the result is ready to share on.")
        if (kind == Kind.TEXT && text != null) Text(text.take(200), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 3)
        if (tools.isEmpty()) Text("No tool takes this yet. Open Build your own, tap Blank, and build one that starts with ${kind.label}.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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
        HSecondaryButton(otherWay) { onOpenInstead() }
    }
}

private fun defaults(b: Block): Map<String, String> = when (b) {
    Block.SHRINK -> mapOf("mb" to "2"); Block.SUMMARIZE -> mapOf("sentences" to "3"); Block.CONVERT -> mapOf("format" to "JPG")
    Block.WATERMARK -> mapOf("text" to "For verification only"); Block.STAMP -> mapOf("marks" to StampPlan.STANDARD); Block.RETURN_BY -> mapOf("days" to "30"); Block.VIDEO_SHRINK -> mapOf("mb" to "25"); Block.RESIZE_PHOTO -> mapOf("size" to "413x531")
    Block.ADD_TO_LIST -> mapOf("list" to TextTidy.DEFAULT_LIST)
    Block.CHAT_LINK -> mapOf("cc" to TextTidy.callingCode(java.util.Locale.getDefault().country))
    Block.VIDEO_TRIM -> mapOf("side" to "first", "secs" to "30"); Block.VIDEO_ROTATE -> mapOf("turn" to "right")
    Block.TRANSLATE -> mapOf("to" to "en"); Block.REWRITE -> mapOf("style" to "clear")
    Block.PDF_SHRINK -> mapOf("mb" to "5"); Block.PDF_LOCK -> mapOf("password" to ""); Block.PDF_PAGES -> mapOf("pages" to "")
    Block.EMOJI_FACES -> mapOf("emoji" to TextTidy.FACE_EMOJIS[0]); Block.MEME -> mapOf("top" to "", "bottom" to "")
    Block.VIDEO_SPEED -> mapOf("speed" to "slow"); Block.VIDEO_LOOP -> mapOf("style" to "boomerang")
    Block.ART_FILTER -> mapOf("style" to "sketch"); Block.VOICE_CHANGE -> mapOf("voice" to "chipmunk")
    else -> emptyMap()
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
    var showHistory by remember { mutableStateOf(false) }
    var linking by remember { mutableStateOf<Chain?>(null) }
    val prefs = remember { ctx.getSharedPreferences("builder", Context.MODE_PRIVATE) }
    var introSeen by remember { mutableStateOf(prefs.getBoolean("introSeen", false)) }
    fun setIntro(seen: Boolean) { introSeen = seen; prefs.edit().putBoolean("introSeen", seen).apply() }
    var have by remember { mutableStateOf<Kind?>(null) }     // "What do you have?": narrows the starters
    var runOn by remember { mutableStateOf<Uri?>(null) }      // the new photo a tapped "run this tool" notification came with
    var editHint by remember { mutableStateOf<String?>(null) }   // shown above the steps after Describe it, when the request was only half said
    var renaming by remember { mutableStateOf<Chain?>(null) }
    var newName by remember { mutableStateOf("") }
    // "Start with what you have": the thing picked (a file with its type, or text), waiting for a tool to be chosen.
    var givenUri by remember { mutableStateOf<Uri?>(null) }
    var givenMime by remember { mutableStateOf<String?>(null) }
    var givenText by remember { mutableStateOf<String?>(null) }
    fun give(uri: Uri?) {
        if (uri == null) return
        val mime = ctx.contentResolver.getType(uri)
        if (kindOf(mime, false) == null) note = "Tenzy has no tool for that kind of file yet." else { note = null; givenMime = mime; givenUri = uri }
    }
    val havePhoto = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? -> give(uri) }
    val haveFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? -> give(uri) }

    // A tapped reminder lands here: open that tool ready to run.
    val reminded = ToolReminders.pending
    LaunchedEffect(reminded) {
        if (reminded != null) {
            mine.firstOrNull { it.id == reminded }?.let { editing = null; runOn = ToolReminders.pendingPhoto; running = it }
            ToolReminders.pending = null; ToolReminders.pendingPhoto = null
        }
    }

    editing?.let { c ->
        ChainEditor(c, hint = editHint, onCancel = { editing = null; editHint = null }) { saved ->
            val i = mine.indexOfFirst { it.id == saved.id }
            if (i >= 0) mine[i] = saved else mine.add(saved)
            saveAll(); editing = null; editHint = null
        }
        return
    }
    if (givenUri != null || givenText != null) {
        ShareToToolScreen(givenUri, givenMime, givenText, otherWay = "Back") { givenUri = null; givenMime = null; givenText = null }
        return
    }
    renaming?.let { r ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { renaming = null },
            title = { Text("Name this tool") },
            text = { OutlinedTextField(newName, { newName = it }, singleLine = true, label = { Text("Name") }) },
            confirmButton = { TextButton({
                val name = newName.trim()
                val i = mine.indexOfFirst { it.id == r.id }
                if (name.isNotEmpty() && i >= 0) { mine[i] = mine[i].copy(name = name); saveAll() }
                renaming = null
            }) { Text("Save") } },
            dismissButton = { TextButton({ renaming = null }) { Text("Cancel") } })
    }
    running?.let { c -> ChainRunScreen(c, initial = runOn) { running = null; runOn = null }; return }
    if (showSheets) { SheetsScreen { showSheets = false }; return }
    if (showHistory) { HistoryScreen { showHistory = false }; return }
    linking?.let { c -> ToolLinkDialog(c) { linking = null } }

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
                Text("Say what you want in your own words. Spelling doesn't matter, and half a sentence is enough. Tenzy lines up the steps and shows you before anything runs.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                OutlinedTextField(ask, { ask = it }, Modifier.fillMaxWidth(), placeholder = { Text("e.g. shrink a photo under 1 MB and remove its location") }, minLines = 1, maxLines = 3)
                HPrimaryButton("Build it for me", enabled = ask.isNotBlank()) {
                    val g = ChainPlanner.guess(ask)
                    if (g != null) {
                        editHint = if (g.second) null else "That wasn't much to go on, so this is my best guess. Change, add or remove any step before you save."
                        editing = g.first; note = null
                    }
                    else note = "I couldn't tell what you'd like done. Say what you have (a photo, a PDF, a video, a recording, a link or some text) and what should happen to it."
                }
            }
        }
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(HandyTokens.Space16), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                Text("Start with what you have", style = MaterialTheme.typography.titleMedium)
                Text("Pick it, and Tenzy shows the tools that fit. No need to know which one you want.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    OutlinedButton({ havePhoto.launch("image/*") }) { Text("Photo") }
                    OutlinedButton({ havePhoto.launch("video/*") }) { Text("Video") }
                    OutlinedButton({ haveFile.launch(arrayOf("application/pdf", "audio/*")) }) { Text("PDF or recording") }
                    OutlinedButton({
                        val c = paste(ctx)
                        if (c.isBlank()) note = "There is nothing copied to paste. Copy some text or a link first." else { note = null; givenText = c }
                    }) { Text("Paste") }
                }
            }
        }
        note?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
        if (mine.isNotEmpty()) {
            Text("My tools", style = MaterialTheme.typography.titleMedium)
            mine.toList().forEach { c ->
                ChainRow(c, onRun = { running = c }, onEdit = { editHint = null; editing = c }, onCopy = { copy(ctx, c); note = "Copied. Paste it into Tenzy on another phone." }, onLink = { linking = c }, onDelete = { mine.removeAll { it.id == c.id }; saveAll() },
                    onRename = { newName = c.name; renaming = c },
                    onTop = if (mine.firstOrNull()?.id == c.id) null else ({ mine.removeAll { it.id == c.id }; mine.add(0, c); saveAll(); note = "${c.name} is now first." }),
                    onPin = { note = if (pinToHome(ctx, c)) "Follow the phone's prompt to put ${c.name} on your Home screen." else "This phone's Home screen doesn't take shortcuts from apps." },
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
        val historyCount = remember { RunHistory.all(ctx).size }
        if (historyCount > 0) HCard(Modifier.fillMaxWidth(), onClick = { showHistory = true }) {
            Column(Modifier.padding(HandyTokens.Space12)) {
                Text("Recent results", style = MaterialTheme.typography.titleSmall)
                Text(if (historyCount == 1) "The last thing a tool made" else "The last $historyCount things your tools made", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Start from a template", style = MaterialTheme.typography.titleMedium)
            Row {
                TextButton({ editHint = null; editing = Chain.blank() }) { Text("Blank") }
                TextButton({
                    val c = ToolLink.chain(paste(ctx))
                    if (c != null) { if (BuilderLimits.canSave(mine.size, premium)) { mine.add(c); saveAll(); note = "Added ${c.name}." } else proForSave() } else note = "Copy a tool from another Tenzy first, then tap Paste. Tools that use steps this phone doesn't have can't be added."
                }) { Text("Paste") }
            }
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            listOf<Pair<String, Kind?>>("All" to null, "Photo" to Kind.IMAGE, "Text" to Kind.TEXT, "Video" to Kind.VIDEO, "Sound" to Kind.AUDIO, "PDF" to Kind.PDF).forEach { (label, k) ->
                if (have == k) Button({ have = k }) { Text(label) } else OutlinedButton({ have = k }) { Text(label) }
            }
        }
        // Only starters this phone can run. One that needs something it lacks is simply not offered.
        BuilderIntro.starters(have).filter { ExtraSteps.unavailable(ctx, it) == null }.forEach { c ->
            ChainRow(c, onRun = { running = c }, onEdit = { editHint = null; editing = c.copy(id = java.util.UUID.randomUUID().toString(), name = c.name + " (mine)") }, onCopy = { copy(ctx, c); note = "Copied." }, onDelete = null)
        }
        if (introSeen) TextButton({ setIntro(false) }) { Text("How does this work?") }
    }
}

/** A tool as a QR code and a link, to hand to someone else. Shown only once the link page is live ([ToolLink.LIVE]). */
@Composable
private fun ToolLinkDialog(c: Chain, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val link = remember(c.id) { runCatching { ToolLink.link(c) }.getOrNull() }
    val code = remember(link) { link?.let { com.handytools.app.tools.power.CodesEngine.qr(it) } }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDone,
        title = { Text(c.name) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                if (code != null) Image(code.asImageBitmap(), "QR code for this tool", Modifier.fillMaxWidth())
                Text(if (code != null) "Point another phone's camera at this, or send the link. It opens the tool in Tenzy." else "This tool is too big to fit in a QR code. Send the link instead.", style = MaterialTheme.typography.bodySmall)
                Text("The link never carries your email addresses, phone numbers, reminders or a PDF password.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
        },
        confirmButton = {
            TextButton({
                link?.let { l -> runCatching { ctx.startActivity(android.content.Intent.createChooser(android.content.Intent(android.content.Intent.ACTION_SEND).setType("text/plain").putExtra(android.content.Intent.EXTRA_TEXT, l), "Send the link")) } }
            }) { Text("Send the link") }
        },
        dismissButton = { TextButton(onDone) { Text("Done") } },
    )
}

private fun copy(ctx: Context, c: Chain) {
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy tool", c.shareText))
}
/** Puts a tool on the Home screen as its own icon: one tap opens Tenzy with that tool ready to run. False if the launcher can't. */
private fun pinToHome(ctx: Context, c: Chain): Boolean = try {
    if (!androidx.core.content.pm.ShortcutManagerCompat.isRequestPinShortcutSupported(ctx)) false else {
        val open = android.content.Intent(ctx, com.handytools.app.MainActivity::class.java).setAction(android.content.Intent.ACTION_VIEW)
            .putExtra("route", "builder").putExtra("tool", c.id)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val info = androidx.core.content.pm.ShortcutInfoCompat.Builder(ctx, "tool-${c.id}")
            .setShortLabel(c.name.take(24).ifBlank { "Tenzy tool" }).setLongLabel(c.name.ifBlank { "Tenzy tool" })
            .setIcon(androidx.core.graphics.drawable.IconCompat.createWithResource(ctx, com.handytools.app.R.mipmap.ic_launcher))
            .setIntent(open).build()
        androidx.core.content.pm.ShortcutManagerCompat.requestPinShortcut(ctx, info, null)
    }
} catch (_: Throwable) { false }

private fun paste(ctx: Context): String =
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString().orEmpty()

@Composable
private fun ChainRow(c: Chain, onRun: () -> Unit, onEdit: () -> Unit, onCopy: () -> Unit, onDelete: (() -> Unit)?, onDuplicate: (() -> Unit)? = null,
                     onRename: (() -> Unit)? = null, onTop: (() -> Unit)? = null, onPin: (() -> Unit)? = null, onLink: (() -> Unit)? = null) {
    var menu by remember { mutableStateOf(false) }
    HCard(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(HandyTokens.Space12), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(c.name, style = MaterialTheme.typography.titleSmall)
                Text(c.steps.joinToString("  ›  ") { it.block.title }, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                if (ExtraSteps.unavailable(LocalContext.current, c) != null) Text("Has a step this phone can't run", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                if (c.auto.isNotEmpty()) Text(AutoRun.label(c.auto), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                c.schedule?.let { w -> Text("Reminder: " + w.label(android.text.format.DateFormat.is24HourFormat(LocalContext.current)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary) }
            }
            TextButton(onRun) { Text("Run") }
            TextButton({ menu = true }) { Text("More") }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text(if (onDelete == null) "Edit a copy" else "Edit") }, onClick = { menu = false; onEdit() })
                if (onRename != null) DropdownMenuItem(text = { Text("Rename") }, onClick = { menu = false; onRename() })
                if (onPin != null) DropdownMenuItem(text = { Text("Add to Home screen") }, onClick = { menu = false; onPin() })
                if (onTop != null) DropdownMenuItem(text = { Text("Move to top") }, onClick = { menu = false; onTop() })
                if (onDuplicate != null) DropdownMenuItem(text = { Text("Duplicate") }, onClick = { menu = false; onDuplicate() })
                DropdownMenuItem(text = { Text("Copy to share") }, onClick = { menu = false; onCopy() })
                if (onLink != null && ToolLink.LIVE) DropdownMenuItem(text = { Text("Share as a link or QR code") }, onClick = { menu = false; onLink() })
                if (onDelete != null) DropdownMenuItem(text = { Text("Delete") }, onClick = { menu = false; onDelete() })
            }
        }
    }
}

/** A flow from what you give, through each step, to what you get, with each step tried on a sample as you build. */
@Composable
private fun ChainEditor(start: Chain, hint: String? = null, onCancel: () -> Unit, onSave: (Chain) -> Unit) {
    var chain by remember { mutableStateOf(start) }
    var addMenu by remember { mutableStateOf(false) }
    val previews = remember { mutableStateListOf<Preview?>() }
    // What the person said they start with, before there is a first step to tell us.
    var startChoice by remember { mutableStateOf<Kind?>(null) }
    val ctx = LocalContext.current
    val fitting = chain.end?.let { e -> Block.values().filter { e.feeds(it.takes) } } ?: startChoice?.let { BlockGoals.starting(it) } ?: emptyList()
    // Steps that fit here and that this phone can run, and the ones that fit but it can't.
    val options = fitting.filter { ExtraSteps.unavailable(ctx, it) == null }
    val missing = fitting.filter { ExtraSteps.unavailable(ctx, it) != null }
    val problem = chain.problem()

    LaunchedEffect(chain.steps) {
        previews.clear(); chain.steps.forEach { previews.add(null) }
        val first = chain.steps.firstOrNull() ?: return@LaunchedEffect
        if (first.block.takes == Kind.VIDEO || first.block.takes == Kind.AUDIO || first.block.takes == Kind.PDF) {
            // There is no sample video, recording or PDF to try steps on, so say what each one will do instead of showing a result.
            chain.steps.forEachIndexed { i, s -> previews[i] = ExtraSteps.unavailable(ctx, s.block)?.let { Preview.Bad("Not available on this phone. $it") } ?: Preview.Doc(s.block.blurb) }
            return@LaunchedEffect
        }
        delay(250)
        var v: Payload = when {
            first.block == Block.READ_TEXT -> Payload.Pic(sampleReceipt())
            first.block == Block.READ_CODE -> Payload.Pic(com.handytools.app.tools.power.CodesEngine.qr("https://example.com/sale?utm_source=poster") ?: samplePhoto())
            first.block == Block.PAGE_TEXT -> Payload.Words("https://example.com/article")
            first.block.takes == Kind.TEXT -> Payload.Words(SAMPLE_TEXT)
            else -> Payload.Pic(samplePhoto())
        }
        for ((i, s) in chain.steps.withIndex()) {
            if (!v.kind.feeds(s.block.takes)) { previews[i] = Preview.Bad("Needs ${s.block.takes.label} from the step above."); continue }
            val why = ExtraSteps.unavailable(ctx, s.block)
            if (why != null) { previews[i] = Preview.Bad("Not available on this phone. $why"); return@LaunchedEffect }
            if (s.block in ExtraSteps.NO_PREVIEW) {
                // These need a voice, a translator or a download, so the sample isn't run through them.
                previews[i] = Preview.Doc(s.block.blurb)
                if (s.block.gives == Kind.TEXT) continue          // the steps below still preview, on the text as it was
                for (j in i + 1 until chain.steps.size) previews[j] = Preview.Doc(chain.steps[j].block.blurb)
                return@LaunchedEffect
            }
            when (val r = ChainRunner.apply(s, v, dryRun = true)) {   // a preview never saves anything
                is Outcome.Done -> { v = r.value; previews[i] = Preview.of(r.value) }
                is Outcome.Stopped -> { previews[i] = Preview.Bad(r.why); return@LaunchedEffect }
            }
        }
    }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        ToolHeader("Build a tool", "Each step is tried on a sample so you can see it work.")
        OutlinedTextField(chain.name, { chain = chain.copy(name = it) }, Modifier.fillMaxWidth(), label = { Text("Name your tool") }, singleLine = true)
        if ((chain.name.isBlank() || chain.name.trim() == "My tool") && chain.steps.isNotEmpty())
            Text("No name yet. It will be saved as \u201C${ChainPlanner.autoName(chain)}\u201D.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        hint?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary) }
        Text(if (chain.steps.isEmpty()) "You give it a photo, text, a video, a recording or a PDF. The first step decides which." else "You give it ${chain.start.label}", style = MaterialTheme.typography.titleSmall)
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
                Button({ startChoice = Kind.VIDEO }, Modifier.weight(1f)) { Text("A video") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                Button({ startChoice = Kind.AUDIO }, Modifier.weight(1f)) { Text("A recording") }
                Button({ startChoice = Kind.PDF }, Modifier.weight(1f)) { Text("A PDF") }
            }
            Text("A photo tool also takes scans, PDF pages and QR codes. A text tool also takes a link, what you say, a contact, where you are, or the words in a PDF. A recording tool writes out what was said.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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
                if (missing.isNotEmpty()) {
                    Text("Not on this phone", style = MaterialTheme.typography.labelMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = HandyTokens.Space12, vertical = HandyTokens.Space4))
                    missing.forEach { b -> DropdownMenuItem(text = { Text(b.title) }, onClick = {}, enabled = false) }
                }
            }
            missing.firstOrNull()?.let { first ->
                Text(if (missing.size == 1) "${first.title} is greyed out on this phone. ${ExtraSteps.unavailable(ctx, first)}" else "${missing.size} steps are greyed out because this phone can't run them. Everything else works.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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
                    androidx.compose.material3.Switch(chain.combine, { on -> chain = chain.copy(combine = on, onePage = on && chain.onePage, collage = if (on) false else chain.collage, gif = if (on) false else chain.gif, versus = if (on) false else chain.versus) })
                    Text("  Put all pages or photos into one PDF", style = MaterialTheme.typography.bodyMedium)
                }
                if (chain.combine) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.onePage, { on -> chain = chain.copy(onePage = on) })
                    Text("  All on a single page (both sides of an ID)", style = MaterialTheme.typography.bodyMedium)
                }
                if (it == Kind.IMAGE || it == Kind.PHOTO_FILE) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.collage, { on -> chain = if (on) chain.copy(collage = true, combine = false, onePage = false, gif = false, versus = false) else chain.copy(collage = false) })
                    Text("  Put all photos into one picture (a collage)", style = MaterialTheme.typography.bodyMedium)
                }
                if (it == Kind.IMAGE || it == Kind.PHOTO_FILE) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.gif, { on -> chain = if (on) chain.copy(gif = true, collage = false, combine = false, onePage = false, versus = false) else chain.copy(gif = false) })
                    Text("  Play all photos as one GIF", style = MaterialTheme.typography.bodyMedium)
                }
                if (it == Kind.IMAGE || it == Kind.PHOTO_FILE) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Switch(chain.versus, { on -> chain = if (on) chain.copy(versus = true, gif = false, collage = false, combine = false, onePage = false) else chain.copy(versus = false) })
                    Text("  Before and after: two photos side by side", style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (chain.start == Kind.PDF && it == Kind.PDF) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                androidx.compose.material3.Switch(chain.combine, { on -> chain = chain.copy(combine = on) })
                Text("  Join several PDFs into one", style = MaterialTheme.typography.bodyMedium)
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
        // A name is optional: a tool saved without one is named for what it does.
        HPrimaryButton("Save", enabled = problem == null) { onSave(chain.copy(name = ChainPlanner.savedName(chain))) }
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
        Block.VIDEO_SHRINK -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val mb = TextTidy.videoLimit(s.settings["mb"])
            TextTidy.VIDEO_LIMITS.forEach { m -> TextButton({ set("mb", m.toString()) }) { Text(if (m == mb) "● $m MB" else "$m MB") } }
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
        Block.VIDEO_TRIM -> {
            Row {
                listOf("first" to "The start", "last" to "The end").forEach { (id, label) ->
                    TextButton({ set("side", id) }) { Text(if ((if (s.settings["side"] == "last") "last" else "first") == id) "● $label" else label) }
                }
            }
            Row(Modifier.horizontalScroll(rememberScrollState())) {
                val secs = s.settings["secs"]?.toIntOrNull() ?: 30
                TextTidy.TRIM_LENGTHS.forEach { n -> TextButton({ set("secs", n.toString()) }) { Text(if (n == secs) "● $n sec" else "$n sec") } }
            }
        }
        Block.VIDEO_ROTATE -> Row {
            listOf("right" to "Right", "left" to "Left", "flip" to "Upside down").forEach { (id, label) ->
                TextButton({ set("turn", id) }) { Text(if ((s.settings["turn"] ?: "right") == id) "● $label" else label) }
            }
        }
        Block.TRANSLATE -> {
            var open by remember { mutableStateOf(false) }
            val to = TextTidy.languageCode(s.settings["to"])
            OutlinedButton({ open = true }) { Text("Into ${TextTidy.languageName(to)}") }
            DropdownMenu(open, { open = false }) {
                TextTidy.LANGUAGES.forEach { (code, name) -> DropdownMenuItem(text = { Text(name) }, onClick = { open = false; set("to", code) }) }
            }
            Text("The first time you use a language, the phone downloads it and needs a connection.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.REWRITE -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val style = TextTidy.rewriteStyle(s.settings["style"])
            TextTidy.REWRITE_STYLES.forEach { (id, label) -> TextButton({ set("style", id) }) { Text(if (id == style) "● $label" else label) } }
        }
        Block.PDF_SHRINK -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val mb = TextTidy.pdfLimit(s.settings["mb"])
            TextTidy.PDF_LIMITS.forEach { m -> TextButton({ set("mb", m.toString()) }) { Text(if (m == mb) "● $m MB" else "$m MB") } }
        }
        Block.PDF_LOCK -> {
            OutlinedTextField(s.settings["password"] ?: "", { v -> set("password", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Password") },
                visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation())
            Text("Kept on this phone with the tool. It is left out when you copy the tool to share.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.PDF_PAGES ->
            OutlinedTextField(s.settings["pages"] ?: "", { v -> set("pages", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Pages, e.g. 1-3, 5 (empty keeps all)") })
        Block.EMOJI_FACES -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val now = TextTidy.faceEmoji(s.settings["emoji"])
            TextTidy.FACE_EMOJIS.forEach { e -> TextButton({ set("emoji", e) }) { Text(if (e == now) "● $e" else e) } }
        }
        Block.MEME -> {
            OutlinedTextField(s.settings["top"] ?: "", { v -> set("top", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Top line") })
            OutlinedTextField(s.settings["bottom"] ?: "", { v -> set("bottom", v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Bottom line") })
            Text("Leave them empty to type new words every time you run the tool.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Block.VIDEO_SPEED -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val now = TextTidy.SPEEDS.firstOrNull { it.first == s.settings["speed"] }?.first ?: "slow"
            TextTidy.SPEEDS.forEach { (id, label, _) -> TextButton({ set("speed", id) }) { Text(if (id == now) "● $label" else label) } }
        }
        Block.ART_FILTER -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val now = PixelArt.style(s.settings["style"])
            PixelArt.STYLES.forEach { (id, label) -> TextButton({ set("style", id) }) { Text(if (id == now) "● $label" else label) } }
        }
        Block.VOICE_CHANGE -> Row(Modifier.horizontalScroll(rememberScrollState())) {
            val now = TextTidy.VOICES.firstOrNull { it.first == s.settings["voice"] }?.first ?: "chipmunk"
            TextTidy.VOICES.forEach { (id, label, _) -> TextButton({ set("voice", id) }) { Text(if (id == now) "● $label" else label) } }
        }
        Block.VIDEO_LOOP -> Row {
            listOf("boomerang" to "Forwards and back", "reverse" to "Backwards").forEach { (id, label) ->
                TextButton({ set("style", id) }) { Text(if ((if (s.settings["style"] == "reverse") "reverse" else "boomerang") == id) "● $label" else label) }
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
            is Payload.Clip -> Doc("Video")
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
private fun ChainRunScreen(chain: Chain, initial: Uri? = null, initialKind: Kind = Kind.IMAGE, initialText: String? = null, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<Payload?>(null) }
    var batch by remember { mutableStateOf<List<BatchItem>>(emptyList()) }
    var progress by remember { mutableStateOf("") }
    // What each result of a many-at-once run is called in the list: a photo, or a file.
    var noun by remember { mutableStateOf("Photo") }
    // A meme's words can be typed fresh for each run.
    val memeStep = remember(chain) { chain.steps.firstOrNull { it.block == Block.MEME } }
    var memeTop by remember { mutableStateOf(memeStep?.settings?.get("top").orEmpty()) }
    var memeBottom by remember { mutableStateOf(memeStep?.settings?.get("bottom").orEmpty()) }
    /** The tool as it runs this time: a meme step takes the words typed on this screen. */
    fun live(): Chain = if (memeStep == null) chain else chain.copy(steps = chain.steps.map { s ->
        if (s.block == Block.MEME) s.copy(settings = s.settings + mapOf("top" to memeTop, "bottom" to memeBottom)) else s })

    /** So the result is still there after this screen is closed. */
    fun keep(made: Payload) { scope.launch(Dispatchers.IO) { RunHistory.add(ctx, chain.name, TextTidy.fileName(chain.fileName, chain.name, ext = "").trimEnd('.'), made) } }

    fun go(input: Payload) {
        busy = true; result = null; message = null; batch = emptyList()
        scope.launch {
            when (val r = ChainRunner.run(live(), input)) {
                is Outcome.Done -> { result = r.value; keep(r.value) }
                is Outcome.Stopped -> message = r.why
            }
            busy = false
        }
    }
    // Opened from "Share to Tenzy": the shared photo runs straight away, no picking needed.
    // The same for anything handed over before the tool was chosen: a video, a recording, a PDF, or text.
    LaunchedEffect(initial, initialText) {
        if (initialText != null) { text = initialText; go(Payload.Words(initialText)) }
        else if (initial != null) when (initialKind) {
            Kind.VIDEO -> go(Payload.Clip(initial))
            Kind.AUDIO, Kind.PDF -> {
                val bytes = withContext(Dispatchers.IO) { BuilderInputs.bytes(ctx, initial) }
                if (bytes == null) message = "That file couldn't be opened. Try another."
                else go(Payload.Doc(bytes, if (initialKind == Kind.PDF) "pdf" else BuilderInputs.audioExt(ctx, initial)))
            }
            else -> {
                val bmp = withContext(Dispatchers.IO) { runCatching { ctx.contentResolver.openInputStream(initial)?.use { BitmapFactory.decodeStream(it) } }.getOrNull() }
                if (bmp != null) go(Payload.Pic(bmp)) else message = "That photo couldn't be opened. Try another."
            }
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
            val perPage = live().let { it.copy(steps = it.stepsPerPage) }
            val pages = ArrayList<android.graphics.Bitmap>()
            var joinable = chain.combine || chain.collage || chain.gif || chain.versus
            noun = "Photo"
            picked.forEachIndexed { i, uri ->
                progress = "Working… ${i + 1} of ${picked.size}"
                val bmp = withContext(Dispatchers.IO) { runCatching { ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } }.getOrNull() }
                if (bmp == null) { out.add(BatchItem(i + 1, note = "Couldn't open this photo.")); return@forEachIndexed }
                val r = if (perPage.steps.isEmpty()) Outcome.Done(Payload.Pic(bmp)) else ChainRunner.run(perPage, Payload.Pic(bmp))
                when (r) {
                    is Outcome.Done -> {
                        if (chain.combine || chain.collage || chain.gif || chain.versus) when (val v = r.value) {
                            is Payload.Pic -> pages.add(v.bmp)
                            is Payload.Doc -> BitmapFactory.decodeByteArray(v.bytes, 0, v.bytes.size)?.takeIf { v.kind == Kind.PHOTO_FILE }?.let { pages.add(it) } ?: run { joinable = false }
                            else -> joinable = false
                        }
                        out.add(BatchItem.of(i + 1, r.value, dir))
                    }
                    is Outcome.Stopped -> out.add(BatchItem(i + 1, note = r.why))
                }
            }
            if (chain.versus) {
                // Before and after: the first and the last result side by side.
                if (joinable && pages.size >= 2) {
                    val one = withContext(Dispatchers.Default) { FunSteps.beforeAfter(pages.first(), pages.last()) }
                    result = Payload.Pic(one); keep(Payload.Pic(one))
                } else message = "Before and after needs two photos: pick the before and the after together."
                busy = false; progress = ""
                return@launch
            }
            if (chain.gif && joinable && pages.isNotEmpty()) {
                // One GIF for everything: the results played one after another.
                val skipped = out.count { it.note != null }
                val one = withContext(Dispatchers.Default) { FunSteps.photosGif(pages) }
                if (one != null) {
                    result = Payload.Doc(one, "gif"); keep(Payload.Doc(one, "gif"))
                    if (skipped > 0) message = "$skipped of ${picked.size} couldn't be used and were left out."
                    busy = false; progress = ""
                    return@launch
                }
            }
            if (chain.collage && joinable && pages.isNotEmpty()) {
                // One picture for everything: the results laid out as a collage.
                val skipped = out.count { it.note != null }
                val one = withContext(Dispatchers.Default) { ChainRunner.collage(pages) }
                if (one != null) {
                    result = Payload.Pic(one)
                    if (skipped > 0) message = "$skipped of ${picked.size} couldn't be used and were left out."
                    busy = false; progress = ""
                    return@launch
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
            withContext(Dispatchers.IO) { RunHistory.add(ctx, chain.name, out.filter { it.note == null }.mapNotNull { it.file }, out.filter { it.note == null }.mapNotNull { it.text }.joinToString("\n\n").ifEmpty { null }) }
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
        if (uris.size == 1 && !chain.combine && !chain.collage && !chain.gif && !chain.versus) {
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

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? -> if (uri != null) go(Payload.Clip(uri)) }

    // A recording, or one or more PDFs, for the tools that start with those.
    val audioPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; message = null
        scope.launch {
            val bytes = withContext(Dispatchers.IO) { BuilderInputs.bytes(ctx, uri) }
            if (bytes == null) { busy = false; message = "That recording couldn't be opened. Try another." }
            else go(Payload.Doc(bytes, BuilderInputs.audioExt(ctx, uri)))
        }
    }
    val pdfFiles = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris: List<Uri> ->
        val picked = uris.take(MAX_BATCH)
        if (picked.isEmpty()) return@rememberLauncherForActivityResult
        busy = true; result = null; message = null; batch = emptyList()
        scope.launch {
            val dir = File(ctx.cacheDir, "batch-${System.currentTimeMillis()}").also { it.mkdirs() }
            val out = ArrayList<BatchItem>()
            val joined = ArrayList<ByteArray>()
            var last: Payload? = null
            picked.forEachIndexed { i, uri ->
                progress = "Working… ${i + 1} of ${picked.size}"
                val bytes = withContext(Dispatchers.IO) { BuilderInputs.bytes(ctx, uri) }
                if (bytes == null) { out.add(BatchItem(i + 1, note = "Couldn't open this file.")); return@forEachIndexed }
                when (val r = ChainRunner.run(chain, Payload.Doc(bytes, "pdf"))) {
                    is Outcome.Done -> {
                        last = r.value
                        (r.value as? Payload.Doc)?.takeIf { it.kind == Kind.PDF }?.let { joined.add(it.bytes) }
                        out.add(BatchItem.of(i + 1, r.value, dir))
                    }
                    is Outcome.Stopped -> out.add(BatchItem(i + 1, note = r.why))
                }
            }
            progress = ""
            val ok = out.count { it.note == null }
            // One PDF for everything, when the tool asks for it and every result is a PDF.
            val one = if (chain.combine && joined.size == ok && joined.size > 1) withContext(Dispatchers.IO) { BuilderInputs.joinPdfs(ctx, joined) } else null
            when {
                one != null -> { result = Payload.Doc(one, "pdf"); if (ok < picked.size) message = "${picked.size - ok} of ${picked.size} couldn't be used and were left out." }
                picked.size == 1 && ok == 1 -> result = last
                picked.size == 1 -> message = out.first().note
                else -> { noun = "File"; batch = out }
            }
            busy = false
        }
    }
    val locationAsk = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
        if (granted.values.none { it }) { message = "Tenzy needs the location permission to add where you are. Allow it in Settings, or type the place in."; return@rememberLauncherForActivityResult }
        busy = true; message = null
        scope.launch {
            val here = BuilderInputs.whereAmI(ctx)
            busy = false
            if (here == null) message = "Tenzy couldn't find where you are. Check that Location is switched on, or type the place in." else text = TextTidy.joined(text, here)
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
        ExtraSteps.unavailable(ctx, chain)?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
        if (memeStep != null) {
            OutlinedTextField(memeTop, { memeTop = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Top line") })
            OutlinedTextField(memeBottom, { memeBottom = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Bottom line") })
        }
        if (chain.start == Kind.AUDIO) {
            HPrimaryButton("Choose a recording", enabled = !busy) { audioPicker.launch("audio/*") }
            Text("Pick a voice recording or any sound file. It never leaves this phone.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        } else if (chain.start == Kind.PDF) {
            HPrimaryButton(if (chain.combine) "Choose PDFs" else "Choose a PDF", enabled = !busy) { pdfFiles.launch("application/pdf") }
            Text(if (chain.combine) "Pick the PDFs to join. They go into one PDF in the order the phone lists them." else "Pick one, or several at once. Each one gets the same steps.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        } else if (chain.start == Kind.TEXT) {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.SpaceBetween) {
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
                TextButton({ locationAsk.launch(arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION, android.Manifest.permission.ACCESS_COARSE_LOCATION)) }) { Text("Location") }
            }
            OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp), label = { Text("Your text") })
            HPrimaryButton("Run", enabled = text.isNotBlank() && !busy) { go(Payload.Words(text)) }
        } else if (chain.start == Kind.VIDEO) {
            HPrimaryButton("Choose a video", enabled = !busy) { videoPicker.launch("video/*") }
            Text("Long videos take a little while. Keep Tenzy open until it finishes.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        } else {
            HPrimaryButton("Choose photos", enabled = !busy) { picker.launch("image/*") }
            HSecondaryButton("Scan a document") { scan() }
            HSecondaryButton("Choose a PDF") { pdf.launch("application/pdf") }
            Text(if (chain.combine) "Pick or scan as many pages as you need. They all go into one PDF." else if (chain.collage) "Pick up to $MAX_BATCH photos. They are laid out as one picture." else if (chain.gif) "Pick up to $MAX_BATCH photos. They play one after another as a GIF." else if (chain.versus) "Pick two photos: the before, then the after." else "Pick one, or up to $MAX_BATCH at once. Each one gets the same steps.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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
            is Payload.Clip -> {
                val f = r.uri.path?.let { File(it) }
                Text("Your video is ready" + (f?.takeIf { it.exists() }?.let { " · ${MediaEngine.human(it.length())}" } ?: ""), style = MaterialTheme.typography.titleSmall)
                HPrimaryButton("Save or share") { if (f != null && f.exists()) Share.file(ctx, f, "video/mp4") else message = "The video couldn't be found to share. Run the tool again." }
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
                    is Payload.Clip -> r.uri.path?.let { File(it) }?.takeIf { it.exists() }?.let { files.add(it) }
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
                        Text("$noun ${b.n}", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                        Text(b.note ?: b.summary, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                }
            }
            val files = ok.mapNotNull { it.file }
            if (files.isNotEmpty()) {
                val mime = files.map { it.extension }.distinct().singleOrNull()?.let { mimeFor(it) } ?: "*/*"
                HPrimaryButton("Save or share all (${files.size})") { Share.files(ctx, files, mime) }
            }
            val texts = ok.mapNotNull { b -> b.text?.let { "$noun ${b.n}\n$it" } }
            if (texts.isNotEmpty()) HSecondaryButton("Copy all text") {
                (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", texts.joinToString("\n\n")))
            }
        }
        HSecondaryButton("Done") { onDone() }
    }
}

private const val MAX_BATCH = 20

internal fun mimeFor(ext: String): String = when (ext) {
    "jpg", "jpeg" -> "image/jpeg"; "png" -> "image/png"; "mp4" -> "video/mp4"; "m4a" -> "audio/mp4"; "wav" -> "audio/wav"; "mp3" -> "audio/mpeg"; "gif" -> "image/gif"; "vcf" -> "text/x-vcard"; "ics" -> "text/calendar"; "csv" -> "text/csv"; "pdf" -> "application/pdf"; else -> "*/*"
}

/** One photo's outcome in a batch run. Results are written to a cache folder straight away so twenty full-size
 *  results never sit in memory together. */
internal class BatchItem(val n: Int, val file: File? = null, val text: String? = null, val summary: String = "", val note: String? = null) {
    companion object {
        fun of(n: Int, p: Payload, dir: File): BatchItem = try {
            when (p) {
                is Payload.Words -> BatchItem(n, text = p.text, summary = "${p.text.length} characters")
                is Payload.Pic -> File(dir, "Tenzy-$n.jpg").also { it.writeBytes(MediaEngine.jpeg(p.bmp, 92)) }.let { BatchItem(n, file = it, summary = "${it.length() / 1024} KB · JPG") }
                is Payload.Clip -> p.uri.path?.let { File(it) }?.takeIf { it.exists() }?.let { BatchItem(n, file = it, summary = "${it.length() / 1024} KB · VIDEO") } ?: BatchItem(n, note = "Couldn't save this result.")
                is Payload.Doc -> File(dir, "Tenzy-$n.${p.ext}").also { it.writeBytes(p.bytes) }.let { BatchItem(n, file = it, summary = "${p.bytes.size / 1024} KB · ${p.ext.uppercase()}") }
            }
        } catch (_: Exception) { BatchItem(n, note = "Couldn't save this result.") }
    }
}
