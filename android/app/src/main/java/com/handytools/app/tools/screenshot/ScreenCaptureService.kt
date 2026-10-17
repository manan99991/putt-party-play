package com.handytools.app.tools.screenshot

import com.handytools.app.ui.HandyHaptics

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.handytools.app.HandyApp
import com.handytools.app.MainActivity
import com.handytools.app.R
import com.handytools.app.tools.OverlayBubble
import com.handytools.app.tools.ocr.ScreenOcr
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * One foreground service powers both Screenshot+ (tool 2) and Grab Screen Text (tool 7).
 *
 * Modes: SINGLE (one frame), FULL_PAGE (long screenshot — Tenzy samples its own screen frames
 * while you scroll, de-dups, and stitches; no AccessibilityService), BURST (N frames 1s apart).
 *
 * Apps that set FLAG_SECURE come back as solid black from MediaProjection — we detect that
 * and refuse to save, which is the boundary you asked to respect.
 */
class ScreenCaptureService : Service() {

    enum class Mode { SINGLE, FULL_PAGE, BURST, OCR }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var bubble: OverlayBubble? = null
    private var busy = false

    // Long-screenshot session state (FULL_PAGE): tap once to start sampling, tap again to stitch.
    private var longActive = false
    private var longJob: Job? = null
    private val longFrames = mutableListOf<Bitmap>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startFg()
                val code = intent.getIntExtra("code", 0)
                val data: Intent? = intent.getParcelableExtra("data")
                if (data != null) setupProjection(code, data)
                mode = Mode.valueOf(intent.getStringExtra("mode") ?: Mode.SINGLE.name)
                showBubble()
            }
            ACTION_STOP -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startFg() {
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, javaClass).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val n: Notification = NotificationCompat.Builder(this, HandyApp.CH_TOOLS)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle("Screenshot+ is on")
            .setContentText("Tap the floating button in any app to capture.")
            .setContentIntent(pi)
            .addAction(0, "Stop", stop)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        else startForeground(NOTIF_ID, n)
    }

    private fun setupProjection(code: Int, data: Intent) {
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = mpm.getMediaProjection(code, data)?.also { p ->
            p.registerCallback(object : MediaProjection.Callback() { override fun onStop() { stopSelf() } }, Handler(Looper.getMainLooper()))
            val dm = resources.displayMetrics
            reader = ImageReader.newInstance(dm.widthPixels, dm.heightPixels, PixelFormat.RGBA_8888, 2)
            display = p.createVirtualDisplay("handytools", dm.widthPixels, dm.heightPixels, dm.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader!!.surface, null, null)
        }
    }

    private fun showBubble() {
        if (bubble == null) {
            bubble = OverlayBubble(this, R.drawable.ic_notif, bg = 0xFFE53935.toInt()) { onBubbleTap() }
            bubble?.show()
        }
    }

    private fun onBubbleTap() {
        // Long screenshot is a session: first tap starts, second tap finishes + stitches.
        if (mode == Mode.FULL_PAGE) { if (longActive) finishLongCapture() else startLongCapture(); return }
        if (busy) return
        busy = true
        bubble?.setVisible(false)
        scope.launch {
            try {
                delay(250) // let the bubble disappear before we grab the frame
                when (mode) {
                    Mode.SINGLE -> captureFrame()?.let { save(it, "shot") }
                    Mode.BURST -> repeat(3) { i -> captureFrame()?.let { save(it, "burst${i + 1}") }; delay(1000) }
                    Mode.OCR -> captureFrame()?.let { ScreenOcr.recognizeAndCopy(this@ScreenCaptureService, it) }
                    Mode.FULL_PAGE -> Unit // handled above
                }
            } finally {
                bubble?.setVisible(true); busy = false
            }
        }
    }

    /** Grabs the latest frame. Returns null (and toasts) if the app is FLAG_SECURE. */
    private suspend fun captureFrame(): Bitmap? = withContext(Dispatchers.IO) {
        val r = reader ?: return@withContext null
        var img = r.acquireLatestImage()
        var tries = 0
        while (img == null && tries++ < 10) { Thread.sleep(50); img = r.acquireLatestImage() }
        img ?: return@withContext null
        val plane = img.planes[0]
        val w = img.width; val h = img.height
        val rowPadding = plane.rowStride - plane.pixelStride * w
        val bmp = Bitmap.createBitmap(w + rowPadding / plane.pixelStride, h, Bitmap.Config.ARGB_8888)
        bmp.copyPixelsFromBuffer(plane.buffer)
        img.close()
        val cropped = Bitmap.createBitmap(bmp, 0, 0, w, h)
        if (isBlack(cropped)) {
            withContext(Dispatchers.Main) { toast("This app blocks screenshots — respecting that.") }
            return@withContext null
        }
        cropped
    }

    private fun isBlack(b: Bitmap): Boolean {
        val step = 32
        var dark = 0; var total = 0
        for (y in 0 until b.height step step) for (x in 0 until b.width step step) {
            total++; if (b.getPixel(x, y) and 0xFFFFFF == 0) dark++
        }
        return total > 0 && dark.toFloat() / total > 0.98f
    }

    /**
     * Long screenshot, no AccessibilityService: once started, Tenzy grabs a frame of its own
     * MediaProjection stream roughly once a second while you scroll the page by hand. Frames that
     * are nearly identical to the last kept one (you paused, or hit the bottom) are dropped, so
     * you just scroll at a comfortable pace and tap the button again to stitch + save.
     */
    private fun startLongCapture() {
        if (longActive) return
        longActive = true
        longFrames.clear()
        toast("Long shot: scroll down slowly. Tap the button again to finish.")
        longJob = scope.launch {
            captureLongFrame()
            while (longActive && longFrames.size < MAX_PAGES) {
                delay(900)
                captureLongFrame()
            }
            if (longActive && longFrames.size >= MAX_PAGES) { toast("Reached max length"); finishLongCapture() }
        }
    }

    private suspend fun captureLongFrame() {
        bubble?.setVisible(false)
        delay(120) // let the bubble clear the frame
        val f = captureFrame()
        bubble?.setVisible(true)
        f ?: return
        val last = longFrames.lastOrNull()
        if (last != null && nearlySame(last, f)) return // paused or bottom — nothing new
        longFrames += f
    }

    private fun finishLongCapture() {
        if (!longActive) return
        longActive = false
        longJob?.cancel()
        val frames = longFrames.toList()
        longFrames.clear()
        if (frames.isEmpty()) { toast("Nothing captured"); return }
        scope.launch {
            toast("Stitching ${frames.size} screens…")
            val out = withContext(Dispatchers.Default) { Stitcher.stitch(frames) }
            save(out, "longshot")
        }
    }

    /** Cheap sampled comparison: true when two frames are visually the same (scrolling stopped). */
    private fun nearlySame(a: Bitmap, b: Bitmap): Boolean {
        if (a.width != b.width || a.height != b.height) return false
        val stepX = maxOf(1, a.width / 24)
        val stepY = maxOf(1, a.height / 40)
        var diff = 0L; var n = 0
        var y = (a.height * 0.1f).toInt()
        val yEnd = (a.height * 0.9f).toInt()
        while (y < yEnd) {
            var x = 0
            while (x < a.width) {
                val pa = a.getPixel(x, y); val pb = b.getPixel(x, y)
                diff += kotlin.math.abs((pa shr 16 and 0xFF) - (pb shr 16 and 0xFF)) +
                    kotlin.math.abs((pa shr 8 and 0xFF) - (pb shr 8 and 0xFF)) +
                    kotlin.math.abs((pa and 0xFF) - (pb and 0xFF))
                n++; x += stepX
            }
            y += stepY
        }
        return n > 0 && diff / n < 8
    }

    private suspend fun save(b: Bitmap, tag: String) = withContext(Dispatchers.IO) {
        val name = "Tenzy_${tag}_${System.currentTimeMillis()}.png"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tenzy")
        }
        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return@withContext
        contentResolver.openOutputStream(uri)?.use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        withContext(Dispatchers.Main) {
            com.handytools.app.ui.HandyHaptics.medium(this@ScreenCaptureService)
            toast("Saved to Pictures/Tenzy")
        }
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()

    override fun onDestroy() {
        longActive = false; longJob?.cancel()
        bubble?.hide()
        display?.release(); reader?.close(); projection?.stop()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val NOTIF_ID = 1001
        const val MAX_PAGES = 12
        @Volatile var mode: Mode = Mode.SINGLE
    }
}

/** Vertical stitcher: finds where frame N+1's top overlaps frame N's bottom and appends the new part. */
object Stitcher {
    fun stitch(frames: List<Bitmap>): Bitmap {
        if (frames.size == 1) return frames[0]
        val w = frames[0].width
        val pieces = mutableListOf<Pair<Bitmap, Int>>() // bitmap, startY within it
        pieces += frames[0] to 0
        var totalH = frames[0].height
        for (i in 1 until frames.size) {
            val prev = frames[i - 1]; val cur = frames[i]
            val overlap = findOverlap(prev, cur)
            val newPart = cur.height - overlap
            if (newPart <= 0) continue
            pieces += cur to overlap
            totalH += newPart
        }
        val out = Bitmap.createBitmap(w, totalH, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        var y = 0
        pieces.forEach { (bmp, start) ->
            val h = bmp.height - start
            c.drawBitmap(bmp, android.graphics.Rect(0, start, w, bmp.height), android.graphics.Rect(0, y, w, y + h), null)
            y += h
        }
        return out
    }

    /** Rows of cur (from the top) that duplicate the bottom of prev. Sampled for speed. */
    private fun findOverlap(prev: Bitmap, cur: Bitmap): Int {
        val h = prev.height; val w = prev.width
        val sampleX = (0 until w step maxOf(1, w / 24)).toList()
        // skip status bar region (top 8%) and nav region (bottom 8%) which don't scroll
        val minOverlap = (h * 0.08).toInt(); val maxOverlap = (h * 0.92).toInt()
        var best = minOverlap; var bestScore = Int.MAX_VALUE
        for (ov in minOverlap..maxOverlap step 2) {
            var diff = 0
            val rows = listOf(ov / 4, ov / 2, ov * 3 / 4)
            for (r in rows) for (x in sampleX) {
                val a = prev.getPixel(x, h - ov + r); val b = cur.getPixel(x, r)
                diff += colorDist(a, b)
                if (diff > bestScore) break
            }
            if (diff < bestScore) { bestScore = diff; best = ov }
        }
        return best
    }

    private fun colorDist(a: Int, b: Int): Int =
        kotlin.math.abs((a shr 16 and 0xFF) - (b shr 16 and 0xFF)) +
            kotlin.math.abs((a shr 8 and 0xFF) - (b shr 8 and 0xFF)) +
            kotlin.math.abs((a and 0xFF) - (b and 0xFF))
}
