package com.handytools.app.tools.receipts

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.CalendarContract
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

private val moneyRe = Regex("""(?:\$|£|€)?\s?(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2})""")

/**
 * Receipt & Warranty Keeper. Snap a receipt; the merchant, total and date are read on-device and
 * pre-filled, you set the warranty length, and it's filed with the photo. See what's expiring soon
 * and drop a reminder into your calendar in one tap. Everything stays on the phone.
 */
@Composable
fun ReceiptKeeperScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val receipts = remember { mutableStateListOf<Receipt>() }
    var busy by remember { mutableStateOf(false) }

    // Draft being added (after a photo is picked + OCR'd)
    var draftImage by remember { mutableStateOf<String?>(null) }
    var merchant by remember { mutableStateOf("") }
    var total by remember { mutableStateOf("") }
    var months by remember { mutableStateOf("12") }

    val recognizer = remember { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }
    val df = remember { SimpleDateFormat("d MMM yyyy", Locale.getDefault()) }

    LaunchedEffect(Unit) { receipts.addAll(ReceiptStore.load(ctx)) }

    fun persist() = ReceiptStore.save(ctx, receipts.toList())

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true
        scope.launch {
            val res = withContext(Dispatchers.IO) {
                try {
                    val id = System.currentTimeMillis()
                    val dst = File(ctx.filesDir, "receipt_$id.jpg")
                    ctx.contentResolver.openInputStream(uri)?.use { input -> dst.outputStream().use { input.copyTo(it) } }
                    val bmp = BitmapFactory.decodeFile(dst.absolutePath) ?: return@withContext null
                    val vt = recognizer.process(InputImage.fromBitmap(bmp, 0)).await()
                    bmp.recycle()
                    Triple(dst.absolutePath, guessMerchant(vt.text), guessTotal(vt.text))
                } catch (e: Exception) { null }
            }
            busy = false
            if (res != null) {
                draftImage = res.first; merchant = res.second; total = res.third; months = "12"
                HandyHaptics.light(ctx)
            }
        }
    }

    fun saveDraft() {
        val img = draftImage ?: return
        receipts.add(Receipt(System.currentTimeMillis(), merchant.ifBlank { "Receipt" }, total.trim(), System.currentTimeMillis(), months.toIntOrNull() ?: 12, img))
        receipts.sortBy { it.warrantyEndMs }
        persist()
        draftImage = null; merchant = ""; total = ""
        HandyHaptics.success(ctx)
    }

    fun remind(r: Receipt) {
        val intent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.Events.TITLE, "Warranty ends: ${r.merchant}")
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, r.warrantyEndMs)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, r.warrantyEndMs + 3_600_000L)
            .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
            .putExtra(CalendarContract.Events.DESCRIPTION, "Total ${r.total}. Receipt kept in Tenzy.")
        try { ctx.startActivity(intent) } catch (_: Exception) {}
    }

    fun delete(r: Receipt) {
        runCatching { File(r.imagePath).delete() }
        receipts.remove(r); persist()
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Receipt & Warranty Keeper", "Snap a receipt, set the warranty, and never miss the window to return or claim.")
        Spacer(Modifier.size(16.dp))

        if (draftImage == null) {
            HPrimaryButton(if (busy) "Reading…" else "Add a receipt", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
                picker.launch("image/*")
            }
        } else {
            Text("New receipt", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.size(10.dp))
            OutlinedTextField(merchant, { merchant = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Merchant") })
            Spacer(Modifier.size(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(total, { total = it }, modifier = Modifier.weight(1f), label = { Text("Total") })
                OutlinedTextField(months, { months = it.filter { c -> c.isDigit() }.take(3) }, modifier = Modifier.weight(1f), label = { Text("Warranty (months)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            }
            Spacer(Modifier.size(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HSecondaryButton("Cancel", modifier = Modifier.weight(1f)) { draftImage = null }
                HPrimaryButton("Save receipt", modifier = Modifier.weight(1f)) { saveDraft() }
            }
        }

        if (receipts.isNotEmpty()) {
            Spacer(Modifier.size(20.dp))
            Text("Saved (${receipts.size})", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
            val now = System.currentTimeMillis()
            receipts.toList().forEach { r ->
                Spacer(Modifier.size(12.dp))
                Row(Modifier.fillMaxWidth()) {
                    val thumb = remember(r.imagePath) { decodeSampled(r.imagePath, 160) }
                    if (thumb != null) Image(thumb.asImageBitmap(), contentDescription = null, modifier = Modifier.size(56.dp).clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop)
                    Spacer(Modifier.size(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(r.merchant, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                        val days = ((r.warrantyEndMs - now) / 86_400_000L).toInt()
                        val when_ = when {
                            days < 0 -> "Warranty expired ${df.format(Date(r.warrantyEndMs))}"
                            days == 0 -> "Warranty ends today"
                            days <= 30 -> "Warranty ends in $days day${if (days == 1) "" else "s"} (${df.format(Date(r.warrantyEndMs))})"
                            else -> "Warranty ends ${df.format(Date(r.warrantyEndMs))}"
                        }
                        Text(if (r.total.isNotBlank()) "${r.total} · $when_" else when_, color = if (days in 0..30) HandyWarn else Handy.palette.textSecondary, fontSize = 12.sp)
                        Spacer(Modifier.size(6.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            HSecondaryButton("Remind") { remind(r) }
                            HSecondaryButton("Share") { Share.file(ctx, File(r.imagePath), "image/jpeg") }
                            HSecondaryButton("Delete") { delete(r) }
                        }
                    }
                }
            }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Read and stored on your phone only. “Remind” drops an event into your calendar app for you to confirm — no background alarms, no special permissions.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

private val HandyWarn = androidx.compose.ui.graphics.Color(0xFFB54708)

private fun guessMerchant(text: String): String =
    text.lineSequence().map { it.trim() }.firstOrNull { it.length in 2..40 && it.any { c -> c.isLetter() } } ?: ""

private fun guessTotal(text: String): String {
    var best = 0.0; var bestStr = ""
    for (m in moneyRe.findAll(text)) {
        val raw = m.groupValues[1].replace(",", "")
        val v = raw.toDoubleOrNull() ?: continue
        if (v >= best) { best = max(best, v); bestStr = m.value.trim() }
    }
    return bestStr
}

private fun decodeSampled(path: String, target: Int): android.graphics.Bitmap? {
    return try {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        var s = 1
        while (opts.outWidth / s > target || opts.outHeight / s > target) s *= 2
        BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = s })
    } catch (e: Exception) { null }
}
