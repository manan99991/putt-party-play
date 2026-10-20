package com.handytools.app.tools.sorted

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.CalendarContract
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import java.text.DateFormat
import java.util.Calendar
import java.util.Date

/** Sorted — snap a bill, appointment card, form or notice; get what it is, what you owe, and the key
 *  date, then add it to your calendar in a tap. OCR + date/amount extraction run on every phone; the
 *  "add to calendar" opens the system Calendar prefilled, so Sorted needs no calendar permission. */
@Composable
fun SortedScreen() {
    val ctx = LocalContext.current
    var text by remember { mutableStateOf(TextFieldValue("")) }
    var working by remember { mutableStateOf(false) }
    var parsed by remember { mutableStateOf<Parsed?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return@rememberLauncherForActivityResult
        working = true; parsed = null
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromBitmap(bmp, 0))
            .addOnSuccessListener { working = false; text = TextFieldValue(it.text) }
            .addOnFailureListener { working = false }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Sorted", "Snap a bill, appointment or notice — get what it is, what you owe and the deadline, then add it to your calendar.")
        Spacer(Modifier.size(16.dp))

        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                BasicTextField(value = text, onValueChange = { text = it }, modifier = Modifier.fillMaxWidth(),
                    textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                    decorationBox = { inner ->
                        if (text.text.isBlank()) Text("Snap or paste the document…", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
                        inner()
                    })
            }
        }
        Spacer(Modifier.size(8.dp))
        Row(Modifier.fillMaxWidth()) {
            HSecondaryButton("Photo", modifier = Modifier.fillMaxWidth()) {
                picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
        }

        if (text.text.trim().length >= 4) {
            Spacer(Modifier.size(8.dp))
            HPrimaryButton("Make sense of it", enabled = !working, modifier = Modifier.fillMaxWidth()) {
                parsed = SortedEngine.parse(text.text)
            }
        }
        if (working) { Spacer(Modifier.size(12.dp)); Text("Reading it…", color = Handy.palette.textSecondary) }

        val p = parsed
        if (p != null) {
            Spacer(Modifier.size(12.dp))
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(p.kind.uppercase(), style = MaterialTheme.typography.labelSmall, color = com.handytools.app.ui.HandyColors.Accent)
                        Spacer(Modifier.size(6.dp))
                        Text(p.title, style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.size(6.dp))
                        Text(p.summary, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                        if (p.amount != null) { Spacer(Modifier.size(8.dp)); Text("Amount: ${p.amount}", style = MaterialTheme.typography.bodyLarge) }
                        if (p.due != null) { Spacer(Modifier.size(4.dp)); Text("Date: ${DateFormat.getDateInstance(DateFormat.FULL).format(p.due)}", style = MaterialTheme.typography.bodyLarge) }
                    }
                }
                Spacer(Modifier.size(8.dp))
                if (p.due != null) {
                    HPrimaryButton("Add to Calendar", modifier = Modifier.fillMaxWidth()) {
                        val start = Calendar.getInstance().apply { time = p.due; set(Calendar.HOUR_OF_DAY, 9); set(Calendar.MINUTE, 0) }
                        val title = if (p.amount != null) "${p.title} — ${p.amount}" else p.title
                        val intent = Intent(Intent.ACTION_INSERT)
                            .setData(CalendarContract.Events.CONTENT_URI)
                            .putExtra(CalendarContract.Events.TITLE, title)
                            .putExtra(CalendarContract.Events.DESCRIPTION, p.summary)
                            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start.timeInMillis)
                            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, start.timeInMillis + 3600_000)
                        runCatching { ctx.startActivity(intent) }
                    }
                    Spacer(Modifier.size(8.dp))
                }
                HSecondaryButton("Copy / Share", modifier = Modifier.fillMaxWidth()) { Share.text(ctx, p.shareText()) }
                Text("A reading aid, not official advice — always check the original for the exact terms and deadline.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 10.dp))
            }
        } else {
            Spacer(Modifier.weight(1f))
        }
        BannerAd()
    }
}

data class Parsed(val kind: String, val title: String, val amount: String?, val due: Date?, val summary: String) {
    fun shareText(): String {
        val sb = StringBuilder("$kind: $title\n$summary")
        if (amount != null) sb.append("\nAmount: $amount")
        if (due != null) sb.append("\nDate: ${DateFormat.getDateInstance(DateFormat.FULL).format(due)}")
        return sb.append("\n\n(Reading aid, not advice — Tenzy)").toString()
    }
}
