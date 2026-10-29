package com.handytools.app.tools.power

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.log10
import kotlin.math.sqrt

// ---------------------------------------------------------------------------------------------
// Shared plumbing for the Instruments tool: sensor subscription, prefs, the mic meter, and the
// small readout composables every tab uses (big number, sub line, bar, reference table).
// ---------------------------------------------------------------------------------------------

/** Calibration values that survive between sessions. All on-device. */
internal class InstrumentPrefs(ctx: Context) {
    private val p = ctx.getSharedPreferences("instruments", Context.MODE_PRIVATE)
    var levelOffRoll: Float
        get() = p.getFloat("lv_roll", 0f); set(v) = p.edit().putFloat("lv_roll", v).apply()
    var levelOffPitch: Float
        get() = p.getFloat("lv_pitch", 0f); set(v) = p.edit().putFloat("lv_pitch", v).apply()
    var levelOffBar: Float
        get() = p.getFloat("lv_bar", 0f); set(v) = p.edit().putFloat("lv_bar", v).apply()
    var rulerFactor: Float
        get() = p.getFloat("ruler_factor", 1f); set(v) = p.edit().putFloat("ruler_factor", v).apply()
    var metalBeep: Boolean
        get() = p.getBoolean("metal_beep", false); set(v) = p.edit().putBoolean("metal_beep", v).apply()
    var metalThreshold: Float
        get() = p.getFloat("metal_thr", 30f); set(v) = p.edit().putFloat("metal_thr", v).apply()
    var altRef: Float
        get() = p.getFloat("alt_ref", Float.NaN); set(v) = p.edit().putFloat("alt_ref", v).apply()
}

/** Settings page for this app — where a denied runtime permission can be flipped back on. */
internal fun instrAppSettingsIntent(ctx: Context): Intent =
    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))

/**
 * Registers a sensor listener for as long as this composable is in the tree (so switching tab
 * unregisters it). Returns false when the phone has no such sensor, so the tab can say so.
 */
@Composable
internal fun rememberInstrSensor(
    type: Int,
    delay: Int = SensorManager.SENSOR_DELAY_UI,
    onAccuracy: (Int) -> Unit = {},
    onEvent: (SensorEvent) -> Unit,
): Boolean {
    val ctx = LocalContext.current
    val sm = remember { ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager }
    val sensor = remember(type) { sm.getDefaultSensor(type) }
    val latestEvent = rememberUpdatedState(onEvent)
    val latestAcc = rememberUpdatedState(onAccuracy)
    DisposableEffect(sensor) {
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) { latestEvent.value(event) }
            override fun onAccuracyChanged(s: Sensor?, a: Int) { latestAcc.value(a) }
        }
        if (sensor != null) sm.registerListener(listener, sensor, delay)
        onDispose { sm.unregisterListener(listener) }
    }
    return sensor != null
}

/** True when the phone has this sensor at all. */
internal fun instrHasSensor(ctx: Context, type: Int): Boolean =
    (ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager).getDefaultSensor(type) != null

/**
 * Mic RMS meter. Reads 16-bit PCM on a worker thread and reports an approximate dB level on the
 * main thread ~15 times a second. Nothing is recorded or kept.
 */
internal class InstrSoundMeter(private val onLevel: (Int) -> Unit) {
    @Volatile private var running = false
    private var thread: Thread? = null
    private val main = Handler(Looper.getMainLooper())

    fun start(): Boolean {
        if (running) return true
        val rate = 44100
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (min <= 0) return false
        val record = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, min * 2)
        } catch (e: Exception) { return false }
        if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); return false }
        running = true
        thread = Thread {
            val buf = ShortArray(rate / 15)
            try {
                record.startRecording()
                while (running) {
                    val n = record.read(buf, 0, buf.size)
                    if (n <= 0) continue
                    var sum = 0.0
                    for (i in 0 until n) { val v = buf[i].toDouble(); sum += v * v }
                    val rms = sqrt(sum / n) / 32767.0
                    val db = (20.0 * log10(if (rms < 1e-6) 1e-6 else rms) + 94.0).toInt().coerceIn(0, 120)
                    main.post { if (running) onLevel(db) }
                }
            } catch (_: Exception) {
            } finally {
                try { record.stop() } catch (_: Exception) {}
                record.release()
            }
        }.also { it.start() }
        return true
    }

    fun stop() {
        running = false
        thread?.join(300)
        thread = null
    }
}

/** Saves a bitmap into Pictures/Tenzy. Returns true on success. */
internal suspend fun instrSaveBitmap(ctx: Context, bitmap: Bitmap, tag: String): Boolean = withContext(Dispatchers.IO) {
    try {
        val name = "Tenzy_${tag}_${System.currentTimeMillis()}.jpg"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tenzy")
        }
        val uri = ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return@withContext false
        ctx.contentResolver.openOutputStream(uri)?.use { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) } ?: return@withContext false
        true
    } catch (_: Exception) { false }
}

// ---- readout pieces (prototype's .big / sub line / .prog / .cap-fields) ----------------------

@Composable
internal fun InstrBigReadout(text: String, color: Color = HandyColors.Accent) {
    Text(
        text, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold, color = color, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp), lineHeight = 44.sp
    )
}

@Composable
internal fun InstrSubLine(text: String, color: Color = Handy.palette.textSecondary) {
    Text(
        text, style = MaterialTheme.typography.bodySmall, color = color, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
    )
}

/** Thin rounded progress bar, 0..1, tinted. */
@Composable
internal fun InstrBar(fraction: Float, color: Color = HandyColors.Accent) {
    Box(
        Modifier.fillMaxWidth().padding(vertical = 8.dp).height(8.dp).clip(RoundedCornerShape(50))
            .background(Handy.palette.surfaceRaised.copy(alpha = if (Handy.palette.isDark) 1f else 0.6f))
    ) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).fillMaxHeight().background(color))
    }
}

internal data class InstrRef(val label: String, val value: String, val tint: Color? = null)

/** Reference table: label left, value right, hairline between rows. */
@Composable
internal fun InstrRefTable(rows: List<InstrRef>) {
    Column(Modifier.fillMaxWidth().padding(top = 10.dp)) {
        rows.forEach { r ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 7.dp),
                horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(r.label, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                Text(r.value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = r.tint ?: MaterialTheme.colorScheme.onSurface)
            }
            Box(Modifier.fillMaxWidth().height(1.dp).background(Handy.palette.border))
        }
    }
}
