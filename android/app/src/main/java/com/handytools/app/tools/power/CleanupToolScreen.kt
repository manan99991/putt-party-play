package com.handytools.app.tools.power

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Contacts
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.tools.Share
import com.handytools.app.tools.contacts.ContactRec
import com.handytools.app.tools.contacts.ContactsEngine
import com.handytools.app.tools.contacts.ContactsReport
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HCompactButton
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val GRID_CAP = 300

/** Clean Up — free space (photos/videos → recoverable Trash) and tidy contacts. Nothing is deleted outright. */
@Composable
fun CleanupToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var tab by remember { mutableIntStateOf(0) }
    val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    // ---- photo/video permission
    val mediaPerms = remember {
        when {
            Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
            Build.VERSION.SDK_INT >= 29 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
    }
    fun hasMedia() = ContextCompat.checkSelfPermission(ctx, mediaPerms[0]) == PackageManager.PERMISSION_GRANTED
    var mediaGranted by remember { mutableStateOf(hasMedia()) }
    var mediaDenied by remember { mutableStateOf(false) }
    val mediaLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { mediaGranted = hasMedia(); if (!mediaGranted) mediaDenied = true }
    val settingsIntent = remember { Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}")) }

    // ---- scan state
    var scanning by remember { mutableStateOf(false) }
    var phase by remember { mutableStateOf("") }
    var progress by remember { mutableStateOf(0f) }
    var scan by remember { mutableStateOf<CleanScan?>(null) }
    var scanFailed by remember { mutableStateOf(false) }
    var tick by remember { mutableIntStateOf(0) }
    var reviewing by remember { mutableStateOf<String?>(null) }
    var selected by remember { mutableStateOf(setOf<Uri>()) }
    var status by remember { mutableStateOf<String?>(null) }
    val sessionTrash = remember { mutableStateListOf<CleanItem>() }
    var systemTrash by remember { mutableStateOf<List<CleanItem>>(emptyList()) }
    var pending by remember { mutableStateOf<List<CleanItem>>(emptyList()) }
    var confirmPurge by remember { mutableStateOf(false) }

    fun refreshTrash() {
        scope.launch {
            systemTrash = withContext(Dispatchers.IO) {
                if (modern) CleanupEngine.systemTrash(ctx)
                else CleanupEngine.legacyRecords(ctx).map { CleanItem(Uri.fromFile(java.io.File(it.trashed)), it.name, it.size, it.isVideo) }
            }
        }
    }
    LaunchedEffect(mediaGranted) { if (mediaGranted) refreshTrash() }

    fun runScan() {
        if (scanning) return
        scanning = true; scanFailed = false; progress = 0f; phase = "Starting…"; reviewing = null
        scope.launch {
            val r = runCatching {
                withContext(Dispatchers.IO) { CleanupEngine.scan(ctx) { p, f -> scope.launch { phase = p; progress = f } } }
            }.getOrNull()
            scan = r; scanFailed = r == null; scanning = false; tick++
        }
    }

    fun category(id: String): CleanCategory? = scan?.categories?.firstOrNull { it.id == id }

    fun applyTrashed(items: List<CleanItem>) {
        if (items.isEmpty()) return
        val uris = items.map { it.uri }.toHashSet()
        scan?.categories?.forEach { c -> c.items = c.items.filter { it.uri !in uris } }
        sessionTrash.addAll(items)
        selected = selected - uris
        status = "${items.size} moved to Trash · ${CleanupEngine.human(items.sumOf { it.size })} freed"
        reviewing = null; tick++
        HandyHaptics.success(ctx)
        refreshTrash()
    }

    val trashLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        if (res.resultCode == Activity.RESULT_OK) applyTrashed(pending) else status = "Nothing moved — you can try again any time."
        pending = emptyList()
    }
    val restoreLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        if (res.resultCode == Activity.RESULT_OK) { status = "Restored"; sessionTrash.clear(); refreshTrash(); if (scan != null) runScan() }
    }
    val purgeLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        if (res.resultCode == Activity.RESULT_OK) { status = "Deleted forever"; sessionTrash.clear(); refreshTrash() }
    }

    fun moveToTrash() {
        val cat = category(reviewing ?: return) ?: return
        val items = cat.items.filter { it.uri in selected }
        if (items.isEmpty()) return
        val sender = CleanupEngine.trashRequest(ctx, items.map { it.uri }, true)
        if (sender != null) { pending = items; trashLauncher.launch(IntentSenderRequest.Builder(sender).build()) }
        else scope.launch {
            val moved = withContext(Dispatchers.IO) { CleanupEngine.legacyTrash(ctx, items) }
            val movedNames = moved.map { it.trashed }.toHashSet()
            applyTrashed(items.filter { i -> moved.any { it.original.endsWith(i.name) || it.name == i.name } && movedNames.isNotEmpty() })
            if (moved.isEmpty()) status = "Couldn't move those — storage permission may be missing."
        }
    }

    val trashAll = (sessionTrash + systemTrash).distinctBy { it.uri.toString() }
    fun restoreAll() {
        if (modern) {
            val sender = CleanupEngine.trashRequest(ctx, trashAll.map { it.uri }, false) ?: return
            restoreLauncher.launch(IntentSenderRequest.Builder(sender).build())
        } else scope.launch {
            val n = withContext(Dispatchers.IO) { CleanupEngine.legacyRestoreAll(ctx) }
            status = "$n restored"; sessionTrash.clear(); refreshTrash()
        }
    }
    fun purgeAll() {
        if (modern) {
            val sender = CleanupEngine.deleteRequest(ctx, trashAll.map { it.uri }) ?: return
            purgeLauncher.launch(IntentSenderRequest.Builder(sender).build())
        } else scope.launch {
            val n = withContext(Dispatchers.IO) { CleanupEngine.legacyDeleteAll(ctx) }
            status = "$n deleted · ${CleanupEngine.human(trashAll.sumOf { it.size })} freed"; sessionTrash.clear(); refreshTrash()
        }
    }

    // ---- contacts
    fun hasContacts() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
    var contactsGranted by remember { mutableStateOf(hasContacts()) }
    var contactsDenied by remember { mutableStateOf(false) }
    val contactsLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { contactsGranted = hasContacts(); if (!contactsGranted) contactsDenied = true }
    var cReport by remember { mutableStateOf<ContactsReport?>(null) }
    var cSources by remember { mutableStateOf<Map<String, List<String>>>(emptyMap()) }
    var cBusy by remember { mutableStateOf(false) }
    var cNote by remember { mutableStateOf<String?>(null) }
    var dismissed by remember { mutableStateOf(setOf<String>()) }
    var confirmEmpty by remember { mutableStateOf(false) }
    fun groupKey(g: List<ContactRec>) = g.map { it.contactId }.sorted().joinToString(",")

    fun scanContacts() {
        cBusy = true
        scope.launch {
            val r = runCatching { withContext(Dispatchers.IO) { ContactsEngine.scan(ctx) } }.getOrNull()
            cSources = if (r == null) emptyMap() else withContext(Dispatchers.IO) { r.duplicateGroups.associate { g -> groupKey(g) to CleanupEngine.sources(ctx, g) } }
            cReport = r; cBusy = false
            if (r == null) cNote = "Couldn't read contacts."
        }
    }
    LaunchedEffect(contactsGranted, tab) { if (tab == 1 && contactsGranted && cReport == null && !cBusy) scanContacts() }

    // ------------------------------------------------------------------------------------------ UI
    val trashCount = trashAll.size
    val tabs = listOf("Space", "Contacts", if (trashCount > 0) "Trash ($trashCount)" else "Trash")

    PowerToolPage("cleanup", tabs = tabs, selected = tab, onTab = { tab = it }) {
        when (tab) {
            0 -> SpaceTab(
                mediaGranted, mediaDenied, settingsIntent, { mediaLauncher.launch(mediaPerms) },
                scanning, phase, progress, scan, scanFailed, tick, reviewing, selected, status,
                onScan = { runScan() }, onReview = { id -> reviewing = id; selected = category(id)?.items?.map { it.uri }?.toSet() ?: emptySet(); status = null },
                onSelect = { sel -> selected = sel }, onBack = { reviewing = null }, onTrash = { moveToTrash() }
            )
            1 -> ContactsTab(
                contactsGranted, contactsDenied, settingsIntent, { contactsLauncher.launch(arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS)) },
                cReport, cSources, cBusy, cNote, dismissed,
                onMerge = { g -> cBusy = true; scope.launch { runCatching { withContext(Dispatchers.IO) { ContactsEngine.merge(ctx, g) } }; cNote = "Merged · ${g.firstOrNull { it.hasName }?.name ?: "contact"}"; HandyHaptics.success(ctx); scanContacts() } },
                onKeep = { g -> dismissed = dismissed + groupKey(g) },
                onRemoveEmpty = { confirmEmpty = true }, onRescan = { scanContacts() }
            )
            else -> TrashTab(trashAll, modern, status, onRestore = { restoreAll() }, onPurge = { confirmPurge = true })
        }
    }

    if (confirmPurge) {
        AlertDialog(
            onDismissRequest = { confirmPurge = false },
            title = { Text("Delete ${trashAll.size} items forever?") },
            text = { Text("This can't be undone. ${CleanupEngine.human(trashAll.sumOf { it.size })} will be freed.") },
            confirmButton = { TextButton(onClick = { confirmPurge = false; purgeAll() }) { Text("Delete forever", color = HandyColors.Danger) } },
            dismissButton = { TextButton(onClick = { confirmPurge = false }) { Text("Keep in Trash") } }
        )
    }
    if (confirmEmpty) {
        val empties = cReport?.incomplete?.filter { !it.hasName && !it.hasNumber } ?: emptyList()
        AlertDialog(
            onDismissRequest = { confirmEmpty = false },
            title = { Text("Remove ${empties.size} empty contacts?") },
            text = { Text("They have no name and no number, so there's nothing to recover — contacts don't have a Trash. Back up first if you'd like a copy.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmEmpty = false; cBusy = true
                    scope.launch { val n = withContext(Dispatchers.IO) { CleanupEngine.deleteEmpty(ctx, empties) }; cNote = "Removed $n empty contact${if (n == 1) "" else "s"}"; scanContacts() }
                }) { Text("Remove", color = HandyColors.Danger) }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { scope.launch { val f = runCatching { withContext(Dispatchers.IO) { ContactsEngine.exportVcf(ctx) } }.getOrNull(); if (f != null) Share.file(ctx, f, "text/x-vcard") } }) { Text("Back up (.vcf)") }
                    TextButton(onClick = { confirmEmpty = false }) { Text("Cancel") }
                }
            }
        )
    }
}

// ------------------------------------------------------------------------------------------ Space

@Composable
private fun SpaceTab(
    granted: Boolean, denied: Boolean, settingsIntent: Intent, onAsk: () -> Unit,
    scanning: Boolean, phase: String, progress: Float, scan: CleanScan?, scanFailed: Boolean, tick: Int,
    reviewing: String?, selected: Set<Uri>, status: String?,
    onScan: () -> Unit, onReview: (String) -> Unit, onSelect: (Set<Uri>) -> Unit, onBack: () -> Unit, onTrash: () -> Unit,
) {
    if (!granted) {
        if (denied) PermissionCard("Photos & videos", "Tenzy needs to see your photos and videos to find what you can free up.", false, settingsIntent, "Open settings", "Scanned on this phone only — nothing is uploaded.")
        else AskCard("Photos & videos", "Tenzy needs to see your photos and videos to find what you can free up.", "Scanned on this phone only — nothing is uploaded.", onAsk)
    }
    val cat = reviewing?.let { id -> scan?.categories?.firstOrNull { it.id == id } }
    if (cat == null) {
        val reclaim = scan?.categories?.sumOf { it.bytes } ?: 0L
        Spacer(Modifier.height(12.dp))
        Text(if (scan != null) "Up to ${CleanupEngine.human(reclaim)}" else "—", style = MaterialTheme.typography.headlineMedium, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Text(
            when {
                scanning -> phase
                scan != null -> "to free · of ${CleanupEngine.human(scan.usedBytes)} used"
                scanFailed -> "Couldn't scan. Check photo access and try again."
                else -> "Tap Scan to find what you can free up."
            },
            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 12.dp)
        )
        if (scanning) { LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth()); Spacer(Modifier.height(12.dp)) }
        HPrimaryButton(if (scanning) "Scanning…" else if (scan != null) "Rescan" else "Scan photos & videos", enabled = granted && !scanning) { onScan() }
        status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Success, modifier = Modifier.padding(top = 10.dp)) }
        if (scan != null) {
            Spacer(Modifier.height(8.dp))
            val cats = scan.categories
            if (tick >= 0 && cats.all { it.items.isEmpty() }) EmptyState(Icons.Outlined.Image, "Nothing to clean — your photos are tidy.")
            cats.forEach { c ->
                if (c.items.isEmpty()) return@forEach
                HCard(Modifier.fillMaxWidth().padding(top = 10.dp)) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(Handy.palette.accentSoft), contentAlignment = Alignment.Center) {
                            Icon(if (c.id == "videos") Icons.Outlined.Videocam else Icons.Outlined.Image, null, tint = HandyColors.Accent)
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(c.title, style = MaterialTheme.typography.titleMedium)
                            Text("${c.items.size} items · ${CleanupEngine.human(c.bytes)}", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        }
                        HChip("Review", false) { onReview(c.id) }
                    }
                }
            }
        }
    } else {
        val items = cat.items
        val sel = items.filter { it.uri in selected }
        SectionLabel("${cat.title} · ${items.size} items — tap to keep / select")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            HChip("Select all", false) { onSelect(items.map { it.uri }.toSet()) }
            HChip("Keep all", false) { onSelect(emptySet()) }
            HChip("Keep best, select rest", false) {
                // Grouped: keep the largest (= sharpest) of each group. Flat lists: keep the biggest one.
                val keep = if (cat.grouped) items.groupBy { it.group }.values.mapNotNull { g -> g.maxByOrNull { it.size }?.uri }.toSet()
                else setOfNotNull(items.maxByOrNull { it.size }?.uri)
                onSelect(items.map { it.uri }.filter { it !in keep }.toSet())
            }
        }
        Spacer(Modifier.height(10.dp))
        ThumbGrid(items.take(GRID_CAP), selected, cat.grouped) { uri -> onSelect(if (uri in selected) selected - uri else selected + uri) }
        if (items.size > GRID_CAP) NoteText("Showing the first $GRID_CAP of ${items.size}; Select all still covers every one.")
        Spacer(Modifier.height(12.dp))
        HPrimaryButton(if (sel.isEmpty()) "Nothing selected" else "Move ${sel.size} to Trash · frees ${CleanupEngine.human(sel.sumOf { it.size })}", enabled = sel.isNotEmpty(), icon = Icons.Outlined.Delete) { onTrash() }
        Spacer(Modifier.height(8.dp))
        HSecondaryButton("← Back to categories") { onBack() }
    }
    NoteText("Nothing is deleted outright — everything goes to a recoverable Trash. Files are shown in full so you can review before you act.")
}

@Composable
private fun ThumbGrid(items: List<CleanItem>, selected: Set<Uri>, grouped: Boolean, onToggle: (Uri) -> Unit) {
    items.chunked(3).forEach { row ->
        Row(Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            row.forEach { item -> Thumb(item, item.uri in selected, grouped, Modifier.weight(1f)) { onToggle(item.uri) } }
            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

@Composable
private fun Thumb(item: CleanItem, selected: Boolean, grouped: Boolean, modifier: Modifier, onTap: (() -> Unit)?) {
    val ctx = LocalContext.current
    val bmp by produceState<Bitmap?>(null, item.uri) { value = withContext(Dispatchers.IO) { CleanupEngine.thumbnail(ctx, item.uri, item.isVideo) } }
    val base = modifier.aspectRatio(1f).clip(RoundedCornerShape(10.dp)).background(MaterialTheme.colorScheme.surface)
        .border(if (selected) 2.dp else 1.dp, if (selected) HandyColors.Accent else Handy.palette.border, RoundedCornerShape(10.dp))
    Box(if (onTap != null) base.clickable { onTap() } else base) {
        val b = bmp
        if (b != null) Image(b.asImageBitmap(), item.name, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        else Icon(if (item.isVideo) Icons.Outlined.Videocam else Icons.Outlined.Image, null, Modifier.align(Alignment.Center).size(28.dp), tint = Handy.palette.textSecondary)
        if (onTap != null) {
            Box(Modifier.padding(6.dp).size(22.dp).clip(CircleShape).background(if (selected) HandyColors.Accent else Color(0x66000000)).align(Alignment.TopStart), contentAlignment = Alignment.Center) {
                if (selected) Icon(Icons.Outlined.Check, null, Modifier.size(14.dp), tint = Color.White)
            }
        }
        if (grouped && item.group >= 0) Badge("G${item.group + 1}", Modifier.align(Alignment.TopEnd))
        item.why?.let { Badge(it, Modifier.align(Alignment.BottomStart)) }
        Badge(CleanupEngine.human(item.size), Modifier.align(Alignment.BottomEnd))
    }
}

@Composable
private fun Badge(text: String, modifier: Modifier) {
    Text(text, fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
        modifier = modifier.padding(4.dp).clip(RoundedCornerShape(6.dp)).background(Color(0x99000000)).padding(horizontal = 5.dp, vertical = 2.dp))
}

/** Amber ask-card in the PermissionCard style, but for a runtime permission prompt. */
@Composable
private fun AskCard(title: String, why: String, privacy: String, onAsk: () -> Unit) {
    Card(Modifier.fillMaxWidth().padding(bottom = HandyTokens.Space12), shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = Handy.palette.warningSoft), elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)) {
        Row(Modifier.padding(HandyTokens.Space16)) {
            Icon(Icons.Outlined.Shield, null, Modifier.size(24.dp), tint = HandyColors.Amber)
            Spacer(Modifier.width(HandyTokens.Space12))
            Column {
                Text(title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp))
                Spacer(Modifier.height(HandyTokens.Space4))
                Text(why, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp))
                Spacer(Modifier.height(HandyTokens.Space4))
                Text(privacy, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Spacer(Modifier.height(HandyTokens.Space12))
                HCompactButton("Allow") { onAsk() }
            }
        }
    }
}

// ------------------------------------------------------------------------------------------ Contacts

@Composable
private fun ContactsTab(
    granted: Boolean, denied: Boolean, settingsIntent: Intent, onAsk: () -> Unit,
    report: ContactsReport?, sources: Map<String, List<String>>, busy: Boolean, note: String?, dismissed: Set<String>,
    onMerge: (List<ContactRec>) -> Unit, onKeep: (List<ContactRec>) -> Unit, onRemoveEmpty: () -> Unit, onRescan: () -> Unit,
) {
    if (!granted) {
        if (denied) PermissionCard("Contacts", "Tenzy needs your contacts to find duplicates and merge them.", false, settingsIntent, "Open settings", "Read and merged on this phone only.")
        else AskCard("Contacts", "Tenzy needs your contacts to find duplicates and merge them.", "Read and merged on this phone only.", onAsk)
        return
    }
    Spacer(Modifier.height(8.dp))
    if (report == null) {
        if (busy) { LinearProgressIndicator(modifier = Modifier.fillMaxWidth()); Text("Reading contacts…", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 8.dp)) }
        else HPrimaryButton("Scan my contacts") { onRescan() }
        note?.let { NoteText(it) }
        return
    }
    val groups = report.duplicateGroups.filter { g -> g.map { it.contactId }.sorted().joinToString(",") !in dismissed }
    val noName = report.incomplete.count { !it.hasName && it.hasNumber }
    val noNumber = report.incomplete.count { it.hasName && !it.hasNumber }
    val empties = report.incomplete.count { !it.hasName && !it.hasNumber }
    SectionLabel("${groups.size} likely duplicate${if (groups.size == 1) "" else "s"} · $noName with no name · $noNumber with no number")
    note?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Success, modifier = Modifier.padding(bottom = 6.dp)) }
    if (groups.isEmpty() && empties == 0) EmptyState(Icons.Outlined.Contacts, "Contacts are tidy. ✓", "${report.total} contacts, no duplicates found.")
    groups.forEach { g ->
        val key = g.map { it.contactId }.sorted().joinToString(",")
        HCard(Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
            Column(Modifier.padding(14.dp)) {
                Text(g.map { it.name.ifBlank { "(no name)" } }.distinct().joinToString(" + "), style = MaterialTheme.typography.titleMedium)
                val details = (g.flatMap { it.numbers } + g.flatMap { it.emails }).distinct()
                Text(if (details.isEmpty()) "No number or email" else details.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                val src = sources[key] ?: emptyList()
                Text("${g.size} entries" + (if (src.isNotEmpty()) " · from ${src.joinToString(", ")}" else ""), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HChip(if (busy) "Working…" else "Merge into one", false) { if (!busy) onMerge(g) }
                    HChip("Keep both", false) { onKeep(g) }
                }
            }
        }
    }
    if (empties > 0) {
        Spacer(Modifier.height(4.dp))
        HSecondaryButton("Also: remove $empties empty contact${if (empties == 1) "" else "s"}", enabled = !busy) { onRemoveEmpty() }
    }
    Spacer(Modifier.height(8.dp))
    HSecondaryButton(if (busy) "Working…" else "Rescan", enabled = !busy) { onRescan() }
    NoteText("Merging links the entries into one contact and keeps every number and email — nothing is lost.")
}

// ------------------------------------------------------------------------------------------ Trash

@Composable
private fun TrashTab(items: List<CleanItem>, modern: Boolean, status: String?, onRestore: () -> Unit, onPurge: () -> Unit) {
    Spacer(Modifier.height(8.dp))
    if (items.isEmpty()) {
        EmptyState(Icons.Outlined.Delete, "Trash is empty.", "Anything you move here can be restored.")
        status?.let { NoteText(it) }
        return
    }
    SectionLabel("${items.size} items · ${CleanupEngine.human(items.sumOf { it.size })} · " + if (modern) "auto-deleted after 30 days" else "kept until you delete forever")
    ThumbGridReadOnly(items.take(GRID_CAP))
    status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Success, modifier = Modifier.padding(top = 8.dp)) }
    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        HSecondaryButton("Restore all", Modifier.weight(1f)) { onRestore() }
        HPrimaryButton("Delete forever", Modifier.weight(1f)) { onPurge() }
    }
    NoteText(if (modern) "This is the phone's own Trash — Android confirms each step with you and keeps items 30 days." else "Files sit in Pictures/Tenzy/.trash until you restore or delete them.")
}

@Composable
private fun ThumbGridReadOnly(items: List<CleanItem>) {
    items.chunked(3).forEach { row ->
        Row(Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            row.forEach { item -> Thumb(item, false, false, Modifier.weight(1f), null) }
            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}
