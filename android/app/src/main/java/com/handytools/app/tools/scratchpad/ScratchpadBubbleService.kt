package com.handytools.app.tools.scratchpad

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import androidx.core.app.NotificationCompat
import com.handytools.app.HandyApp
import com.handytools.app.R
import com.handytools.app.data.Note
import com.handytools.app.tools.OverlayBubble
import com.handytools.app.tools.OverlayPanel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** A green bubble; tap it and a notepad slides up over whatever app you're in. Autosaves. */
class ScratchpadBubbleService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var bubble: OverlayBubble? = null
    private var panel: OverlayPanel? = null
    private lateinit var editor: EditText

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopSelf(); return START_NOT_STICKY }
        startFg()
        if (bubble == null) buildOverlay()
        return START_STICKY
    }

    private fun buildOverlay() {
        val d = resources.displayMetrics.density
        editor = EditText(this).apply {
            setTextColor(Color.WHITE); setHintTextColor(0xFF888888.toInt()); hint = "Jot anything…"
            textSize = 16f; gravity = Gravity.TOP
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            background = null
            setPadding((20 * d).toInt(), (20 * d).toInt(), (20 * d).toInt(), (20 * d).toInt())
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; addView(editor) }
        panel = OverlayPanel(this, root, heightDp = 300, focusable = true)
        bubble = OverlayBubble(this, R.drawable.ic_notif, bg = 0xFF2E7D32.toInt()) {
            val p = panel ?: return@OverlayBubble
            if (p.isShown) { save(); p.hide() } else { load(); p.show(); editor.requestFocus() }
        }
        bubble?.show()
        editor.setOnFocusChangeListener { _, has -> if (!has) save() }
    }

    private fun load() = scope.launch {
        val n = withContext(Dispatchers.IO) { HandyApp.instance.db.notes().getOnce() }
        editor.setText(n?.text ?: ""); editor.setSelection(editor.text.length)
    }

    private fun save() {
        val t = editor.text.toString()
        scope.launch { withContext(Dispatchers.IO) { HandyApp.instance.db.notes().save(Note(text = t)) } }
    }

    private fun startFg() {
        val stop = PendingIntent.getService(this, 3, Intent(this, javaClass).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, HandyApp.CH_TOOLS)
            .setSmallIcon(R.drawable.ic_notif).setContentTitle("Scratchpad bubble is on")
            .addAction(0, "Stop", stop).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(3001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(3001, n)
    }

    override fun onDestroy() {
        if (::editor.isInitialized) save()
        panel?.hide(); bubble?.hide()
        super.onDestroy()
    }

    companion object { const val ACTION_STOP = "stop" }
}
