package com.handytools.app.tools.storage

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun StorageScreen(onOpen: (String) -> Unit = {}) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val perms = if (Build.VERSION.SDK_INT >= 33)
        arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
    else arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)

    fun hasPerm() = perms.all { ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED }

    var granted by remember { mutableStateOf(hasPerm()) }
    var scanning by remember { mutableStateOf(false) }
    var report by remember { mutableStateOf<StorageReport?>(null) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        granted = hasPerm()
    }

    fun scan() {
        scanning = true
        scope.launch {
            val r = runCatching { withContext(Dispatchers.IO) { StorageEngine.scan(ctx) } }.getOrNull()
            report = r; scanning = false
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Storage Map", "See exactly what's filling your phone — photos, videos, and your biggest folders and files.")
        Spacer(Modifier.size(16.dp))

        val r = report
        when {
            !granted -> {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Tenzy reads your photos and videos on this device to show what's using space. Nothing is uploaded.",
                            color = Handy.palette.textSecondary)
                        Spacer(Modifier.size(12.dp))
                        HPrimaryButton("Allow access", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(perms) }
                    }
                }
                Spacer(Modifier.weight(1f)); BannerAd()
            }
            r == null -> {
                HPrimaryButton(if (scanning) "Measuring…" else "Scan my storage", modifier = Modifier.fillMaxWidth()) { if (!scanning) scan() }
                Spacer(Modifier.weight(1f)); BannerAd()
            }
            else -> {
                Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                    // Device usage bar
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text("${StorageEngine.human(r.usedBytes)} used", style = MaterialTheme.typography.headlineSmall)
                            Text("of ${StorageEngine.human(r.totalBytes)} · ${StorageEngine.human(r.freeBytes)} free",
                                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
                            Spacer(Modifier.size(10.dp))
                            val frac = if (r.totalBytes > 0) (r.usedBytes.toFloat() / r.totalBytes).coerceIn(0f, 1f) else 0f
                            Box(
                                Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(5.dp))
                                    .background(Handy.palette.border)
                            ) {
                                Box(Modifier.fillMaxWidth(frac).height(10.dp).clip(RoundedCornerShape(5.dp)).background(Handy.palette.accentSoft))
                            }
                        }
                    }
                    Spacer(Modifier.size(12.dp))

                    Row(Modifier.fillMaxWidth()) {
                        StatCell("Photos", r.photoCount, r.photoBytes, Modifier.weight(1f))
                        Spacer(Modifier.size(12.dp))
                        StatCell("Videos", r.videoCount, r.videoBytes, Modifier.weight(1f))
                    }
                    Spacer(Modifier.size(16.dp))

                    if (r.folders.isNotEmpty()) {
                        Text("Biggest folders", style = MaterialTheme.typography.titleSmall)
                        Spacer(Modifier.size(8.dp))
                        r.folders.forEach { f ->
                            RowLine(f.name.ifBlank { "Other" }, "${f.count} · ${StorageEngine.human(f.bytes)}")
                        }
                        Spacer(Modifier.size(16.dp))
                    }

                    if (r.largest.isNotEmpty()) {
                        Text("Largest files", style = MaterialTheme.typography.titleSmall)
                        Spacer(Modifier.size(8.dp))
                        r.largest.forEach { item ->
                            RowLine(item.name, StorageEngine.human(item.bytes))
                        }
                        Spacer(Modifier.size(16.dp))
                    }
                }

                HPrimaryButton("Free up photo space", modifier = Modifier.fillMaxWidth()) { onOpen("spaceclean") }
                Spacer(Modifier.size(8.dp))
                HSecondaryButton(if (scanning) "Measuring…" else "Rescan", modifier = Modifier.fillMaxWidth()) { if (!scanning) scan() }
                BannerAd()
            }
        }
    }
}

@Composable
private fun StatCell(label: String, count: Int, bytes: Long, modifier: Modifier = Modifier) {
    HCard(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(StorageEngine.human(bytes), style = MaterialTheme.typography.titleLarge)
            Text("$label · $count", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun RowLine(name: String, right: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(name, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f), maxLines = 1)
        Spacer(Modifier.size(10.dp))
        Text(right, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
    }
}
