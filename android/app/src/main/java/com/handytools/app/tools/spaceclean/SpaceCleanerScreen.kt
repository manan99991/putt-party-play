package com.handytools.app.tools.spaceclean

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
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
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun SpaceCleanerScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE

    fun hasPerm() = ContextCompat.checkSelfPermission(ctx, perm) == PackageManager.PERMISSION_GRANTED

    var granted by remember { mutableStateOf(hasPerm()) }
    var scanning by remember { mutableStateOf(false) }
    var report by remember { mutableStateOf<CleanReport?>(null) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    fun scan() {
        scanning = true
        scope.launch {
            val r = runCatching { withContext(Dispatchers.IO) { SpaceCleanerEngine.scan(ctx) } }.getOrNull()
            report = r; scanning = false
        }
    }

    val deleteLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) {
        scan() // rescan after the system delete dialog closes
    }

    fun clean(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val sender = SpaceCleanerEngine.trashRequest(ctx, uris)
        if (sender != null) deleteLauncher.launch(IntentSenderRequest.Builder(sender).build())
        else { SpaceCleanerEngine.deleteLegacy(ctx, uris); scan() }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Space Cleaner", "Find duplicate and look-alike photos, the screenshot pile, and big files. Everything goes to your Trash — recoverable for 30 days, never deleted outright. No paywall on cleanup.")
        Spacer(Modifier.size(16.dp))

        val r = report
        when {
            !granted -> {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Tenzy needs access to your photos to find what's taking up space. It scans on this device only.",
                            color = Handy.palette.textSecondary)
                        Spacer(Modifier.size(12.dp))
                        HPrimaryButton("Allow photo access", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(perm) }
                    }
                }
                Spacer(Modifier.weight(1f)); BannerAd()
            }
            r == null -> {
                HPrimaryButton(if (scanning) "Scanning your photos…" else "Scan for space to free up", modifier = Modifier.fillMaxWidth()) {
                    if (!scanning) scan()
                }
                Spacer(Modifier.weight(1f)); BannerAd()
            }
            else -> {
                Row(Modifier.fillMaxWidth()) {
                    HSecondaryButton(if (scanning) "Scanning…" else "Rescan", modifier = Modifier.fillMaxWidth()) { if (!scanning) scan() }
                }
                Spacer(Modifier.size(12.dp))
                Text("Up to ${SpaceCleanerEngine.humanSize(r.reclaimable)} to free up", style = MaterialTheme.typography.headlineSmall)
                Text("of ${SpaceCleanerEngine.humanSize(r.totalBytes)} in photos", color = Handy.palette.textSecondary)
                Spacer(Modifier.size(12.dp))

                Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                    Category("Exact duplicates", r.exactDupes.sumOf { it.reclaim }, r.exactDupes.sumOf { it.items.size - 1 }) {
                        clean(r.exactDupes.flatMap { it.items.drop(1) }.map { it.uri })
                    }
                    Category("Look-alike photos", r.similar.sumOf { it.reclaim }, r.similar.sumOf { it.items.size - 1 }) {
                        clean(r.similar.flatMap { it.items.drop(1) }.map { it.uri })
                    }
                    r.screenshots?.let { s ->
                        Category("Screenshots", s.reclaim, s.items.size) { clean(s.items.map { it.uri }) }
                    }
                    r.largeFiles?.let { l ->
                        Category("Large images", l.reclaim, l.items.size) { clean(l.items.map { it.uri }) }
                    }
                    if (r.reclaimable == 0L) {
                        HCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text("Nothing to clean — your photos are tidy.") } }
                    }
                }
                BannerAd()
            }
        }
    }
}

@Composable
private fun Category(title: String, reclaim: Long, count: Int, onClean: () -> Unit) {
    if (count <= 0) return
    HCard(Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.size(2.dp))
            Text("$count item${if (count == 1) "" else "s"} · ${SpaceCleanerEngine.humanSize(reclaim)}",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.size(10.dp))
            HPrimaryButton("Review & free up", modifier = Modifier.fillMaxWidth()) { onClean() }
        }
    }
}
