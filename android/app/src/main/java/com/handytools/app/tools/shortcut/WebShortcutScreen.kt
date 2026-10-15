package com.handytools.app.tools.shortcut

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ads.Interstitials
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.launch

@Composable
fun WebShortcutScreen(initialUrl: String? = null) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var url by remember { mutableStateOf(initialUrl ?: "") }
    var name by remember { mutableStateOf("") }
    var preview by remember { mutableStateOf<PagePreview?>(null) }
    var loading by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }

    fun load(u: String) {
        if (u.isBlank()) return
        loading = true; done = false
        scope.launch {
            preview = WebShortcut.preview(u.trim())
            name = preview?.title ?: ""
            loading = false
        }
    }

    LaunchedEffect(initialUrl) { if (initialUrl != null) load(initialUrl) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Web → Home", "Paste a link. We pick a name and icon. Tap Add. Done.")
        OutlinedTextField(url, { url = it }, label = { Text("URL") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        Row {
            OutlinedButton(onClick = {
                val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val t = cm.primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString()?.trim() ?: ""
                Regex("https?://\\S+|[\\w.-]+\\.[a-z]{2,}\\S*").find(t)?.value?.let { url = it; load(it) }
            }) { Text("Paste from clipboard") }
            Spacer(Modifier.width(8.dp))
            Button(onClick = { load(url) }, enabled = url.isNotBlank() && !loading) { Text("Fetch") }
        }
        Spacer(Modifier.height(20.dp))
        if (loading) CircularProgressIndicator()
        preview?.let { p ->
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    p.icon?.let { Image(it.asImageBitmap(), null, Modifier.size(48.dp)) }
                    Spacer(Modifier.width(12.dp))
                    OutlinedTextField(name, { name = it.take(30) }, label = { Text("Shortcut name") }, singleLine = true, modifier = Modifier.weight(1f))
                }
            }
            Spacer(Modifier.height(12.dp))
            Button(onClick = {
                val ok = WebShortcut.pin(ctx, p.copy(title = name.ifBlank { p.title }))
                done = ok
                if (ok) Interstitials.showIfReady(ctx as Activity)
            }, modifier = Modifier.fillMaxWidth()) { Text("Add to home screen") }
            if (done) Text("Added to your home screen.", style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(16.dp))
        Text("Tip: share any link to HandyTools from your browser and it lands here.", style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
