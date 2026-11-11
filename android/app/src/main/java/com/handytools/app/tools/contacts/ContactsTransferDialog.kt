package com.handytools.app.tools.contacts

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** Three taps: where they are now, where they should go, copy or move. Copy is the default. */
@Composable
fun ContactsTransferDialog(onDismiss: () -> Unit, onChanged: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var accounts by remember { mutableStateOf<List<ContactAccount>>(emptyList()) }
    var from by remember { mutableStateOf<String?>(null) }
    var to by remember { mutableStateOf<String?>(null) }
    var move by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var outcome by remember { mutableStateOf<ContactsTransfer.Outcome?>(null) }
    var backup by remember { mutableStateOf<File?>(null) }
    var confirm by remember { mutableStateOf(false) }

    fun reload() { scope.launch { accounts = withContext(Dispatchers.IO) { ContactsTransfer.accounts(ctx) } } }
    LaunchedEffect(Unit) { reload() }

    val fromAcc = accounts.firstOrNull { it.key == from }
    val toAcc = accounts.firstOrNull { it.key == to }
    val ready = fromAcc != null && toAcc != null && fromAcc.key != toAcc.key && !busy

    fun run() {
        val f = fromAcc ?: return; val t = toAcc ?: return
        busy = true; outcome = null; progress = 0f; backup = null
        scope.launch {
            val (b, o) = withContext(Dispatchers.IO) {
                // A move saves a backup file of the source first, so nothing is ever only in the removed copy.
                val bk = if (move) ContactsTransfer.backup(ctx, f) else null
                bk to ContactsTransfer.transfer(ctx, f, t, move) { progress = it }
            }
            backup = b; outcome = o; busy = false; onChanged(); reload()
        }
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Move contacts", style = MaterialTheme.typography.titleLarge)
                    TextButton(onClick = onDismiss) { Text("Close") }
                }
                Text("Pick where your contacts are now and where they should go. Nothing leaves this phone.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)

                SectionLabel("1. Take contacts from")
                accounts.forEach { a -> AccountRow(a, from == a.key) { from = a.key; if (to == a.key) to = null } }

                SectionLabel("2. Put them into")
                accounts.filter { it.key != from && it.writable }.forEach { a -> AccountRow(a, to == a.key) { to = a.key } }
                Text("Don't see your Google account? Add it in Settings › Passwords & accounts › Add account › Google, and keep Contacts sync on.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))

                SectionLabel("3. How")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HChip("Copy (keep originals)", !move) { move = false }
                    HChip("Move (remove from old)", move) { move = true }
                }
                if (move) Text("Move removes the originals from the first account once the copies are saved. If that account is Google, they're removed from your Google contacts too. A backup file is made first.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))

                Spacer(Modifier.height(16.dp))
                val n = fromAcc?.count ?: 0
                HPrimaryButton(
                    if (fromAcc == null || toAcc == null) "Pick two accounts"
                    else "${if (move) "Move" else "Copy"} $n contact${if (n == 1) "" else "s"} to ${toAcc.name ?: toAcc.kind}",
                    enabled = ready
                ) { if (move) confirm = true else run() }
                if (busy) { Spacer(Modifier.height(8.dp)); LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth()) }

                outcome?.let { o ->
                    Spacer(Modifier.height(12.dp))
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(14.dp)) {
                            Text("${o.copied} added", style = MaterialTheme.typography.titleMedium)
                            if (o.alreadyThere > 0) NoteText("${o.alreadyThere} already there, so skipped")
                            if (o.failed > 0) NoteText("${o.failed} couldn't be added. They were left where they are.")
                            if (o.removed > 0) NoteText("${o.removed} removed from the old account")
                            backup?.let { f -> TextButton(onClick = { Share.file(ctx, f, "text/x-vcard") }) { Text("Save the backup file") } }
                        }
                    }
                }
            }
        }
    }

    if (confirm) AlertDialog(
        onDismissRequest = { confirm = false },
        title = { Text("Move ${fromAcc?.count ?: 0} contacts?") },
        text = { Text("They're copied into ${toAcc?.title ?: "the new account"} first, then removed from ${fromAcc?.title ?: "the old one"}. Contacts have no Trash, so removing can't be undone. A backup file is saved first.") },
        confirmButton = { TextButton(onClick = { confirm = false; run() }) { Text("Move") } },
        dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } }
    )
}

@Composable
private fun AccountRow(a: ContactAccount, selected: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        RadioButton(selected = selected, onClick = onClick)
        Column(Modifier.padding(start = 4.dp)) {
            Text(a.name?.takeIf { it.isNotBlank() } ?: a.kind, style = MaterialTheme.typography.titleSmall)
            Text("${a.count} contacts · ${a.kind}", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
    }
}
