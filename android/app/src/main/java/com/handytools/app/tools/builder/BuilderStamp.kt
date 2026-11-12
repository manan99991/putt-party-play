package com.handytools.app.tools.builder

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.handytools.app.ui.Handy
import java.io.File
import java.util.Date
import kotlin.math.roundToInt

/** Your signature and name, saved once on this phone so "Sign and stamp" can use them every time. */
object StampBook {
    private fun file(ctx: Context) = File(File(ctx.filesDir, "stamps").also { it.mkdirs() }, "signature.png")

    fun signature(ctx: Context): Bitmap? = runCatching { file(ctx).takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) } }.getOrNull()
    fun saveSignature(ctx: Context, bmp: Bitmap): Boolean = runCatching { file(ctx).outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) } }.getOrDefault(false)

    fun name(ctx: Context): String = ctx.getSharedPreferences("builder", Context.MODE_PRIVATE).getString("stampName", "") ?: ""
    fun setName(ctx: Context, name: String) { ctx.getSharedPreferences("builder", Context.MODE_PRIVATE).edit().putString("stampName", name).apply() }

    fun dateText(day: Date): String = java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM).format(day)

    /** A copy of the page with every mark drawn in. Text is sized to span its width, like the iPhone version. */
    fun render(page: Bitmap, spots: List<StampSpot>, sig: Bitmap?, name: String, day: Date): Bitmap {
        val out = page.copy(Bitmap.Config.ARGB_8888, true)
        val c = Canvas(out)
        val pw = out.width.toFloat(); val ph = out.height.toFloat()
        for (s in spots) {
            val w = (s.w * pw).toFloat(); val cx = (s.x * pw).toFloat(); val cy = (s.y * ph).toFloat()
            if (s.mark == StampPlan.SIG) {
                if (sig == null) continue
                val h = w * sig.height / maxOf(1, sig.width)
                c.drawBitmap(sig, null, RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
            } else {
                val text = if (s.mark == StampPlan.NAME) name else dateText(day)
                if (text.isEmpty()) continue
                val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.BLACK; textSize = 100f }
                val m = p.measureText(text)
                if (m > 0f) p.textSize = (100f * w / m).coerceIn(8f, maxOf(8f, ph * 0.05f))
                c.drawText(text, cx - p.measureText(text) / 2, cy - (p.descent() + p.ascent()) / 2, p)
            }
        }
        return out
    }

    /** The drawn strokes as a see-through picture cropped to the ink. Null when nothing was drawn. */
    fun inkBitmap(strokes: List<List<Offset>>, w: Int, h: Int, strokePx: Float): Bitmap? {
        if (strokes.isEmpty() || w <= 0 || h <= 0) return null
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF14148A.toInt(); style = Paint.Style.STROKE; strokeWidth = strokePx; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        }
        var minX = w.toFloat(); var minY = h.toFloat(); var maxX = 0f; var maxY = 0f
        for (s in strokes) {
            val path = Path()
            s.forEachIndexed { i, o ->
                if (i == 0) path.moveTo(o.x, o.y) else path.lineTo(o.x, o.y)
                minX = minOf(minX, o.x); minY = minOf(minY, o.y); maxX = maxOf(maxX, o.x); maxY = maxOf(maxY, o.y)
            }
            c.drawPath(path, paint)
        }
        if (maxX <= minX || maxY <= minY) return null
        val pad = strokePx * 2
        val l = (minX - pad).toInt().coerceIn(0, w - 1); val t = (minY - pad).toInt().coerceIn(0, h - 1)
        val r = (maxX + pad).toInt().coerceIn(l + 1, w); val b = (maxY + pad).toInt().coerceIn(t + 1, h)
        return Bitmap.createBitmap(bmp, l, t, r - l, b - t)
    }
}

/** Settings for "Sign and stamp": what to put on the page, your signature and name, and where each one goes. */
@Composable
fun StampSettings(marks: String, onChange: (String) -> Unit) {
    val ctx = LocalContext.current
    val spots = StampPlan.parse(marks)
    var saved by remember { mutableStateOf(StampBook.signature(ctx)) }
    var drawing by remember { mutableStateOf(saved == null) }
    var name by remember { mutableStateOf(StampBook.name(ctx)) }
    val strokes = remember { mutableStateListOf<List<Offset>>() }
    var pad by remember { mutableStateOf(IntSize.Zero) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        StampPlan.MARKS.forEach { mark ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(spots.any { it.mark == mark }, { on -> onChange(StampPlan.text(StampPlan.set(spots, mark, on))) })
                Text("  " + StampPlan.title(mark), style = MaterialTheme.typography.bodyMedium)
            }
        }
        if (spots.any { it.mark == StampPlan.SIG }) {
            val sig = saved
            if (sig != null && !drawing) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(sig.asImageBitmap(), "Your saved signature", Modifier.height(48.dp).widthIn(max = 180.dp))
                    TextButton({ strokes.clear(); drawing = true }) { Text("Draw again") }
                }
            } else {
                Text("Draw your signature once. It is kept on this phone.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Box(
                    Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(10.dp)).background(Color.White)
                        .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        .onSizeChanged { pad = it }
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragStart = { o -> strokes.add(listOf(o)) },
                                onDrag = { change, _ ->
                                    change.consume()
                                    if (strokes.isNotEmpty()) strokes[strokes.lastIndex] = strokes.last() + change.position
                                })
                        }
                ) {
                    androidx.compose.foundation.Canvas(Modifier.matchParentSize()) {
                        strokes.forEach { s -> for (i in 1 until s.size) drawLine(Color(0xFF14148A), s[i - 1], s[i], strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round) }
                    }
                }
                Row {
                    TextButton({
                        val bmp = StampBook.inkBitmap(strokes.toList(), pad.width, pad.height, 4f * ctx.resources.displayMetrics.density)
                        if (bmp != null && StampBook.saveSignature(ctx, bmp)) { saved = bmp; drawing = false }
                    }, enabled = strokes.isNotEmpty()) { Text("Save signature") }
                    TextButton({ strokes.clear() }) { Text("Clear") }
                    if (saved != null) TextButton({ drawing = false }) { Text("Keep the old one") }
                }
            }
        }
        if (spots.any { it.mark == StampPlan.NAME }) {
            OutlinedTextField(name, { v -> name = v; StampBook.setName(ctx, v) }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Your name, as it should appear") })
        }
        if (spots.isNotEmpty()) {
            Text("Drag each label to where it belongs on your form. The tool puts them there every time.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            val latest by rememberUpdatedState(spots)
            val send by rememberUpdatedState(onChange)
            BoxWithConstraints(
                Modifier.widthIn(max = 240.dp).fillMaxWidth().aspectRatio(1f / 1.414f).clip(RoundedCornerShape(6.dp)).background(Color.White)
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(6.dp))
            ) {
                val wPx = constraints.maxWidth.toFloat().coerceAtLeast(1f); val hPx = constraints.maxHeight.toFloat().coerceAtLeast(1f)
                val chipW = 76.dp; val chipH = 28.dp
                val halfW = chipW.value * ctx.resources.displayMetrics.density / 2; val halfH = chipH.value * ctx.resources.displayMetrics.density / 2
                spots.forEach { s ->
                    Box(
                        Modifier.offset { IntOffset((s.x * wPx - halfW).roundToInt(), (s.y * hPx - halfH).roundToInt()) }
                            .widthIn(min = chipW).height(chipH).clip(RoundedCornerShape(8.dp)).background(MaterialTheme.colorScheme.primary)
                            .pointerInput(s.mark) {
                                detectDragGestures { change, drag ->
                                    change.consume()
                                    send(StampPlan.text(StampPlan.moved(latest, s.mark, (drag.x / wPx).toDouble(), (drag.y / hPx).toDouble())))
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) { Text(StampPlan.short(s.mark), Modifier.padding(horizontal = 8.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onPrimary) }
                }
            }
        }
    }
}
