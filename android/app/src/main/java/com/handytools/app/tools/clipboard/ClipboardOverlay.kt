package com.handytools.app.tools.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.handytools.app.HandyApp
import com.handytools.app.R
import com.handytools.app.data.Clip
import com.handytools.app.tools.OverlayBubble
import com.handytools.app.tools.OverlayPanel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The floating clipboard stack: a bubble that opens a panel listing every clip you've saved.
 * Hosted by [ClipboardBubbleService] (a draw-over-apps overlay — no AccessibilityService).
 *
 * Capture is deliberate and compliant: "+ Grab copy" pulls in whatever is on the clipboard now,
 * or you Share → Save to Tenzy, or use the Quick-Settings tile. Tap a row to re-copy it, then
 * paste where you need it. "Copy all" joins them with newlines.
 */
object ClipboardOverlay {
    private const val PREF = "clip_overlay"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var bubble: OverlayBubble? = null
    private var panel: OverlayPanel? = null
    private var list: LinearLayout? = null

    fun isEnabled(ctx: Context) = ctx.getSharedPreferences(PREF, 0).getBoolean("on", false)

    fun setEnabled(ctx: Context, on: Boolean) {
        ctx.getSharedPreferences(PREF, 0).edit().putBoolean("on", on).apply()
        val i = Intent(ctx, ClipboardBubbleService::class.java)
        if (on) ContextCompat.startForegroundService(ctx, i)
        else ctx.stopService(i)
    }

    /** Built by the bubble service once it's foreground and overlay permission is granted. */
    fun show(ctx: Context) {
        if (!android.provider.Settings.canDrawOverlays(ctx) || bubble != null) return
        val d = ctx.resources.displayMetrics.density
        list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding((16 * d).toInt(), (12 * d).toInt(), (16 * d).toInt(), (12 * d).toInt()) }
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            val header = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding((16 * d).toInt(), (14 * d).toInt(), (8 * d).toInt(), 0)
                addView(TextView(ctx).apply {
                    text = "Clipboard"; setTextColor(Color.WHITE); textSize = 17f; typeface = Typeface.DEFAULT_BOLD
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                })
                addView(smallButton(ctx, "+ Grab copy") { grabCurrent(ctx) })
                addView(smallButton(ctx, "Copy all") { copyAll(ctx) })
                addView(smallButton(ctx, "Clear") { scope.launch { HandyApp.instance.db.clips().clearUnpinned(); refresh() } })
            }
            addView(header)
            addView(ScrollView(ctx).apply { addView(list) })
        }
        panel = OverlayPanel(ctx, root)
        bubble = OverlayBubble(ctx, R.drawable.ic_notif, onTap = { panel?.toggle(); refresh() })
        bubble?.show()
        refresh()
    }

    fun hide() {
        panel?.hide(); bubble?.hide()
        panel = null; bubble = null; list = null
    }

    fun refresh() {
        val l = list ?: return
        val ctx = l.context
        scope.launch {
            val clips = withContext(Dispatchers.IO) { HandyApp.instance.db.clips().allOnce() }
            l.removeAllViews()
            if (clips.isEmpty()) {
                l.addView(TextView(ctx).apply {
                    text = "No clips yet. Tap “+ Grab copy” after copying something, or Share → Save to Tenzy from any app."
                    setTextColor(0xFFAAAAAA.toInt()); setPadding(0, 24, 0, 24); textSize = 14f
                })
            }
            clips.forEach { c -> l.addView(row(ctx, c)) }
        }
    }

    private fun row(ctx: Context, c: Clip): TextView {
        val d = ctx.resources.displayMetrics.density
        return TextView(ctx).apply {
            text = (if (c.pinned) "📌 " else "") + c.text.replace('\n', ' ').take(160)
            setTextColor(Color.WHITE); textSize = 15f; maxLines = 2
            setPadding((12 * d).toInt(), (12 * d).toInt(), (12 * d).toInt(), (12 * d).toInt())
            setBackgroundColor(0x1AFFFFFF)
            (layoutParams as? LinearLayout.LayoutParams ?: LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)).also {
                it.bottomMargin = (8 * d).toInt(); layoutParams = it
            }
            setOnClickListener { recopy(ctx, c.text) }
            setOnLongClickListener {
                scope.launch { HandyApp.instance.db.clips().update(c.copy(pinned = !c.pinned)); refresh() }; true
            }
        }
    }

    /** Re-copy a saved clip to the system clipboard, ready to paste in the field you're in. */
    private fun recopy(ctx: Context, text: String) {
        panel?.hide()
        (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
            .setPrimaryClip(ClipData.newPlainText("Tenzy", text))
        Toast.makeText(ctx, "Copied — long-press the field and tap Paste", Toast.LENGTH_SHORT).show()
    }

    /** Pull whatever is on the clipboard right now into the stack (via the transparent grabber). */
    private fun grabCurrent(ctx: Context) {
        panel?.hide()
        runCatching { ctx.startActivity(SaveClipActivity.grabIntent(ctx)) }
    }

    private fun copyAll(ctx: Context) {
        scope.launch {
            val all = withContext(Dispatchers.IO) { HandyApp.instance.db.clips().allOnce() }
            if (all.isEmpty()) { Toast.makeText(ctx, "Nothing to copy yet", Toast.LENGTH_SHORT).show(); return@launch }
            val joined = all.joinToString("\n") { it.text }
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", joined))
            Toast.makeText(ctx, "${all.size} items copied, ready to paste", Toast.LENGTH_SHORT).show()
            panel?.hide()
        }
    }

    private fun smallButton(ctx: Context, label: String, onClick: () -> Unit) = Button(ctx).apply {
        text = label; textSize = 12f; isAllCaps = false; setOnClickListener { onClick() }
        setTextColor(Color.WHITE); setBackgroundColor(Color.TRANSPARENT); gravity = Gravity.CENTER
        minWidth = 0; minimumWidth = 0
        setPadding((10 * ctx.resources.displayMetrics.density).toInt(), 0, (10 * ctx.resources.displayMetrics.density).toInt(), 0)
    }
}
