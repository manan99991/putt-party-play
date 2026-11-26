package com.handytools.app

import android.content.Context
import java.util.Locale

/**
 * App-wide localization, twin of the iOS `Localizer`. Every user-facing string is written in English in the
 * code and looked up here by its English text, so a translation is pure data in assets/translations.json
 * (English → { lang: translation }) and adding a language or a string never touches a call site. The device
 * language is read from the default Locale, so the app follows the phone. Anything missing — no entry, a
 * language we don't ship, a malformed file — falls back to the English text, so the UI is never blank.
 * Loaded once in HandyApp.onCreate(); usage: `Text(I18n.t("Add to Reminders"))`, `Text(I18n.t(tool.name))`.
 */
object I18n {
    private var lang: String = "en"
    private var table: Map<String, Map<String, String>> = emptyMap()

    /** Load the table and resolve the device language. Safe to call before any UI; failures leave English. */
    fun load(ctx: Context) {
        lang = Locale.getDefault().language.lowercase()
        if (lang == "en") return
        runCatching {
            val json = ctx.assets.open("translations.json").bufferedReader(Charsets.UTF_8).use { it.readText() }
            val root = org.json.JSONObject(json)
            val out = HashMap<String, Map<String, String>>()
            val keys = root.keys()
            while (keys.hasNext()) {
                val en = keys.next()
                val o = root.getJSONObject(en)
                val inner = HashMap<String, String>()
                val lk = o.keys()
                while (lk.hasNext()) { val l = lk.next(); inner[l] = o.getString(l) }
                out[en] = inner
            }
            table = out
        }
    }

    fun t(english: String): String {
        if (lang == "en") return english
        return table[english]?.get(lang) ?: english
    }

    /** A translated phrase with its %@ / %d filled in order, written the way the iPhone app writes them ("%%" is a %). */
    fun f(english: String, vararg args: Any): String {
        var s = t(english)
        for (a in args) { val m = Regex("%[@d]").find(s) ?: break; s = s.replaceRange(m.range, a.toString()) }
        return s.replace("%%", "%")
    }
}
