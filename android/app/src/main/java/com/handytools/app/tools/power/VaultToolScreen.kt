package com.handytools.app.tools.power

import android.content.DialogInterface
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private data class VaultItem(val id: String, val name: String, val mime: String)

/**
 * Vault — a private locker behind your fingerprint or face. Files are encrypted with an AES-256 key
 * held in the device's secure hardware (Android Keystore) and stored in the app's private space, so
 * they're unreadable without this phone and your biometric. Nothing is uploaded.
 */
@Composable
fun VaultToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var unlocked by remember { mutableStateOf(false) }
    var items by remember { mutableStateOf<List<VaultItem>>(emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    fun vaultDir() = File(ctx.filesDir, "vault").apply { mkdirs() }

    fun loadItems() {
        items = vaultDir().listFiles { f -> f.name.endsWith(".bin") }?.mapNotNull { bin ->
            val id = bin.nameWithoutExtension
            try {
                val meta = String(VaultCrypto.decrypt(File(vaultDir(), "$id.hdr").readBytes()))
                val parts = meta.split("\u0000")
                VaultItem(id, parts.getOrElse(0) { "File" }, parts.getOrElse(1) { "application/octet-stream" })
            } catch (_: Throwable) { null }
        }?.sortedBy { it.name.lowercase() } ?: emptyList()
    }

    fun queryName(uri: Uri): String {
        var n = "file"
        try { ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) n = it.getString(0) ?: n } } catch (_: Throwable) {}
        return n
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; error = null
        scope.launch {
            withContext(Dispatchers.IO) {
                try {
                    val bytes = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@withContext
                    val name = queryName(uri); val mime = ctx.contentResolver.getType(uri) ?: "application/octet-stream"
                    val id = System.currentTimeMillis().toString()
                    File(vaultDir(), "$id.bin").writeBytes(VaultCrypto.encrypt(bytes))
                    File(vaultDir(), "$id.hdr").writeBytes(VaultCrypto.encrypt("$name\u0000$mime".toByteArray()))
                } catch (_: Throwable) {}
            }
            loadItems(); busy = false
        }
    }

    fun openItem(item: VaultItem) {
        scope.launch {
            val f = withContext(Dispatchers.IO) {
                try {
                    val bytes = VaultCrypto.decrypt(File(vaultDir(), "${item.id}.bin").readBytes())
                    File(ctx.cacheDir, item.name).apply { writeBytes(bytes) }
                } catch (_: Throwable) { null }
            }
            if (f != null) Share.file(ctx, f, item.mime) else error = "Couldn't open that item."
        }
    }

    fun deleteItem(item: VaultItem) {
        File(vaultDir(), "${item.id}.bin").delete()
        File(vaultDir(), "${item.id}.hdr").delete()
        loadItems()
    }

    fun unlock() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) { error = "The vault needs Android 9 or newer."; return }
        error = null
        try {
            val prompt = BiometricPrompt.Builder(ctx)
                .setTitle("Unlock Vault")
                .setDescription("Confirm it's you to open your private vault")
                .setNegativeButton("Cancel", ctx.mainExecutor, DialogInterface.OnClickListener { _, _ -> })
                .build()
            prompt.authenticate(CancellationSignal(), ctx.mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    unlocked = true; loadItems()
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Dismissing the sheet isn't an error worth shouting about. The system supplies an
                    // accurate message for the rest (e.g. "no biometrics enrolled", lockout).
                    val dismissed = errorCode == BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.BIOMETRIC_ERROR_CANCELED ||
                        errorCode == BiometricPrompt.BIOMETRIC_ERROR_NEGATIVE_BUTTON
                    if (!dismissed) error = errString.toString()
                }
            })
        } catch (e: Throwable) {
            // The prompt couldn't even start — don't claim biometrics are missing; they may well be
            // enrolled (the real cause here was a missing USE_BIOMETRIC permission).
            error = "Couldn't start biometric unlock on this phone."
        }
    }

    PowerToolPage("vault") {
        if (!unlocked) {
            PreviewBox(minHeight = 180.dp) {
                Text("Your files, locked behind your fingerprint or face. Encrypted on this phone with a key that never leaves its secure hardware.",
                    style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
            }
            Spacer(Modifier.height(14.dp))
            HPrimaryButton("Unlock with biometrics") { unlock() }
            error?.let { Spacer(Modifier.height(10.dp)); Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium) }
        } else {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HPrimaryButton(if (busy) "Encrypting…" else "Add a file", Modifier.weight(1f), enabled = !busy) { picker.launch("*/*") }
                HSecondaryButton("Lock", Modifier.weight(1f)) { unlocked = false; items = emptyList() }
            }
            Spacer(Modifier.height(14.dp))
            if (items.isEmpty()) {
                Text("Nothing in your vault yet. Add a file and it's encrypted the moment it lands here.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            } else {
                SectionLabel("${items.size} item${if (items.size == 1) "" else "s"}")
                items.forEach { item ->
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(14.dp)) {
                            Text(item.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                            Spacer(Modifier.height(8.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                HSecondaryButton("Open") { openItem(item) }
                                HSecondaryButton("Delete") { deleteItem(item) }
                            }
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }
            }
            error?.let { Spacer(Modifier.height(6.dp)); Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall) }
        }
        NoteText("Files are encrypted with AES-256 using a key stored in this device's secure hardware — unreadable without this phone and your biometric. Everything stays on the phone.")
    }
}
