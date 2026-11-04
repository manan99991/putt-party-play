package com.handytools.app.tools.power

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.annotation.RequiresApi
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.coroutines.resume

/**
 * Transcribes an already-recorded audio file, OFF the microphone — so it works even on devices
 * (e.g. Samsung) where a live SpeechRecognizer can't share the mic with the recorder. Decodes the
 * file to PCM, then feeds it to the on-device recognizer via RecognizerIntent.EXTRA_AUDIO_SOURCE
 * (Android 13+). Returns the transcript, or null when the device can't do it (caller keeps its note).
 *
 * Purely additive: it never touches recording/playback/trim, so a null result is no worse than
 * before. Also powers transcription of imported audio files.
 */
object FileTranscriber {

    /** True when this device can transcribe a file (needs Android 13+ and an available recognizer). */
    fun isSupported(ctx: Context): Boolean =
        Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isRecognitionAvailable(ctx)

    /** Decodes [file] + runs recognition. Null if unsupported or nothing decoded/recognised. */
    suspend fun transcribe(ctx: Context, file: File, durationMs: Long): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !SpeechRecognizer.isRecognitionAvailable(ctx)) return null
        val pcm = try { withContext(Dispatchers.IO) { decodeToPcm(file) } } catch (_: Exception) { null } ?: return null
        try {
            // Give the recogniser headroom: at least 20s, up to ~2.5x the clip, capped at 3 min.
            val budget = (durationMs * 5 / 2).coerceIn(20_000L, 180_000L)
            return withTimeoutOrNull(budget) { recognise(ctx, pcm.file, pcm.sampleRate) }
        } finally {
            try { pcm.file.delete() } catch (_: Exception) {}
        }
    }

    private data class Pcm(val file: File, val sampleRate: Int)

    /** Decodes any supported audio file to signed 16-bit little-endian mono PCM in a temp file. */
    private fun decodeToPcm(src: File): Pcm? {
        val extractor = MediaExtractor()
        extractor.setDataSource(src.absolutePath)
        var track = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { track = i; format = f; break }
        }
        if (track < 0 || format == null) { extractor.release(); return null }
        extractor.selectTrack(track)

        val mime = format.getString(MediaFormat.KEY_MIME)!!
        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 1

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val out = File.createTempFile("asr_pcm_", ".raw", src.parentFile)
        val sink = out.outputStream().buffered()
        val info = MediaCodec.BufferInfo()
        var sawInputEnd = false
        var sawOutputEnd = false
        try {
            while (!sawOutputEnd) {
                if (!sawInputEnd) {
                    val inIx = codec.dequeueInputBuffer(10_000)
                    if (inIx >= 0) {
                        val buf = codec.getInputBuffer(inIx)!!
                        val size = extractor.readSampleData(buf, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(inIx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            sawInputEnd = true
                        } else {
                            codec.queueInputBuffer(inIx, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                var outIx = codec.dequeueOutputBuffer(info, 10_000)
                while (outIx >= 0) {
                    if (info.size > 0) {
                        val buf = codec.getOutputBuffer(outIx)!!
                        buf.position(info.offset); buf.limit(info.offset + info.size)
                        writeMonoPcm16(buf, channels, sink)
                    }
                    codec.releaseOutputBuffer(outIx, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) { sawOutputEnd = true; break }
                    outIx = codec.dequeueOutputBuffer(info, 0)
                }
            }
        } finally {
            sink.flush(); sink.close()
            try { codec.stop() } catch (_: Exception) {}
            try { codec.release() } catch (_: Exception) {}
            extractor.release()
        }
        return if (out.length() > 0) Pcm(out, sampleRate) else { out.delete(); null }
    }

    /** Writes a decoder output buffer as mono 16-bit PCM, averaging channels when the source isn't mono. */
    private fun writeMonoPcm16(buf: ByteBuffer, channels: Int, sink: java.io.OutputStream) {
        val sb = buf.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val n = sb.remaining()
        val two = ByteArray(2)
        if (channels <= 1) {
            var i = 0
            while (i < n) { val s = sb.get(); two[0] = (s.toInt() and 0xFF).toByte(); two[1] = ((s.toInt() shr 8) and 0xFF).toByte(); sink.write(two); i++ }
        } else {
            var i = 0
            while (i + channels <= n) {
                var sum = 0
                for (c in 0 until channels) sum += sb.get().toInt()
                val s = (sum / channels)
                two[0] = (s and 0xFF).toByte(); two[1] = ((s shr 8) and 0xFF).toByte(); sink.write(two)
                i += channels
            }
        }
    }

    /** Runs the on-device recogniser against a PCM file, accumulating every segment it returns. */
    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private suspend fun recognise(ctx: Context, pcm: File, sampleRate: Int): String? =
        suspendCancellableCoroutine { cont ->
            val main = Handler(Looper.getMainLooper())
            main.post {
                val recognizer = try {
                    if (SpeechRecognizer.isOnDeviceRecognitionAvailable(ctx))
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx)
                    else SpeechRecognizer.createSpeechRecognizer(ctx)
                } catch (_: Exception) { if (cont.isActive) cont.resume(null); return@post }

                val pfd = try { ParcelFileDescriptor.open(pcm, ParcelFileDescriptor.MODE_READ_ONLY) } catch (_: Exception) {
                    try { recognizer.destroy() } catch (_: Exception) {}
                    if (cont.isActive) cont.resume(null); return@post
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.packageName)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pfd)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    // End the session when the file is fully read, and surface each utterance.
                    putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                }

                val acc = StringBuilder()
                var done = false
                fun finish() {
                    if (done) return
                    done = true
                    try { recognizer.destroy() } catch (_: Exception) {}
                    try { pfd.close() } catch (_: Exception) {}
                    if (cont.isActive) cont.resume(acc.toString().trim().ifEmpty { null })
                }
                fun add(b: Bundle?) {
                    b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let {
                        if (it.isNotBlank()) { if (acc.isNotEmpty()) acc.append(' '); acc.append(it.trim()) }
                    }
                }

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(p: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(r: Float) {}
                    override fun onBufferReceived(b: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onPartialResults(p: Bundle?) {}
                    override fun onEvent(t: Int, p: Bundle?) {}
                    override fun onResults(b: Bundle?) { add(b) }               // non-segmented fallback
                    override fun onSegmentResults(b: Bundle) { add(b) }          // one utterance of the file
                    override fun onEndOfSegmentedSession() { finish() }          // whole file consumed
                    override fun onError(code: Int) {
                        // ERROR_NO_MATCH / ERROR_SPEECH_TIMEOUT at EOF just means "that's all" — keep what we have.
                        finish()
                    }
                })
                cont.invokeOnCancellation { main.post { try { recognizer.cancel(); recognizer.destroy() } catch (_: Exception) {}; try { pfd.close() } catch (_: Exception) {} } }
                try { recognizer.startListening(intent) } catch (_: Exception) { finish() }
            }
        }
}
