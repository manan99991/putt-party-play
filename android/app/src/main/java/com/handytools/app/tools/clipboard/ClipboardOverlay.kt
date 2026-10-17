package com.handytools.app.tools.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
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
 * The floating clipboard stack: a bubble that opens a bottom panel listing every copy.
 * Tap a row -> pasted into the focused field (via the accessibility service) or, if nothing
 * is focused, placed on the clipboard. "Copy all" joins them with newlines.
 */
object ClipboardOverlay {
    private const val PREF = "clip_overlay"
    @Volatile var lastPastedText: String? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var bubble: OverlayBubble? = null
    private var panel: OverlayPanel? = null
    private var list: LinearLayout? = null

    fun isEnabled(ctx: Context) = ctx.getSharedPreferences(PREF, 0).getBoolean("on", false)
    fun setEnabled(ctx: Context, on: Boolean) {
        ctx.getSharedPreferences(PREF, 0).edit().putBoolean("on", on).apply()
        val svc = ClipboardAccessibilityService.instance
        if (on && svc != null) showIfEnabled(svc) else hide()
    }

    fun showIfEnabled(ctx: Context) {
        if (!isEnabled(ctx) || !android.provider.Settings.canDrawOverlays(ctx)) return
        if (bubble != null) return
        val d = ctx.resources.displayMetrics.density
        list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding((16 * d).toInt(), (12 * d).toInt(), (16 * d).toInt(), (12 * d).toInt()) }
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            val header = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding((16 * d).toInt(), (14 * d).toInt(), (8 * d).toInt(), 0)
                addView(TextView(ctx).apply {
                    text = "Clipboard stack"; setTextColor(Color.WHITE); textSize = 17f; typeface = Typeface.DEFAULT_BOLD
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                })
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
                l.addView(TextView(ctx).apply { text = "Copy something in any app — it shows up here."; setTextColor(0xFFAAAAAA.toInt()); setPadding(0, 24, 0, 24) })
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
            setOnClickListener { paste(ctx, c.text) }
            setOnLongClickListener {
                scope.launch { HandyApp.instance.db.clips().update(c.copy(pinned = !c.pinned)); refresh() }; true
            }
        }
    }

    private fun paste(ctx: Context, text: String) {
        panel?.hide()
        val pasted = ClipboardAccessibilityService.instance?.pasteIntoFocused(text) == true
        if (!pasted) {
            lastPastedText = text
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Oddbox", text))
            Toast.makeText(ctx, "Ready to paste", Toast.LENGTH_SHORT).show()
        }
    }

    private fun copyAll(ctx: Context) {
        scope.launch {
            val all = withContext(Dispatchers.IO) { HandyApp.instance.db.clips().allOnce() }
            val joined = all.joinToString("\n") { it.text }
            lastPastedText = joined
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Oddbox", joined))
            Toast.makeText(ctx, "${all.size} items copied, ready to paste", Toast.LENGTH_SHORT).show()
            panel?.hide()
        }
    }

    private fun smallButton(ctx: Context, label: String, onClick: () -> Unit) = Button(ctx).apply {
        text = label; textSize = 12f; isAllCaps = false; setOnClickListener { onClick() }
        setTextColor(Color.WHITE); setBackgroundColor(Color.TRANSPARENT); gravity = Gravity.CENTER
    }
}
