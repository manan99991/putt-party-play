package com.handytools.app.tools.zip

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.tools.pdf.PdfCore
import com.handytools.app.tools.pdf.ResultCard
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Make a Zip: many files into one, to send as a single attachment. Names that clash get " (2)". */
object Zipper {
    /** Unique names inside the zip, keeping each extension. Pure. */
    fun uniqueNames(names: List<String>): List<String> {
        val seen = mutableMapOf<String, Int>()
        return names.map { n ->
            val clean = n.replace("/", "-").ifBlank { "file" }
            val count = (seen[clean.lowercase()] ?: 0) + 1
            seen[clean.lowercase()] = count
            if (count == 1) clean else clean.substringBeforeLast('.', clean) + " ($count)" + (if ('.' in clean) "." + clean.substringAfterLast('.') else "")
        }
    }

    fun name(ctx: Context, uri: Uri): String = runCatching {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }.getOrNull() ?: "file"

    fun zip(ctx: Context, uris: List<Uri>, out: File): Boolean = runCatching {
        val names = uniqueNames(uris.map { name(ctx, it) })
        ZipOutputStream(out.outputStream().buffered()).use { z ->
            uris.forEachIndexed { i, u ->
                z.putNextEntry(ZipEntry(names[i]))
                ctx.contentResolver.openInputStream(u)!!.use { it.copyTo(z) }
                z.closeEntry()
            }
        }
        true
    }.getOrDefault(false)
}

@Composable
fun ZipScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var files by remember { mutableStateOf(listOf<Uri>()) }
    var result by remember { mutableStateOf<File?>(null) }
    var working by remember { mutableStateOf(false) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { if (it.isNotEmpty()) files = (files + it).distinct() }

    PowerToolPage("zipmaker") {
        val r = result
        if (r != null) {
            ResultCard(r, "application/zip", null, "${files.size} " + I18n.t("files") + " · " + "%.1f MB".format(r.length() / 1_048_576.0)) { result = null; files = emptyList() }
            return@PowerToolPage
        }
        Text(I18n.t("Pick the files to put together — photos, PDFs, anything. They go into one zip you can send as a single attachment."),
            color = Handy.palette.textSecondary)
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (files.isEmpty()) "Choose files" else "Add more files", modifier = Modifier.testTag("zip-pick")) { pick.launch(arrayOf("*/*")) }
        Spacer(Modifier.size(8.dp))
        Zipper.uniqueNames(files.map { Zipper.name(ctx, it) }).forEach { Text("• $it", fontSize = 14.sp, color = MaterialTheme.colorScheme.onBackground) }
        if (files.isNotEmpty()) {
            Spacer(Modifier.size(12.dp))
            HPrimaryButton(if (working) "Working…" else "Make the zip", enabled = !working, modifier = Modifier.testTag("zip-make")) {
                working = true
                scope.launch {
                    val out = PdfCore.out(ctx, "Files.zip")
                    if (withContext(Dispatchers.IO) { Zipper.zip(ctx, files, out) }) result = out
                    working = false
                }
            }
            Spacer(Modifier.size(8.dp))
            HSecondaryButton("Clear") { files = emptyList() }
        }
    }
}
