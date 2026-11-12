package com.handytools.app.tools.builder

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.StaticLayout
import android.text.TextPaint
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.HandyApp
import com.handytools.app.tools.power.DocEngine
import com.handytools.app.tools.power.FileTranscriber
import com.handytools.app.tools.power.MediaEngine
import com.handytools.app.tools.power.TranslateEngine
import com.handytools.app.tools.power.VoiceAudio
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume

/**
 * The newer steps of Build your own: recordings, PDFs, web pages, codes, translating, reading aloud and more video.
 *
 * Every one of them checks what this phone can do first. A phone that can't run a step gets a plain sentence saying
 * so; the step is greyed out in the builder and every other step keeps working.
 */
object ExtraSteps {
    /** What "Read the page at a link" shows while a tool is being built, so no page is fetched for a preview. */
    const val SAMPLE_PAGE = "Example article\nThe words of the page appear here, without its menus, ads or buttons."

    /** Steps the builder can't try on a sample (they need a voice, a translator or a download), so it says what each does instead. */
    val NO_PREVIEW = setOf(Block.TRANSLATE, Block.REWRITE, Block.READ_ALOUD, Block.STICKER, Block.EMOJI_FACES)

    @Volatile private var speechKnown: Boolean? = null
    private fun speech(ctx: Context): Boolean =
        speechKnown ?: runCatching { SpeechRecognizer.isRecognitionAvailable(ctx) }.getOrDefault(false).also { speechKnown = it }

    /** Null when this phone can run the step; otherwise one plain sentence saying why not. */
    fun unavailable(ctx: Context, b: Block): String? = TextTidy.unavailable(b, Build.VERSION.SDK_INT, speech(ctx))

    /** The first step of [chain] this phone can't run, as a sentence; null when the whole tool works here. */
    fun unavailable(ctx: Context, chain: Chain): String? =
        chain.steps.firstNotNullOfOrNull { s -> unavailable(ctx, s.block)?.let { "${s.block.title} isn't available on this phone. $it" } }

    @Volatile private var pdfboxReady = false
    private fun pdfbox(ctx: Context) { if (!pdfboxReady) { PDFBoxResourceLoader.init(ctx.applicationContext); pdfboxReady = true } }

    private fun temp(ctx: Context, bytes: ByteArray, ext: String): File =
        File(File(ctx.cacheDir, "extra-steps").also { it.mkdirs() }, "in-${System.nanoTime()}.${ext.lowercase().ifEmpty { "bin" }}").also { it.writeBytes(bytes) }

    private fun cantOpen(b: Block) = "${b.title} couldn't open that PDF. It may be damaged or locked with a password."

    /** Null when [step] is not one of these steps (the runner then reports the wrong input). */
    suspend fun apply(step: Step, input: Payload, dryRun: Boolean): Outcome? {
        val b = step.block
        val ctx: Context = HandyApp.instance
        fun stop(why: String): Outcome = Outcome.Stopped(why)
        fun fail(): Outcome = Outcome.Stopped("${b.title} couldn't finish. Try again.")
        fun clip(f: File): Outcome = Outcome.Done(Payload.Clip(Uri.fromFile(f)))

        return try {
            when {
                b == Block.READ_CODE && input is Payload.Pic -> {
                    val codes = BarcodeScanning.getClient().process(InputImage.fromBitmap(input.bmp, 0)).await()
                    // A QR code wins when the picture holds both.
                    val hit = codes.firstOrNull { it.format == Barcode.FORMAT_QR_CODE && !it.rawValue.isNullOrEmpty() } ?: codes.firstOrNull { !it.rawValue.isNullOrEmpty() }
                    hit?.rawValue?.let { Outcome.Done(Payload.Words(it)) } ?: stop("Read a QR or barcode didn't find a code in it. Fill the frame with the code and try again.")
                }

                b == Block.PAGE_TEXT && input is Payload.Words -> {
                    val link = TextTidy.pageLink(input.text)
                    when {
                        link == null -> stop("Read the page at a link needs a web link, and didn't find one in that text.")
                        dryRun -> Outcome.Done(Payload.Words(SAMPLE_PAGE))
                        else -> {
                            val html = withContext(Dispatchers.IO) { fetch(link) }
                            val words = html?.let { TextTidy.article(it) }
                            when {
                                words == null -> stop("Read the page at a link couldn't open ${runCatching { URL(link).host }.getOrDefault("that link")}. Check the connection and try again.")
                                words.isEmpty() -> stop("Read the page at a link opened the page but found no words to read on it.")
                                else -> Outcome.Done(Payload.Words(words))
                            }
                        }
                    }
                }

                b == Block.TEXT_PDF && input is Payload.Words ->
                    if (input.text.isBlank()) stop("Text to PDF didn't find anything in that text.") else Outcome.Done(Payload.Doc(textPdf(input.text.trim()), "pdf"))

                b == Block.PDF_SHRINK && input is Payload.Doc -> {
                    val src = temp(ctx, input.bytes, "pdf")
                    try {
                        when {
                            pageCount(src) <= 0 -> stop(cantOpen(b))
                            input.bytes.size <= TextTidy.pdfLimit(step.settings["mb"]) * 1_048_576L -> Outcome.Done(input)     // already fits
                            else -> {
                                val small = withContext(Dispatchers.IO) { DocEngine.compress(ctx, Uri.fromFile(src)) }
                                val bytes = small?.takeIf { it.length() in 1 until input.bytes.size.toLong() }?.readBytes()
                                small?.delete()
                                Outcome.Done(Payload.Doc(bytes ?: input.bytes, "pdf"))      // never bigger than it came in
                            }
                        }
                    } finally { src.delete() }
                }

                b == Block.PDF_LOCK && input is Payload.Doc -> {
                    val password = step.settings["password"].orEmpty().trim()
                    if (password.isEmpty()) stop("Lock with a password needs a password. Edit the tool and type one in.")
                    else withContext(Dispatchers.IO) {
                        pdfbox(ctx)
                        val doc = try { PDDocument.load(input.bytes) } catch (_: Throwable) { null }
                        if (doc == null) stop(cantOpen(b)) else doc.use { d ->
                            val policy = StandardProtectionPolicy(password, password, AccessPermission())
                            policy.encryptionKeyLength = 128
                            d.protect(policy)
                            Outcome.Done(Payload.Doc(ByteArrayOutputStream().also { d.save(it) }.toByteArray(), "pdf"))
                        }
                    }
                }

                b == Block.PDF_PAGES && input is Payload.Doc -> withContext(Dispatchers.IO) {
                    pdfbox(ctx)
                    val doc = try { PDDocument.load(input.bytes) } catch (_: Throwable) { null }
                    if (doc == null || doc.numberOfPages == 0) { runCatching { doc?.close() }; stop(cantOpen(b)) } else doc.use { d ->
                        PDDocument().use { out ->
                            TextTidy.pageList(step.settings["pages"].orEmpty(), d.numberOfPages).forEach { out.importPage(d.getPage(it)) }
                            Outcome.Done(Payload.Doc(ByteArrayOutputStream().also { out.save(it) }.toByteArray(), "pdf"))
                        }
                    }
                }

                b == Block.PDF_TEXT && input is Payload.Doc -> {
                    val src = temp(ctx, input.bytes, "pdf")
                    try {
                        val words = withContext(Dispatchers.IO) {
                            pdfbox(ctx)
                            try {
                                PDDocument.load(src).use { d ->
                                    val stripper = PDFTextStripper(); stripper.startPage = 1; stripper.endPage = minOf(d.numberOfPages, 150)
                                    (stripper.getText(d) ?: "").trim()
                                }
                            } catch (_: Throwable) { null }
                        }
                        when {
                            words == null -> stop(cantOpen(b))
                            words.isNotEmpty() -> Outcome.Done(Payload.Words(words))
                            else -> {
                                // A scan has no words of its own, so read its pages as pictures (the first 20).
                                val read = scanWords(ctx, src)
                                if (read.isEmpty()) stop("Read the PDF's words found no words in that PDF.") else Outcome.Done(Payload.Words(read))
                            }
                        }
                    } finally { src.delete() }
                }

                b == Block.SPEECH_TEXT && input is Payload.Doc -> {
                    val f = temp(ctx, input.bytes, input.ext.ifEmpty { "m4a" })
                    try {
                        val text = FileTranscriber.transcribe(ctx, f, VoiceAudio.durationMs(f))?.trim().orEmpty()
                        if (text.isEmpty()) stop("${b.title} couldn't make out any words. Try a clearer recording.") else Outcome.Done(Payload.Words(text))
                    } finally { f.delete() }
                }

                b == Block.READ_ALOUD && input is Payload.Words -> {
                    val words = input.text.trim().take((runCatching { TextToSpeech.getMaxSpeechInputLength() }.getOrDefault(4000) - 100).coerceAtLeast(500))
                    if (words.isEmpty()) stop("Read it aloud didn't find anything in that text.")
                    else speak(ctx, words)?.let { Outcome.Done(Payload.Doc(it, "wav")) }
                        ?: stop("Read it aloud couldn't make the audio on this phone. Check that a voice is installed in Settings, under Text-to-speech.")
                }

                b == Block.TRANSLATE && input is Payload.Words -> {
                    val words = input.text.trim()
                    val to = TextTidy.languageCode(step.settings["to"])
                    val guess = runCatching { LanguageIdentification.getClient().identifyLanguage(words.take(2000)).await() }.getOrDefault("und")
                    val from = if (guess == "und") "en" else guess.substringBefore('-')
                    when {
                        words.isEmpty() -> stop("Translate didn't find anything in that text.")
                        from == to -> Outcome.Done(Payload.Words(words))       // already in that language
                        else -> try { Outcome.Done(Payload.Words(TranslateEngine.translate(from, to, words))) } catch (_: Throwable) {
                            stop("Translate couldn't finish. The first time, it downloads ${TextTidy.languageName(to)} and needs a connection. After that it works with none.")
                        }
                    }
                }

                b == Block.VIDEO_TRIM && input is Payload.Clip -> {
                    val (from, to) = TextTidy.trimWindow(step.settings["side"], step.settings["secs"], MediaEngine.videoDurationMs(ctx, input.uri))
                    if (to <= from) fail() else VideoSteps.trim(ctx, input.uri, from, to)?.let { clip(it) } ?: fail()
                }
                b == Block.VIDEO_ROTATE && input is Payload.Clip ->
                    VideoSteps.rotate(ctx, input.uri, TextTidy.turnDegrees(step.settings["turn"]))?.let { clip(it) } ?: fail()
                b == Block.VIDEO_VERTICAL && input is Payload.Clip ->
                    VideoSteps.vertical(ctx, input.uri)?.let { clip(it) } ?: fail()
                b == Block.VIDEO_GIF && input is Payload.Clip -> {
                    val made = withContext(Dispatchers.IO) { MediaEngine.videoToGif(ctx, input.uri, 480) }
                    if (made == null) fail() else {
                        val bytes = made.first.readBytes()
                        made.first.delete()
                        Outcome.Done(Payload.Doc(bytes, "gif"))
                    }
                }

                // The playful steps: stickers, emojis, meme text, boomerangs and speed.
                else -> FunSteps.apply(step, input, dryRun)
            }
        } catch (_: Throwable) { fail() }
    }

    // ------------------------------------------------------------------ helpers

    /** The page's HTML. Only the page the person asked for is fetched; nothing is sent besides the request itself. */
    private fun fetch(link: String): String? = try {
        val c = (URL(link.replaceFirst("http://", "https://")).openConnection() as HttpURLConnection)
        c.connectTimeout = 15_000; c.readTimeout = 20_000; c.instanceFollowRedirects = true
        c.setRequestProperty("User-Agent", "Mozilla/5.0 (Mobile) Tenzy")
        try {
            if (c.responseCode !in 200..299) null else {
                val buf = ByteArrayOutputStream()
                var tooBig = false
                c.inputStream.use { ins ->
                    val chunk = ByteArray(16_384)
                    while (true) {
                        val n = ins.read(chunk)
                        if (n < 0) break
                        buf.write(chunk, 0, n)
                        if (buf.size() > 6_000_000) { tooBig = true; break }
                    }
                }
                val named = c.contentType?.substringAfter("charset=", "")?.trim()?.trim('"')?.takeIf { it.isNotEmpty() }
                val cs = named?.let { runCatching { java.nio.charset.Charset.forName(it) }.getOrNull() } ?: Charsets.UTF_8
                if (tooBig) null else String(buf.toByteArray(), cs)
            }
        } finally { c.disconnect() }
    } catch (_: Throwable) { null }

    /** Plain text laid out on A4 pages with comfortable margins, as many pages as it needs (up to 300). */
    fun textPdf(text: String): ByteArray {
        val width = 595; val height = 842; val marginX = 54; val marginY = 60
        val paint = TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; textSize = 12f }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width - marginX * 2).setLineSpacing(3f, 1f).build()
        val room = height - marginY * 2
        val doc = PdfDocument()
        var line = 0; var number = 0
        while (line < layout.lineCount && number < 300) {
            val top = layout.getLineTop(line)
            var end = line
            while (end < layout.lineCount && layout.getLineBottom(end) - top <= room) end++
            if (end == line) end++                                   // one line taller than a page still gets drawn
            val page = doc.startPage(PdfDocument.PageInfo.Builder(width, height, ++number).create())
            val c = page.canvas
            c.save()
            c.translate(marginX.toFloat(), (marginY - top).toFloat())
            c.clipRect(0, top, width - marginX * 2, layout.getLineBottom(end - 1))
            layout.draw(c)
            c.restore()
            doc.finishPage(page)
            line = end
        }
        if (number == 0) doc.finishPage(doc.startPage(PdfDocument.PageInfo.Builder(width, height, 1).create()))
        val out = ByteArrayOutputStream()
        doc.writeTo(out); doc.close()
        return out.toByteArray()
    }

    private fun pageCount(pdf: File): Int = try {
        ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { fd -> PdfRenderer(fd).use { it.pageCount } }
    } catch (_: Throwable) { 0 }

    /** The words on the first pages of a scanned PDF, read from pictures of them. */
    private suspend fun scanWords(ctx: Context, pdf: File): String {
        val pages = withContext(Dispatchers.IO) { BuilderInputs.pdfPages(ctx, Uri.fromFile(pdf), 20) }
        val reader = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val parts = ArrayList<String>()
        try {
            for (p in pages) {
                val bmp = withContext(Dispatchers.IO) { p.path?.let { BitmapFactory.decodeFile(it) } } ?: continue
                val words = runCatching { reader.process(InputImage.fromBitmap(bmp, 0)).await().text.trim() }.getOrDefault("")
                bmp.recycle()
                if (words.isNotEmpty()) parts.add(words)
            }
        } finally { reader.close() }
        return parts.joinToString("\n\n")
    }

    /** The text spoken into a .wav file by the phone's own voice. Null when the phone has no voice to use. */
    private suspend fun speak(ctx: Context, text: String): ByteArray? = withContext(Dispatchers.Main) {
        withTimeoutOrNull(180_000L) {
            suspendCancellableCoroutine<ByteArray?> { cont ->
                val out = File(ctx.cacheDir, "tenzy-speech-${System.nanoTime()}.wav")
                var tts: TextToSpeech? = null
                fun done(ok: Boolean) {
                    val bytes = if (ok && out.length() > 44L) runCatching { out.readBytes() }.getOrNull() else null
                    out.delete()
                    runCatching { tts?.shutdown() }
                    if (cont.isActive) cont.resume(bytes)
                }
                tts = TextToSpeech(ctx.applicationContext) { status ->
                    val voice = tts
                    if (status != TextToSpeech.SUCCESS || voice == null) { done(false); return@TextToSpeech }
                    voice.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {}
                        override fun onDone(utteranceId: String?) { done(true) }
                        @Deprecated("Deprecated in Java") override fun onError(utteranceId: String?) { done(false) }
                        override fun onError(utteranceId: String?, errorCode: Int) { done(false) }
                    })
                    if (voice.synthesizeToFile(text, Bundle(), out, "tenzy-read-aloud") != TextToSpeech.SUCCESS) done(false)
                }
                cont.invokeOnCancellation { runCatching { tts?.shutdown() }; out.delete() }
            }
        }
    }
}
