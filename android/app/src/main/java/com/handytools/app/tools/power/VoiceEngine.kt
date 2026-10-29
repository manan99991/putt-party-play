package com.handytools.app.tools.power

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** One saved voice note. Audio lives in filesDir/voice_notes, the index is a JSON file next to it. */
data class VoiceNote(
    val id: String,
    val title: String,
    val path: String,
    val durationMs: Long,
    val createdAt: Long,
    val transcript: String,
) {
    val file: File get() = File(path)
}

/** Persisted note library — plain JSON in filesDir, nothing leaves the phone. */
object VoiceNotes {
    private fun dir(ctx: Context): File = File(ctx.filesDir, "voice_notes").apply { mkdirs() }
    private fun index(ctx: Context): File = File(dir(ctx), "index.json")

    fun load(ctx: Context): List<VoiceNote> {
        val f = index(ctx)
        if (!f.exists()) return emptyList()
        return try {
            val arr = JSONArray(f.readText())
            val out = ArrayList<VoiceNote>()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val n = VoiceNote(
                    id = o.getString("id"), title = o.optString("title", "Voice note"), path = o.getString("path"),
                    durationMs = o.optLong("durationMs", 0L), createdAt = o.optLong("createdAt", 0L),
                    transcript = o.optString("transcript", "")
                )
                if (File(n.path).exists()) out.add(n)
            }
            out.sortedByDescending { it.createdAt }
        } catch (e: Exception) { emptyList() }
    }

    private fun save(ctx: Context, notes: List<VoiceNote>) {
        val arr = JSONArray()
        notes.forEach { n ->
            arr.put(JSONObject().put("id", n.id).put("title", n.title).put("path", n.path)
                .put("durationMs", n.durationMs).put("createdAt", n.createdAt).put("transcript", n.transcript))
        }
        try { index(ctx).writeText(arr.toString()) } catch (_: Exception) {}
    }

    /** Copies [source] into the library and records it. Returns the new note. */
    fun add(ctx: Context, source: File, transcript: String, durationMs: Long, titleHint: String? = null): VoiceNote {
        val id = System.currentTimeMillis().toString()
        val ext = source.extension.ifEmpty { "m4a" }
        val dest = File(dir(ctx), "note_$id.$ext")
        if (!source.renameTo(dest)) source.copyTo(dest, overwrite = true)
        val note = VoiceNote(id, titleHint ?: titleFrom(transcript, "Voice note"), dest.absolutePath, durationMs, System.currentTimeMillis(), transcript)
        save(ctx, listOf(note) + load(ctx))
        return note
    }

    fun delete(ctx: Context, note: VoiceNote) {
        try { File(note.path).delete() } catch (_: Exception) {}
        save(ctx, load(ctx).filter { it.id != note.id })
    }

    /** First words of the transcript, like the prototype's 40-char title. */
    fun titleFrom(transcript: String, fallback: String): String {
        val t = transcript.trim().replace(Regex("\\s+"), " ")
        if (t.isEmpty()) return fallback
        return if (t.length > 40) t.substring(0, 40).trimEnd() + "…" else t
    }

    fun fmt(ms: Long): String { val s = (ms / 1000).coerceAtLeast(0); return "%d:%02d".format(s / 60, s % 60) }

    fun dateLabel(ts: Long): String {
        val diff = System.currentTimeMillis() - ts
        return when {
            diff < 60_000L -> "just now"
            diff < 3_600_000L -> "${diff / 60_000L} min ago"
            diff < 86_400_000L -> "${diff / 3_600_000L} h ago"
            else -> SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(ts))
        }
    }
}

/** Transcript analysis: sentences, 2-line summary, key numbers/dates, action items. Pure text, no model. */
object VoiceText {
    val TODO = Regex("\\b(remember|need to|book|send|call|follow up|schedule|buy|finish|email)\\b", RegexOption.IGNORE_CASE)
    private val DETAIL = Regex(
        "(\\$\\s?\\d[\\d,.]*|\\b\\d[\\d,.]*\\s?(?:am|pm|%|percent|dollars|euros|k)(?!\\w)|" +
            "\\b\\d{1,2}(?::\\d{2})?\\s?(?:am|pm)\\b|\\b\\d+(?:st|nd|rd|th)\\b|" +
            "\\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|tonight|today|next week|next month|this week|this weekend|end of (?:the )?(?:day|week|month))\\b|" +
            "\\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\.?\\s+\\d{1,2}\\b|" +
            "\\b\\d{1,2}\\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\b|\\b\\d[\\d,.]*\\b)",
        RegexOption.IGNORE_CASE
    )

    /** Splits on sentence punctuation; unpunctuated dictation is also cut where a new action starts. */
    fun sentences(text: String): List<String> {
        val raw = text.trim().split(Regex("(?<=[.!?])\\s+")).map { it.trim() }.filter { it.isNotEmpty() }
        val out = ArrayList<String>()
        for (s in raw) {
            val words = s.split(Regex("\\s+"))
            if (words.size <= 18) { out.add(s); continue }
            var start = 0
            var i = 0
            while (i < words.size) {
                val one = words[i]
                val two = if (i + 1 < words.size) one + " " + words[i + 1] else one
                val hit = TODO.containsMatchIn(one) || TODO.containsMatchIn(two)
                if (hit && i - start >= 4) { out.add(words.subList(start, i).joinToString(" ")); start = i }
                i++
            }
            out.add(words.subList(start, words.size).joinToString(" "))
        }
        return out
    }

    fun summary(text: String): String = sentences(text).take(2).joinToString(" ")

    fun keyDetails(text: String): List<String> {
        val seen = LinkedHashSet<String>()
        for (m in DETAIL.findAll(text)) {
            val v = m.value.trim()
            if (v.length == 1 && v.all { it.isDigit() }) continue // lone digits are rarely useful
            seen.add(v.replaceFirstChar { it.uppercase() })
            if (seen.size >= 8) break
        }
        return seen.toList()
    }

    fun todos(text: String): List<String> = sentences(text).filter { TODO.containsMatchIn(it) }
}

/** Audio helpers: duration, lossless trim (MediaExtractor → MediaMuxer, from Audio Cutter), recorder setup. */
object VoiceAudio {
    fun durationMs(ctx: Context, uri: Uri): Long {
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(ctx, uri)
            mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        } catch (e: Exception) { 0L } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }

    fun durationMs(file: File): Long {
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(file.absolutePath)
            mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        } catch (e: Exception) { 0L } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }

    /** AAC in an .m4a container, mono, voice-friendly bitrate (~0.7 MB/min). */
    fun newRecorder(ctx: Context, out: File): MediaRecorder {
        @Suppress("DEPRECATION")
        val r: MediaRecorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else MediaRecorder()
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioChannels(1)
        r.setAudioSamplingRate(44100)
        r.setAudioEncodingBitRate(96000)
        r.setOutputFile(out.absolutePath)
        return r
    }

    /** Copies the audio samples between startMs and endMs into [out] (.m4a) without re-encoding. */
    fun trim(ctx: Context, uri: Uri, startMs: Long, endMs: Long, out: File) {
        val startUs = startMs * 1000
        val endUs = endMs * 1000
        val extractor = MediaExtractor()
        extractor.setDataSource(ctx, uri, null)
        var audioTrack = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { audioTrack = i; format = f; break }
        }
        if (audioTrack < 0 || format == null) { extractor.release(); throw IllegalStateException("no audio track") }
        extractor.selectTrack(audioTrack)

        val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val outTrack = muxer.addTrack(format)
        muxer.start()

        val buffer = ByteBuffer.allocate(256 * 1024)
        val info = MediaCodec.BufferInfo()
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        try {
            while (true) {
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                val ptUs = extractor.sampleTime
                if (ptUs > endUs) break
                if (ptUs >= startUs) {
                    info.offset = 0
                    info.size = size
                    info.presentationTimeUs = ptUs - startUs
                    info.flags = extractor.sampleFlags
                    muxer.writeSampleData(outTrack, buffer, info)
                }
                if (!extractor.advance()) break
            }
        } finally {
            try { muxer.stop() } catch (_: Exception) {}
            muxer.release()
            extractor.release()
        }
    }

    /** Shrinks a long amplitude history to [bars] values (max per bucket) for the static waveform. */
    fun downsample(src: List<Float>, bars: Int): List<Float> {
        if (src.isEmpty()) return List(bars) { 0f }
        if (src.size <= bars) return src + List(bars - src.size) { 0f }
        val out = ArrayList<Float>(bars)
        for (b in 0 until bars) {
            val from = b * src.size / bars
            val to = ((b + 1) * src.size / bars).coerceAtLeast(from + 1).coerceAtMost(src.size)
            var m = 0f
            for (i in from until to) if (src[i] > m) m = src[i]
            out.add(m)
        }
        return out
    }
}
