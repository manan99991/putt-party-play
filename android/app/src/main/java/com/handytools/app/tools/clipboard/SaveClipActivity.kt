package com.handytools.app.tools.clipboard

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * No-UI, fully transparent. Two ways in, both Play-compliant:
 *   1. Share sheet — another app shares text to "Save to Tenzy"; we store EXTRA_TEXT.
 *   2. "Grab current copy" — the Quick-Settings tile or the bubble launches us; we read the
 *      system clipboard while briefly foreground (reading needs window focus, which we have here).
 */
class SaveClipActivity : ComponentActivity() {
    private var handled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
        val shared = if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text") == true)
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() else null
        if (!shared.isNullOrBlank()) { handled = true; save(shared, "shared") }
        // Otherwise wait for window focus (onWindowFocusChanged) and read the clipboard there.
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !handled) {
            handled = true
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val text = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString()
            if (text.isNullOrBlank()) { toast("Clipboard is empty — copy something first"); finish() }
            else save(text, "clipboard")
        }
    }

    private fun save(text: String, src: String) {
        lifecycleScope.launch {
            val added = withContext(Dispatchers.IO) { ClipStore.save(text, src) }
            toast(if (added) "Saved to Tenzy" else "Already your latest clip")
            finish()
            overridePendingTransition(0, 0)
        }
    }

    private fun toast(s: String) = Toast.makeText(applicationContext, s, Toast.LENGTH_SHORT).show()

    companion object {
        /** Launch to grab whatever is on the clipboard right now. */
        fun grabIntent(ctx: Context): Intent =
            Intent(ctx, SaveClipActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
    }
}
