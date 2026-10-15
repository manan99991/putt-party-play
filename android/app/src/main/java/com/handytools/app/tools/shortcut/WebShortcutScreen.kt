package com.handytools.app.tools.shortcut

import com.handytools.app.ui.HandyHaptics

import androidx.compose.ui.draw.clip

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
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.SliderRow
import com.handytools.app.ui.LimitNote
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens
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
        HPrimaryButton("Fetch", enabled = url.isNotBlank() && !loading) { load(url) }
        HTextButton("Paste from clipboard") {
            val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val t = cm.primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString()?.trim() ?: ""
            Regex("https?://\\S+|[\\w.-]+\\.[a-z]{2,}\\S*").find(t)?.value?.let { url = it; load(it) }
        }
        Spacer(Modifier.height(20.dp))
        if (loading) CircularProgressIndicator()
        preview?.let { p ->
            // Hero: the result rendered as a real home-screen icon mock — the fetched favicon in a
            // 60dp rounded square on a blurred-wallpaper tile, with the name under it in launcher label style.
            HomeIconMock(p, name.ifBlank { p.title })
            Spacer(Modifier.height(12.dp))
            HCard(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    p.icon?.let { Image(it.asImageBitmap(), null, Modifier.size(48.dp)) }
                    Spacer(Modifier.width(12.dp))
                    OutlinedTextField(name, { name = it.take(30) }, label = { Text("Shortcut name") }, singleLine = true, modifier = Modifier.weight(1f))
                }
            }
            Spacer(Modifier.height(12.dp))
            HPrimaryButton("Add to home screen") {
                val ok = WebShortcut.pin(ctx, p.copy(title = name.ifBlank { p.title }))
                done = ok
                if (ok) {
                    com.handytools.app.ui.HandyHaptics.success(ctx)
                    Interstitials.showIfReady(ctx as Activity)
                }
            }
            if (done) Text("Added to your home screen.", style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(16.dp))
        LimitNote("Tip: share any link to HandyTools from your browser and it lands here.")
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

/**
 * Hero: home-screen icon mock. The fetched favicon sits in a 60dp rounded square on a
 * wallpaper-style tile, with the shortcut name under it in launcher label style.
 * (The tile uses a soft vertical gradient as the wallpaper; a true RenderEffect blur needs
 * API 31+, so the gradient stands in on older devices.)
 */
@Composable
private fun HomeIconMock(p: PagePreview, label: String) {
    androidx.compose.foundation.layout.Column(
        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth()
    ) {
        androidx.compose.foundation.layout.Box(
            Modifier.size(140.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(28.dp))
                .background(
                    androidx.compose.ui.graphics.Brush.verticalGradient(
                        listOf(
                            androidx.compose.ui.graphics.Color(0xFF2B68FF),
                            androidx.compose.ui.graphics.Color(0xFF1F5EFF),
                            androidx.compose.ui.graphics.Color(0xFF1649D6)
                        )
                    )
                ),
            contentAlignment = androidx.compose.ui.Alignment.Center
        ) {
            androidx.compose.foundation.layout.Box(
                Modifier.size(60.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                    .background(androidx.compose.ui.graphics.Color.White),
                contentAlignment = androidx.compose.ui.Alignment.Center
            ) {
                val icon = p.icon
                if (icon != null) Image(icon.asImageBitmap(), null, Modifier.size(44.dp))
                else Text(
                    label.take(1).uppercase(), style = MaterialTheme.typography.titleMedium,
                    color = com.handytools.app.ui.HandyColors.Accent
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface)
    }
}
