package com.handytools.app.tools.clipboard

import com.handytools.app.HandyApp
import com.handytools.app.data.Clip

/**
 * The one place every capture path saves a clip: the Share-sheet target, the Quick-Settings
 * tile, the in-app "save current copy" button, and the floating bubble all funnel through here.
 *
 * No AccessibilityService: Android 10+ only lets the foreground app or the default keyboard read
 * the clipboard, so Tenzy captures when *you* hand it text (share / tile / button) instead of
 * silently watching every app — which is also what Google Play requires.
 */
object ClipStore {
    const val FREE_LIMIT = 20

    /** Saves [text]; returns true if a new clip was stored (false if it was already the latest). */
    suspend fun save(text: String, sourceApp: String?): Boolean {
        val t = text.trim()
        if (t.isEmpty()) return false
        val dao = HandyApp.instance.db.clips()
        val existing = dao.allOnce()
        if (existing.firstOrNull()?.text == t) return false
        // If the same text sits further down (unpinned), drop it so the re-save floats to the top.
        existing.firstOrNull { it.text == t && !it.pinned }?.let { dao.delete(it) }
        dao.insert(Clip(text = t, sourceApp = sourceApp))
        val premium = HandyApp.instance.billing.isPremium.value
        if (!premium) dao.allOnce().filter { !it.pinned }.drop(FREE_LIMIT - 1).forEach { dao.delete(it) }
        ClipboardOverlay.refresh()
        return true
    }
}
