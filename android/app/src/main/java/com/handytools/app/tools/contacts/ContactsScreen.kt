package com.handytools.app.tools.contacts

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ContactsScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    fun hasPerms() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    var granted by remember { mutableStateOf(hasPerms()) }
    var scanning by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var report by remember { mutableStateOf<ContactsReport?>(null) }
    var note by remember { mutableStateOf("") }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        granted = hasPerms()
    }

    fun scan() {
        scanning = true; note = ""
        scope.launch {
            val r = runCatching { withContext(Dispatchers.IO) { ContactsEngine.scan(ctx) } }.getOrNull()
            report = r; scanning = false
            if (r == null) note = "Couldn't read contacts."
        }
    }

    fun mergeGroup(group: List<ContactRec>) {
        busy = true
        scope.launch {
            runCatching { withContext(Dispatchers.IO) { ContactsEngine.merge(ctx, group) } }
            val r = runCatching { withContext(Dispatchers.IO) { ContactsEngine.scan(ctx) } }.getOrNull()
            report = r; busy = false; note = "Merged."
        }
    }

    fun exportBackup() {
        busy = true
        scope.launch {
            val f = runCatching { withContext(Dispatchers.IO) { ContactsEngine.exportVcf(ctx) } }.getOrNull()
            busy = false
            if (f != null) Share.file(ctx, f, "text/x-vcard") else note = "Export failed."
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Contacts Cleanup", "Find and merge duplicates, spot half-empty entries, and back up your contacts — nothing leaves your phone.")
        Spacer(Modifier.size(16.dp))

        val r = report
        when {
            !granted -> {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Tenzy needs access to your contacts to find duplicates and back them up. It only reads them on this device.",
                            color = Handy.palette.textSecondary)
                        Spacer(Modifier.size(12.dp))
                        HPrimaryButton("Allow contacts access", modifier = Modifier.fillMaxWidth()) {
                            permLauncher.launch(arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS))
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                BannerAd()
            }
            r == null -> {
                HPrimaryButton(if (scanning) "Scanning…" else "Scan my contacts", modifier = Modifier.fillMaxWidth()) {
                    if (!scanning) scan()
                }
                if (note.isNotEmpty()) { Spacer(Modifier.size(12.dp)); Text(note, color = Handy.palette.textSecondary) }
                Spacer(Modifier.weight(1f))
                BannerAd()
            }
            else -> {
                Row(Modifier.fillMaxWidth()) {
                    HSecondaryButton(if (scanning) "Scanning…" else "Rescan", modifier = Modifier.fillMaxWidth()) { if (!scanning) scan() }
                }
                Spacer(Modifier.size(12.dp))
                Text("${r.total} contacts · ${r.duplicateCount} duplicate${if (r.duplicateCount == 1) "" else "s"} · ${r.incomplete.size} incomplete",
                    style = MaterialTheme.typography.bodyLarge)
                if (note.isNotEmpty()) { Spacer(Modifier.size(6.dp)); Text(note, color = Handy.palette.textSecondary) }
                Spacer(Modifier.size(12.dp))

                Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                    if (r.duplicateGroups.isEmpty()) {
                        HCard(Modifier.fillMaxWidth()) {
                            Column(Modifier.padding(16.dp)) { Text("No duplicates found. Your contacts are tidy.") }
                        }
                    }
                    r.duplicateGroups.forEach { group ->
                        HCard(Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
                            Column(Modifier.padding(16.dp)) {
                                val title = group.firstOrNull { it.hasName }?.name ?: group.firstOrNull()?.numbers?.firstOrNull() ?: "Contact"
                                Text(title, style = MaterialTheme.typography.titleMedium)
                                Spacer(Modifier.size(4.dp))
                                Text("${group.size} copies · ${group.flatMap { it.numbers }.distinct().size} numbers combined",
                                    color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
                                Spacer(Modifier.size(10.dp))
                                HPrimaryButton(if (busy) "Working…" else "Merge these", modifier = Modifier.fillMaxWidth()) {
                                    if (!busy) mergeGroup(group)
                                }
                            }
                        }
                    }
                    if (r.incomplete.isNotEmpty()) {
                        Spacer(Modifier.size(4.dp))
                        Text("Incomplete entries", style = MaterialTheme.typography.titleSmall)
                        Spacer(Modifier.size(8.dp))
                        r.incomplete.take(50).forEach { rec ->
                            HCard(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                                Column(Modifier.padding(14.dp)) {
                                    Text(if (rec.hasName) rec.name else (rec.numbers.firstOrNull() ?: "Unnamed contact"),
                                        style = MaterialTheme.typography.bodyLarge)
                                    Text(rec.whyIncomplete(), color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
                                }
                            }
                        }
                    }
                }

                Spacer(Modifier.size(8.dp))
                HSecondaryButton(if (busy) "Working…" else "Back up all contacts (.vcf)", modifier = Modifier.fillMaxWidth()) {
                    if (!busy) exportBackup()
                }
                BannerAd()
            }
        }
    }
}
