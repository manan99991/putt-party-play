package com.handytools.app.tools.memory

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.launch

/** Memory — ask your own screenshots anything. Reads them once on-device, then finds by plain words. */
@Composable
fun MemoryScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
    var authorized by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, perm) == PackageManager.PERMISSION_GRANTED) }
    var entries by remember { mutableStateOf(MemoryEngine.loadCache(ctx)) }
    var indexing by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf(0f) }
    var query by remember { mutableStateOf(TextFieldValue("")) }
    var results by remember { mutableStateOf<List<MemEntry>>(emptyList()) }
    var searched by remember { mutableStateOf(false) }
    var viewing by remember { mutableStateOf<MemEntry?>(null) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> authorized = granted }

    fun reindex() {
        if (indexing) return
        indexing = true; progress = 0f
        scope.launch {
            entries = MemoryEngine.index(ctx) { progress = it }
            indexing = false
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Memory", "Ask your own screenshots — the Wi-Fi password, a confirmation number, where you parked. Read on your phone, never uploaded.")
        Spacer(Modifier.size(16.dp))

        if (!authorized) {
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Memory reads your screenshots", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.size(6.dp))
                    Text("It needs access to your photos to find things in them. Nothing is uploaded — it stays on your phone.",
                        style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                }
            }
            Spacer(Modifier.size(8.dp))
            HPrimaryButton("Allow photo access", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(perm) }
            Spacer(Modifier.weight(1f))
        } else {
            HCard(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f)) {
                        BasicTextField(value = query, onValueChange = { query = it }, modifier = Modifier.fillMaxWidth(),
                            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                            decorationBox = { inner ->
                                if (query.text.isBlank()) Text("Ask your screenshots…", color = Handy.palette.textSecondary)
                                inner()
                            })
                    }
                    HSecondaryButton("Ask") { searched = true; results = MemoryEngine.search(query.text, entries) }
                }
            }

            if (indexing) {
                Spacer(Modifier.size(12.dp))
                Text("Reading your screenshots… ${(progress * 100).toInt()}%", color = Handy.palette.textSecondary)
            } else if (entries.isEmpty()) {
                Spacer(Modifier.size(12.dp))
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Read your screenshots once so you can search them. It happens on your phone and is cached — only slow the first time.",
                            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                        Spacer(Modifier.size(10.dp))
                        HPrimaryButton("Index my screenshots", modifier = Modifier.fillMaxWidth()) { reindex() }
                    }
                }
            }

            Spacer(Modifier.size(12.dp))
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                if (searched && results.isEmpty() && !indexing)
                    Text("Nothing matched that. Try the words that were on the screenshot, or re-index if it's recent.",
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                results.forEach { e ->
                    HCard(Modifier.fillMaxWidth().clickable { viewing = e }) {
                        Column(Modifier.padding(14.dp)) {
                            Text(MemoryEngine.bestLine(query.text, e), style = MaterialTheme.typography.bodyLarge)
                            Spacer(Modifier.size(6.dp))
                            Text("Tap to open the screenshot", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                            Spacer(Modifier.size(6.dp))
                            HSecondaryButton("Share") { Share.text(ctx, MemoryEngine.bestLine(query.text, e)) }
                        }
                    }
                    Spacer(Modifier.size(8.dp))
                }
                if (entries.isNotEmpty()) {
                    Text("${entries.size} screenshots read", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    HSecondaryButton("Re-index") { reindex() }
                }
            }
        }
        Text("A one-line AI answer needs on-device Gemini Nano (Pixel 9, Galaxy S24+ and newer). Otherwise you get the best-matching screenshot.",
            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 8.dp))
        BannerAd()
    }

    viewing?.let { e ->
        Dialog(onDismissRequest = { viewing = null }) {
            val bmp = remember(e.id) { loadScreenshot(ctx, e.id) }
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
                    if (bmp != null) {
                        Image(bitmap = bmp.asImageBitmap(), contentDescription = "Screenshot", modifier = Modifier.fillMaxWidth())
                    } else {
                        Text("This screenshot isn't on your phone anymore. The text read from it is below.",
                            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                    }
                    Spacer(Modifier.size(12.dp))
                    if (e.text.isNotBlank()) {
                        Text("Text read from this screenshot", style = MaterialTheme.typography.titleSmall)
                        Spacer(Modifier.size(4.dp))
                        Text(e.text, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.size(12.dp))
                    }
                    Row {
                        if (e.text.isNotBlank()) {
                            HSecondaryButton("Share text") { Share.text(ctx, e.text) }
                            Spacer(Modifier.size(8.dp))
                        }
                        HPrimaryButton("Done") { viewing = null }
                    }
                }
            }
        }
    }
}

/** Load the full screenshot bitmap from MediaStore by id, or null if it's no longer there. */
private fun loadScreenshot(ctx: Context, id: Long): Bitmap? = runCatching {
    val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
    ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
}.getOrNull()
