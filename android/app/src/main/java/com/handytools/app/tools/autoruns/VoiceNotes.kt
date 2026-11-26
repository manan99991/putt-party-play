package com.handytools.app.tools.autoruns

import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.speech.SpeechRecognizer
import com.handytools.app.tools.power.FileTranscriber
import com.handytools.app.tools.power.VoiceText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Voice memos into written notes (the iPhone's autorun): the memos saved today in the folder the person picked are
 * listened to on the phone — only where the phone can recognise speech on its own, so nothing is sent anywhere — and
 * each is written up: what it's about, the key details (times, days, amounts) and the to-dos.
 */
object VoiceNotes {
    private const val PREFS = "autoruns"
    private const val KEY = "voice.folder"

    /** A memo file (its uri as text, so the write-up stays pure). */
    data class Memo(val id: String, val name: String, val modified: Long) { val uri: Uri get() = Uri.parse(id) }
    data class Note(val memo: Memo, val about: String, val details: List<String>, val todos: List<String>, val transcript: String) {
        /** The note as plain text, to copy or email. */
        val text: String get() = buildString {
            append(memo.name).append("\n\n").append(about)
            if (details.isNotEmpty()) append("\n\n").append(details.joinToString("\n") { "• $it" })
            if (todos.isNotEmpty()) append("\n\n").append(com.handytools.app.I18n.t("To do")).append(":\n").append(todos.joinToString("\n") { "☐ $it" })
        }
    }

    /** Whether this phone can listen to a memo on its own (Android 13+ with an on-device recogniser). */
    fun canListen(ctx: Context): Boolean = Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isRecognitionAvailable(ctx) &&
        SpeechRecognizer.isOnDeviceRecognitionAvailable(ctx)

    fun folder(ctx: Context): Uri? = ctx.getSharedPreferences(PREFS, 0).getString(KEY, null)?.let { Uri.parse(it) }
    fun setFolder(ctx: Context, tree: Uri) {
        runCatching { ctx.contentResolver.takePersistableUriPermission(tree, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        ctx.getSharedPreferences(PREFS, 0).edit().putString(KEY, tree.toString()).apply()
    }

    /** The sound files changed in [window] in the chosen folder, oldest first. */
    fun memos(ctx: Context, window: LongRange): List<Memo> {
        val tree = folder(ctx) ?: return emptyList()
        return runCatching { list(ctx, tree, window) }.getOrDefault(emptyList())
    }

    private fun list(ctx: Context, tree: Uri, window: LongRange): List<Memo> {
        val kids = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val out = ArrayList<Memo>()
        ctx.contentResolver.query(kids, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val mime = c.getString(2) ?: ""; val name = c.getString(1) ?: ""
                val sound = mime.startsWith("audio/") || name.substringAfterLast('.').lowercase() in setOf("m4a", "mp3", "wav", "aac", "ogg", "opus", "amr", "3gp", "flac")
                if (!sound || c.getLong(3) !in window) continue
                out += Memo(DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0)).toString(), name, c.getLong(3))
            }
        }
        return out.sortedBy { it.modified }
    }

    /** A transcript written up. Pure, so it's tested. */
    fun writeUp(memo: Memo, transcript: String): Note =
        Note(memo, VoiceText.summary(transcript), VoiceText.keyDetails(transcript).take(6), VoiceText.todos(transcript).take(8), transcript)

    /** Each memo listened to and written up. [progress] runs 0…1. */
    suspend fun make(ctx: Context, window: LongRange, progress: (Double) -> Unit = {}): List<Note> = withContext(Dispatchers.Default) {
        val list = memos(ctx, window)
        list.mapIndexedNotNull { i, m ->
            ensureActive()
            progress(i.toDouble() / list.size)
            val f = File(ctx.cacheDir, "memo-${System.nanoTime()}.${m.name.substringAfterLast('.', "m4a")}")
            try {
                ctx.contentResolver.openInputStream(m.uri)?.use { input -> f.outputStream().use { input.copyTo(it) } } ?: return@mapIndexedNotNull null
                val ms = com.handytools.app.tools.power.VoiceAudio.durationMs(f)
                val text = FileTranscriber.transcribe(ctx, f, ms, onDeviceOnly = true)?.takeIf { it.isNotBlank() } ?: return@mapIndexedNotNull null
                writeUp(m, text)
            } finally { f.delete(); progress((i + 1).toDouble() / list.size) }
        }
    }
}
