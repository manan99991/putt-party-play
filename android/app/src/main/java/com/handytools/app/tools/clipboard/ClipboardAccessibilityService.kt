package com.handytools.app.tools.clipboard

import android.accessibilityservice.AccessibilityService
import android.content.ClipboardManager
import android.content.Context
import android.view.accessibility.AccessibilityEvent
import com.handytools.app.HandyApp
import com.handytools.app.data.Clip
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Android 10+ only lets the foreground app or the default IME read the clipboard — unless you're
 * an accessibility service, which is treated as "the user". So this service is the only
 * legitimate way to build a clipboard stack across apps. It stores text locally in Room and
 * never sends it anywhere.
 */
class ClipboardAccessibilityService : AccessibilityService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var lastSeen: String? = null
    private var currentPkg: String? = null

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener { captureClip() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        clipboard().addPrimaryClipChangedListener(clipListener)
        ClipboardOverlay.showIfEnabled(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            currentPkg = event.packageName?.toString()
        }
        // Some OEMs don't fire OnPrimaryClipChangedListener for background services;
        // text selection events are a cheap fallback poll.
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED) captureClip()
    }

    private fun captureClip() {
        val cm = clipboard()
        val text = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString()
            ?.trim()?.takeIf { it.isNotEmpty() } ?: return
        if (text == lastSeen) return
        lastSeen = text
        // Ignore clips we set ourselves when the user taps "paste"
        if (text == ClipboardOverlay.lastPastedText) return
        if (currentPkg == packageName) return
        val premium = HandyApp.instance.billing.isPremium.value
        scope.launch {
            val dao = HandyApp.instance.db.clips()
            val existing = dao.allOnce()
            if (existing.firstOrNull()?.text == text) return@launch
            dao.insert(Clip(text = text, sourceApp = currentPkg))
            // Free tier: keep last 20 unpinned
            if (!premium) existing.filter { !it.pinned }.drop(19).forEach { dao.delete(it) }
            ClipboardOverlay.refresh()
        }
    }

    /** Paste into whatever is focused right now. Uses the focused node's ACTION_PASTE. */
    fun pasteIntoFocused(text: String): Boolean {
        val cm = clipboard()
        ClipboardOverlay.lastPastedText = text
        cm.setPrimaryClip(android.content.ClipData.newPlainText("Tenzy", text))
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(android.view.accessibility.AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        return focused.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_PASTE)
    }

    private fun clipboard() = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    override fun onInterrupt() {}

    override fun onDestroy() {
        clipboard().removePrimaryClipChangedListener(clipListener)
        ClipboardOverlay.hide()
        instance = null
        super.onDestroy()
    }

    companion object {
        @Volatile var instance: ClipboardAccessibilityService? = null
    }
}
