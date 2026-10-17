package com.handytools.app.tools.shortcut

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.Icon
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

data class PagePreview(val url: String, val title: String, val icon: Bitmap?)

object WebShortcut {

    /** Pulls <title>, og:site_name and the best icon it can find. Falls back to the domain. */
    suspend fun preview(rawUrl: String): PagePreview = withContext(Dispatchers.IO) {
        val url = if (rawUrl.startsWith("http")) rawUrl else "https://$rawUrl"
        val html = runCatching { fetch(url, 200_000) }.getOrNull()?.let { String(it) } ?: ""
        val host = runCatching { URL(url).host.removePrefix("www.") }.getOrDefault(url)

        val siteName = Regex("""<meta[^>]+property=["']og:site_name["'][^>]+content=["']([^"']+)""", RegexOption.IGNORE_CASE).find(html)?.groupValues?.get(1)
        val ogTitle = Regex("""<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)""", RegexOption.IGNORE_CASE).find(html)?.groupValues?.get(1)
        val title = Regex("<title[^>]*>([^<]{1,120})</title>", RegexOption.IGNORE_CASE).find(html)?.groupValues?.get(1)
        val name = (siteName ?: ogTitle ?: title)?.let { decode(it) }?.split(" | ", " – ", " - ", " — ")?.first()?.trim()
            ?.takeIf { it.isNotBlank() } ?: host.substringBefore('.').replaceFirstChar { it.uppercase() }

        val iconHref = Regex("""<link[^>]+rel=["'](?:apple-touch-icon(?:-precomposed)?|icon|shortcut icon)["'][^>]+href=["']([^"']+)""", RegexOption.IGNORE_CASE)
            .findAll(html).map { it.groupValues[1] }.sortedByDescending { it.contains("apple-touch") }.firstOrNull()
        val iconUrl = iconHref?.let { runCatching { URL(URL(url), it).toString() }.getOrNull() } ?: "https://$host/favicon.ico"
        val icon = runCatching { fetch(iconUrl, 2_000_000) }.getOrNull()?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
            ?: runCatching { fetch("https://www.google.com/s2/favicons?sz=128&domain=$host", 500_000) }.getOrNull()?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }

        PagePreview(url, name.take(30), icon)
    }

    fun pin(ctx: Context, p: PagePreview): Boolean {
        val sm = ctx.getSystemService(ShortcutManager::class.java)
        if (!sm.isRequestPinShortcutSupported) return false
        val bmp = p.icon?.let { pad(it) } ?: letterIcon(p.title)
        val info = ShortcutInfo.Builder(ctx, "web_" + p.url.hashCode())
            .setShortLabel(p.title)
            .setLongLabel(p.title)
            .setIcon(Icon.createWithAdaptiveBitmap(bmp))
            .setIntent(Intent(Intent.ACTION_VIEW, Uri.parse(p.url)))
            .build()
        return sm.requestPinShortcut(info, null)
    }

    private fun fetch(url: String, max: Int): ByteArray {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 6000; readTimeout = 6000; instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Mozilla/5.0 (Android) Oddbox")
        }
        return c.inputStream.use { it.readNBytes(max) }
    }

    private fun decode(s: String) = s.replace("&amp;", "&").replace("&#39;", "'").replace("&quot;", "\"").replace("&nbsp;", " ")

    /** Adaptive icons want the content inside the inner 2/3 safe zone. */
    private fun pad(src: Bitmap): Bitmap {
        val size = 192
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(out); c.drawColor(Color.WHITE)
        val inner = size * 2 / 3
        val scaled = Bitmap.createScaledBitmap(src, inner, inner, true)
        c.drawBitmap(scaled, (size - inner) / 2f, (size - inner) / 2f, null)
        return out
    }

    private fun letterIcon(title: String): Bitmap {
        val size = 192
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(out); c.drawColor(com.handytools.app.ui.HandyColors.AccentArgb)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 96f; textAlign = Paint.Align.CENTER }
        c.drawText(title.take(1).uppercase(), size / 2f, size / 2f + 34f, p)
        return out
    }
}
