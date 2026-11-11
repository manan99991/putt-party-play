package com.handytools.app.tools.builder

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.tools.power.CaptureClassifier
import com.handytools.app.tools.power.MediaEngine
import com.handytools.app.tools.power.ScrubberEngine
import com.handytools.app.tools.power.VoiceText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

sealed class Payload {
    class Pic(val bmp: Bitmap) : Payload()
    class Words(val text: String) : Payload()
    class Doc(val bytes: ByteArray, val ext: String) : Payload()

    val kind: Kind get() = when (this) {
        is Pic -> Kind.IMAGE
        is Words -> Kind.TEXT
        is Doc -> if (ext in listOf("jpg", "jpeg", "png")) Kind.PHOTO_FILE else Kind.FILE
    }
}

sealed class Outcome {
    class Done(val value: Payload) : Outcome()
    class Stopped(val why: String) : Outcome()
}

object ChainRunner {
    /** Runs every step in order; a step that cannot produce anything stops the chain and names itself. */
    suspend fun run(chain: Chain, input: Payload): Outcome {
        chain.problem(input.kind)?.let { return Outcome.Stopped(it) }
        var v = input
        for (s in chain.steps) when (val r = apply(s, v)) {
            is Outcome.Done -> v = r.value
            is Outcome.Stopped -> return r
        }
        return Outcome.Done(v)
    }

    suspend fun apply(step: Step, raw: Payload): Outcome = withContext(Dispatchers.Default) {
        val b = step.block
        fun none() = Outcome.Stopped("${b.title} didn't find anything in it. Try a clearer or closer picture.")
        fun fail() = Outcome.Stopped("${b.title} couldn't finish. Try again.")

        // A photo saved as bytes by an earlier step is opened again for the next one.
        val input = if (b.takes == Kind.IMAGE && raw is Payload.Doc && raw.kind == Kind.PHOTO_FILE)
            BitmapFactory.decodeByteArray(raw.bytes, 0, raw.bytes.size)?.let { Payload.Pic(it) } ?: return@withContext fail()
        else raw

        try {
            when {
                b == Block.READ_TEXT && input is Payload.Pic -> {
                    val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    val text = try { r.process(InputImage.fromBitmap(input.bmp, 0)).await().text.trim() } finally { r.close() }
                    if (text.isEmpty()) none() else Outcome.Done(Payload.Words(text))
                }
                b == Block.PULL_RECEIPT && input is Payload.Words -> {
                    val r = CaptureClassifier.classify(input.text)
                    if (r.total.isBlank() && r.items.isEmpty()) none() else Outcome.Done(Payload.Words(CaptureClassifier.csv(r)))
                }
                b == Block.SUMMARIZE && input is Payload.Words -> {
                    val n = (step.settings["sentences"]?.toIntOrNull() ?: 3).coerceAtLeast(1)
                    val s = VoiceText.sentences(input.text).take(n)
                    if (s.isEmpty()) none() else Outcome.Done(Payload.Words(s.joinToString(" ")))
                }
                b == Block.ACTION_ITEMS && input is Payload.Words -> {
                    val items = VoiceText.sentences(input.text).filter { VoiceText.TODO.containsMatchIn(it) }
                    if (items.isEmpty()) none() else Outcome.Done(Payload.Words(items.joinToString("\n") { "• $it" }))
                }
                b == Block.SHRINK && input is Payload.Pic -> {
                    val mb = step.settings["mb"]?.toDoubleOrNull() ?: 2.0
                    val e = MediaEngine.shrinkToBytes(input.bmp, (mb.coerceAtLeast(0.05) * 1_048_576).toLong())
                    Outcome.Done(Payload.Doc(e.bytes, "jpg"))
                }
                b == Block.STRIP_LOCATION && input is Payload.Pic -> Outcome.Done(Payload.Doc(MediaEngine.jpeg(input.bmp, 92), "jpg"))
                b == Block.CONVERT && input is Payload.Pic ->
                    if (step.settings["format"].equals("PNG", true)) Outcome.Done(Payload.Doc(MediaEngine.png(input.bmp), "png"))
                    else Outcome.Done(Payload.Doc(MediaEngine.jpeg(input.bmp, 90), "jpg"))
                b == Block.HIDE_SENSITIVE && input is Payload.Pic -> {
                    val rects = ArrayList<Rect>(ScrubberEngine.detectFaces(input.bmp))
                    rects.addAll(personalText(input.bmp))
                    val out = if (rects.isEmpty()) input.bmp else ScrubberEngine.scrub(input.bmp, rects, ScrubberEngine.HideStyle.PIXELATE)
                    Outcome.Done(Payload.Doc(MediaEngine.jpeg(out, 92), "jpg"))
                }
                b == Block.BUSINESS_CARD && input is Payload.Words -> {
                    val c = CaptureClassifier.classify(input.text)
                    if (c.name.isBlank() && c.phone.isBlank() && c.email.isBlank()) none()
                    else Outcome.Done(Payload.Doc(vcard(c.name, c.title, c.company, c.phone, c.email).toByteArray(), "vcf"))
                }
                b == Block.CALENDAR_EVENT && input is Payload.Words -> {
                    val c = CaptureClassifier.classify(input.text)
                    val start = c.startMs
                    if (start == null) none()
                    else Outcome.Done(Payload.Doc(ics(c.event.ifBlank { "Event" }, start, c.endMs, c.venue).toByteArray(), "ics"))
                }
                else -> Outcome.Stopped("${b.title} can't use that input.")
            }
        } catch (_: Exception) { fail() }
    }

    /** Only text that looks personal (long digit runs, emails) is covered, so the rest of the photo stays readable. */
    private suspend fun personalText(bmp: Bitmap): List<Rect> {
        val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            r.process(InputImage.fromBitmap(bmp, 0)).await().textBlocks
                .filter { it.text.count { c -> c.isDigit() } >= 6 || it.text.contains('@') }
                .mapNotNull { it.boundingBox }
        } catch (_: Exception) { emptyList() } finally { r.close() }
    }

    private fun vcard(name: String, title: String, company: String, phone: String, email: String) = buildString {
        append("BEGIN:VCARD\nVERSION:3.0\n")
        append("FN:").append(name.ifBlank { email.ifBlank { phone } }).append('\n')
        if (company.isNotBlank()) append("ORG:").append(company).append('\n')
        if (title.isNotBlank()) append("TITLE:").append(title).append('\n')
        if (phone.isNotBlank()) append("TEL:").append(phone).append('\n')
        if (email.isNotBlank()) append("EMAIL:").append(email).append('\n')
        append("END:VCARD\n")
    }

    private fun ics(title: String, start: Long, end: Long?, where: String): String {
        val f = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        return buildString {
            append("BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Tenzy//EN\nBEGIN:VEVENT\n")
            append("UID:").append(start).append("@tenzy\n")
            append("DTSTAMP:").append(f.format(Date())).append('\n')
            append("DTSTART:").append(f.format(Date(start))).append('\n')
            append("DTEND:").append(f.format(Date(end ?: (start + 3_600_000L)))).append('\n')
            append("SUMMARY:").append(title).append('\n')
            if (where.isNotBlank()) append("LOCATION:").append(where).append('\n')
            append("END:VEVENT\nEND:VCALENDAR\n")
        }
    }
}
