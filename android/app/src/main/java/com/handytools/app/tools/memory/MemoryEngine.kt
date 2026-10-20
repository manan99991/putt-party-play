package com.handytools.app.tools.memory

import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class MemEntry(val id: Long, val date: Long, val text: String)

/** Reads the text in the phone's screenshots once (Vision OCR), caches it, and finds things by plain
 *  words. All on-device — nothing is uploaded. A one-line AI answer needs Gemini Nano; everywhere
 *  else it returns the best-matching screenshot and line. */
object MemoryEngine {
    private const val PREF = "memory_index"
    private const val KEY = "entries"

    fun loadCache(ctx: Context): List<MemEntry> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                MemEntry(o.getLong("id"), o.getLong("date"), o.getString("text"))
            }
        }.getOrDefault(emptyList())
    }

    fun saveCache(ctx: Context, entries: List<MemEntry>) {
        val arr = JSONArray()
        for (e in entries) arr.put(JSONObject().put("id", e.id).put("date", e.date).put("text", e.text))
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    suspend fun index(ctx: Context, limit: Int = 400, onProgress: (Float) -> Unit): List<MemEntry> = withContext(Dispatchers.IO) {
        val cache = loadCache(ctx).associateBy { it.id }
        val shots = screenshots(ctx, limit)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val out = ArrayList<MemEntry>()
        val total = shots.size.coerceAtLeast(1)
        shots.forEachIndexed { i, pair ->
            val id = pair.first
            val date = pair.second
            val hit = cache[id]
            if (hit != null && hit.date == date) {
                out.add(hit)
            } else {
                val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
                val text = runCatching {
                    val img = InputImage.fromFilePath(ctx, uri)
                    recognizer.process(img).await().text
                }.getOrDefault("")
                out.add(MemEntry(id, date, text))
            }
            onProgress((i + 1).toFloat() / total)
        }
        out.sortByDescending { it.date }
        saveCache(ctx, out)
        out
    }

    private fun screenshots(ctx: Context, limit: Int): List<Pair<Long, Long>> {
        val proj = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DATE_ADDED)
        val sel = "${MediaStore.Images.Media.BUCKET_DISPLAY_NAME} = ?"
        val args = arrayOf("Screenshots")
        val sort = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        val out = ArrayList<Pair<Long, Long>>()
        ctx.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, proj, sel, args, sort)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            while (c.moveToNext() && out.size < limit) out.add(Pair(c.getLong(idCol), c.getLong(dateCol)))
        }
        return out
    }

    private val stop = setOf("the", "a", "an", "my", "me", "i", "is", "was", "of", "to", "in", "on", "for", "what", "whats", "where", "show", "find", "that", "this", "it", "and", "do", "did", "have", "had", "saved", "photo", "photos", "screenshot", "screenshots", "picture")
    fun tokens(s: String) = s.lowercase().split(Regex("[^a-z0-9]+")).filter { it.length > 1 && it !in stop }

    fun search(query: String, entries: List<MemEntry>, top: Int = 6): List<MemEntry> {
        val terms = tokens(query)
        if (terms.isEmpty()) return emptyList()
        val now = System.currentTimeMillis() / 1000
        return entries.mapNotNull { e ->
            val hay = e.text.lowercase()
            var score = 0.0
            for (t in terms) if (hay.contains(t)) score += 1 + t.length / 12.0
            if (score <= 0) null else {
                val ageDays = (now - e.date) / 86400.0
                score += (1.5 - ageDays / 120).coerceAtLeast(0.0)
                Pair(e, score)
            }
        }.sortedByDescending { it.second }.take(top).map { it.first }
    }

    fun bestLine(query: String, entry: MemEntry): String {
        val terms = tokens(query)
        val lines = entry.text.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        return lines.maxByOrNull { l -> terms.count { l.lowercase().contains(it) } } ?: (lines.firstOrNull() ?: "")
    }
}
