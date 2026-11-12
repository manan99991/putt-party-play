package com.handytools.app.tools.builder

import android.content.Context
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.ToolHeader
import java.io.File

/** The sheets tools add to ("Expenses 2026-11"). Kept in the app's own files, on this phone. */
object SheetStore {
    class Sheet(val file: File, val rows: Int) {
        val name: String get() = file.nameWithoutExtension
        val daysAgo: Int get() = ((System.currentTimeMillis() - file.lastModified()) / 86_400_000L).toInt()
    }

    private fun dir(ctx: Context) = File(ctx.filesDir, "lists").also { it.mkdirs() }

    /** Every sheet, most recently changed first. */
    fun all(ctx: Context): List<Sheet> = (dir(ctx).listFiles() ?: emptyArray())
        .filter { it.isFile && it.extension.equals("csv", ignoreCase = true) }
        .sortedByDescending { it.lastModified() }
        .map { Sheet(it, TextTidy.sheetRows(runCatching { it.readText() }.getOrDefault(""))) }

    /** False if the name is empty, unchanged or already taken. */
    fun rename(ctx: Context, sheet: Sheet, newName: String): Boolean {
        if (newName.isBlank()) return false
        val target = File(dir(ctx), TextTidy.fileName(newName, "List", ext = "csv"))
        if (target.exists() || target.name == sheet.file.name) return false
        return runCatching { sheet.file.renameTo(target) }.getOrDefault(false)
    }

    fun removeLastRow(sheet: Sheet): Boolean {
        val next = TextTidy.withoutLastRow(runCatching { sheet.file.readText() }.getOrDefault("")) ?: return false
        return runCatching { sheet.file.writeText(next) }.isSuccess
    }

    fun delete(sheet: Sheet) { runCatching { sheet.file.delete() } }
}

@Composable
fun SheetsScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    var sheets by remember { mutableStateOf(SheetStore.all(ctx)) }
    var open by remember { mutableStateOf<String?>(null) }
    var renaming by remember { mutableStateOf<String?>(null) }
    var newName by remember { mutableStateOf("") }
    var deleting by remember { mutableStateOf<String?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    fun reload() { sheets = SheetStore.all(ctx) }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(HandyTokens.Gutter), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        ToolHeader("My sheets", "Each sheet opens in Excel or Google Sheets. They stay on this phone until you send one.")
        note?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary) }
        if (sheets.isEmpty()) Text("No sheets yet. Run \"Receipt into this month's expense sheet\" and it appears here.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
        sheets.forEach { s ->
            val key = s.file.name
            HCard(Modifier.fillMaxWidth(), onClick = { open = if (open == key) null else key }) {
                Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    Text(s.name, style = MaterialTheme.typography.titleSmall)
                    Text(TextTidy.sheetSummary(s.rows, s.daysAgo), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    if (open == key) {
                        val lines = remember(key, sheets) { runCatching { s.file.readLines() }.getOrDefault(emptyList()).filter { it.isNotBlank() } }
                        val shown = if (lines.size > 31) listOf(lines[0]) + lines.takeLast(30) else lines
                        if (lines.size > 31) Text("Showing the last 30 of ${lines.size - 1} entries.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        Column(Modifier.horizontalScroll(rememberScrollState())) {
                            shown.forEachIndexed { i, line ->
                                Text(line.replace(",", "   "), style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace,
                                    fontWeight = if (i == 0) FontWeight.SemiBold else FontWeight.Normal, maxLines = 1, softWrap = false)
                            }
                        }
                    }
                    if (renaming == key) {
                        OutlinedTextField(newName, { newName = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("New name") })
                        Text("Tools that add to this sheet by its old name will start a new one.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        Row {
                            TextButton({
                                note = if (SheetStore.rename(ctx, s, newName)) "Renamed." else "That name is empty or already used. The sheet kept its name."
                                renaming = null; reload()
                            }) { Text("Save name") }
                            TextButton({ renaming = null }) { Text("Cancel") }
                        }
                    } else if (deleting == key) {
                        Text("Delete this sheet? Its entries are removed from this phone. This can't be undone.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                        Row {
                            TextButton({ SheetStore.delete(s); note = "Deleted ${s.name}."; deleting = null; reload() }) { Text("Delete ${s.name}", color = MaterialTheme.colorScheme.error) }
                            TextButton({ deleting = null }) { Text("Keep it") }
                        }
                    } else Row(Modifier.horizontalScroll(rememberScrollState())) {
                        TextButton({ Share.file(ctx, s.file, "text/csv") }) { Text("Send") }
                        TextButton({ newName = s.name; renaming = key }) { Text("Rename") }
                        if (s.rows > 0) TextButton({ if (SheetStore.removeLastRow(s)) { note = "Removed the last entry from ${s.name}."; reload() } }) { Text("Undo last") }
                        TextButton({ deleting = key }) { Text("Delete") }
                    }
                }
            }
        }
        HSecondaryButton("Back") { onBack() }
    }
}
