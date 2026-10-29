package com.handytools.app.tools.power

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.provider.BlockedNumberContract
import android.telecom.TelecomManager
import com.handytools.app.tools.shield.ScamAnalyzer
import org.json.JSONArray
import org.json.JSONObject

/**
 * Safety — one result shape for every tab (message, link, phone, QR). Message analysis is the
 * existing [ScamAnalyzer]; this adds the prototype's extra signals (family-emergency script,
 * premium-rate numbers, hyphen-heavy hosts), scores bare links and phone numbers on their own,
 * and keeps the last 20 checks. Everything runs on the phone.
 */
object SafetyEngine {

    enum class Kind(val label: String) { MESSAGE("Message"), LINK("Link"), PHONE("Phone"), QR_LINK("QR link"), QR_WIFI("QR · Wi-Fi"), QR_TEXT("QR · Text") }

    data class Finding(val title: String, val why: String, val weight: Int)

    data class Check(
        val kind: Kind,
        val input: String,
        val score: Int,
        val verdict: ScamAnalyzer.Verdict,
        val findings: List<Finding>,
        val advice: List<String>,
        val phone: String?,          // a number found in the input, for Block
        val details: List<Pair<String, String>> = emptyList(), // e.g. Wi-Fi SSID / password
        val timeMs: Long = System.currentTimeMillis(),
    )

    private fun verdictFor(score: Int) = when {
        score >= 55 -> ScamAnalyzer.Verdict.LIKELY_SCAM
        score >= 30 -> ScamAnalyzer.Verdict.SUSPICIOUS
        else -> ScamAnalyzer.Verdict.LOW_RISK
    }

    private val phoneRe = Regex("""(?:\+?\d[\d\s().\-]{7,}\d)""")

    fun firstPhone(text: String): String? = phoneRe.findAll(text).map { it.value.trim() }.firstOrNull { it.count { c -> c.isDigit() } in 7..15 }

    // ---------------------------------------------------------------- message

    fun checkMessage(raw: String): Check {
        val text = raw.trim()
        val lower = text.lowercase()
        val r = ScamAnalyzer.analyze(text)
        val f = r.findings.map { Finding(it.title, it.detail, it.weight) }.toMutableList()
        fun hit(vararg p: String) = p.any { Regex(it).containsMatchIn(lower) }

        if (hit("""\bgrandma\b""", """\bgrandpa\b""", """\bit'?s me\b""", """\bnew number\b""", """\blost my phone\b""", """\bin trouble\b""", """\bbail\b""", """\bthis is my new\b""")) {
            f.add(Finding("Family emergency pattern", "\"It's me, I'm in trouble, don't call my old number\" is a classic impersonation script. Call the person on the number you already have.", 3))
        }
        if (hit("""\b(do not|don'?t) tell\b""", """\bkeep (this|it) (secret|confidential|between us)\b""", """\btell no ?one\b""") && f.none { it.title == "Tells you to keep it secret" }) {
            f.add(Finding("Tells you to keep it secret", "Isolation keeps you from the person who would say \"that is a scam\".", 4))
        }
        if (hit("""\byou('ve| have)? ?won\b""", """\bprize\b""", """\blottery\b""", """\bclaim your\b""", """\bfree gift\b""", """\bbeen selected\b""") && f.none { it.title == "Too good to be true" }) {
            f.add(Finding("Too good to be true", "Unexpected prizes are bait for fees or details.", 2))
        }
        if (hit("""\bone[\s-]?time code\b""", """\botp\b""", """\bverification code\b""", """\bread me the code\b""", """\bshare the code\b""") && f.none { it.title.contains("code, password") }) {
            f.add(Finding("Asks for a one-time code", "Codes are the keys to your account. Never share them, even with \"support\".", 4))
        }
        for (p in phoneRe.findAll(text).map { it.value.trim() }) f.addAll(phoneFindings(p, inMessage = true))
        for (l in r.links) {
            if ((l.host.count { it == '-' }) >= 2 && l.issues.none { it.contains("hyphen") }) {
                f.add(Finding("Link looks wrong: ${l.host}", "Many hyphens — typical of throwaway domains.", 2))
            }
        }
        val extra = f.size - r.findings.size
        val score = if (extra == 0) r.score else minOf(100, r.score + f.drop(r.findings.size).sumOf { it.weight * 12 })
        val verdict = verdictFor(score)
        val advice = when {
            verdict == ScamAnalyzer.Verdict.LOW_RISK || r.verdict != ScamAnalyzer.Verdict.LOW_RISK -> ScamAnalyzer.advice(r).toMutableList()
            else -> mutableListOf("Reply nothing. Do not tap links or send money or codes. Verify through an official channel.")
        }
        if (f.any { it.title == "Family emergency pattern" }) advice.add(0, "Hang up or don't reply. Call the family member on the number you already have — the real one.")
        if (f.any { it.title.startsWith("Premium-rate") }) advice.add(0, "Don't call it back. Premium numbers bill you by the minute.")
        return Check(Kind.MESSAGE, text, score, verdict, f.sortedByDescending { it.weight }, advice.distinct(), firstPhone(text))
    }

    // ---------------------------------------------------------------- link

    fun checkLink(raw: String): Check {
        val url = raw.trim()
        val f = ArrayList<Finding>()
        val checks = ScamAnalyzer.linkChecks(url)
        val host = checks.firstOrNull()?.host ?: url.removePrefix("http://").removePrefix("https://").substringBefore('/').lowercase()
        if (url.isNotBlank() && checks.isEmpty()) {
            f.add(Finding("Not a normal web address", "This doesn't look like a link a company would send. Don't open it; ask the sender what it is.", 2))
        }
        for (c in checks) {
            for (issue in c.issues) {
                val (title, w) = when {
                    issue.contains("look-alike") && issue.contains("appears") -> "Brand name inside a look-alike address" to 4
                    issue.contains("punycode") -> "Look-alike characters in the address" to 4
                    issue.contains("Not encrypted") -> "Not encrypted (http://)" to 2
                    issue.contains("shortened") -> "Shortened link hides the destination" to 2
                    issue.contains("bare IP") -> "Raw IP address instead of a name" to 3
                    issue.contains("domain ending") -> "Scam-heavy domain ending" to 3
                    issue.contains("deep sub-domain") -> "Unusually deep sub-domain" to 2
                    issue.contains("Path says") -> "Login-style page on an unknown site" to 2
                    else -> "Link looks wrong" to 2
                }
                f.add(Finding(title, issue, w))
            }
            if (c.host.count { it == '-' } >= 2) f.add(Finding("Many hyphens in the address", "Lots of hyphens are typical of throwaway domains made for one campaign.", 2))
            if (Regex("""\d{4,}""").containsMatchIn(c.host.substringBefore('.'))) f.add(Finding("Long number in the address", "Auto-generated hosts often carry a number — a company's real site wouldn't.", 1))
        }
        val score = minOf(100, f.sumOf { it.weight * 12 })
        val verdict = verdictFor(score)
        val advice = ArrayList<String>()
        if (verdict != ScamAnalyzer.Verdict.LOW_RISK) {
            advice.add("Don't open it. If it claims to be a company, type their address yourself or use their app.")
            advice.add("If you already tapped it and entered anything, change that password now and turn on two-factor.")
        } else advice.add("No tricks in the address itself. That's not a guarantee — still only sign in on sites you typed yourself.")
        return Check(Kind.LINK, url, score, verdict, f.sortedByDescending { it.weight }, advice, null, listOf("Address" to host))
    }

    // ---------------------------------------------------------------- phone

    private fun phoneFindings(raw: String, inMessage: Boolean): List<Finding> {
        val f = ArrayList<Finding>()
        val d = raw.filter { it.isDigit() }
        val shown = raw.trim()
        val usPremium = Regex("""^1?(900|976)\d{7}$""").containsMatchIn(d)
        if (usPremium) f.add(Finding("Premium-rate number $shown", "Calls to 900/976 numbers are billed at high rates. Scams use them so the call itself costs you.", 3))
        else if (Regex("""^(44|0)?(9\d|70)\d{7,8}$""").containsMatchIn(d)) f.add(Finding("Premium / personal-rate number $shown", "UK 09 and 070 numbers cost extra and are common in scams.", 2))
        if (Regex("""^1?(268|284|473|649|664|767|809|829|849|876)\d{7}$""").containsMatchIn(d)) f.add(Finding("Looks local, isn't", "Area codes like 809, 876 and 473 are Caribbean, not US. \"One-ring\" scams use them so calling back costs you international rates.", 3))
        if (!inMessage) {
            if (d.length < 7) f.add(Finding("Too short to be a real number", "Short codes can be legitimate (banks, carriers) — but a text asking for anything from one is a red flag. Check the sender with the company.", 1))
            if (d.length > 15) f.add(Finding("Too long to be a real number", "No phone number has more than 15 digits. Spoofed caller IDs often do.", 2))
            if (d.length >= 7 && d.toSet().size == 1) f.add(Finding("Spoof pattern: repeated digit", "A number that's all one digit is almost always a spoofed caller ID.", 3))
            if (d.length >= 7 && (d.contains("1234567") || d.contains("7654321") || d.contains("0000000"))) f.add(Finding("Spoof pattern: sequential digits", "Caller-ID spoofing tools default to runs like 123-4567.", 3))
            if (Regex("""^1?(\d{3})\1""").containsMatchIn(d) && d.length == 10) f.add(Finding("Spoof pattern: repeated area code", "Numbers like 312-312-xxxx are a common spoofing template.", 2))
            if (Regex("""^1?[01]\d{9}$""").containsMatchIn(d) || Regex("""^1?\d{3}[01]\d{6}$""").containsMatchIn(d)) f.add(Finding("Not a valid number", "US area codes and exchanges never start with 0 or 1 — this caller ID is made up.", 3))
            if (Regex("""^1?(800|888|877|866|855|844|833)\d{7}$""").containsMatchIn(d)) f.add(Finding("Toll-free number", "Fine for a real company, but anyone can rent one. Only trust it if you found it on the company's own site.", 1))
        }
        return f
    }

    fun checkPhone(raw: String): Check {
        val input = raw.trim()
        val f = phoneFindings(input, inMessage = false)
        val d = input.filter { it.isDigit() }
        val score = minOf(100, f.sumOf { it.weight * 12 })
        val verdict = verdictFor(score)
        val advice = ArrayList<String>()
        if (verdict == ScamAnalyzer.Verdict.LOW_RISK) advice.add("No pattern problems with the number itself. If the caller asked for money, codes or remote access, that's the tell — not the digits.")
        else advice.add("Don't call it back. If they claim to be your bank or a government office, call the number on your card or their official site instead.")
        advice.add("Your phone's own spam list is checked in the dialer — if it's already flagged there, block it.")
        return Check(Kind.PHONE, input, score, verdict, f.sortedByDescending { it.weight }, advice, if (d.length >= 7) input else null)
    }

    // ---------------------------------------------------------------- QR

    fun checkQr(payload: String): Check {
        val v = payload.trim()
        if (Regex("""^(https?://|www\.)""", RegexOption.IGNORE_CASE).containsMatchIn(v)) {
            val c = checkLink(v)
            return c.copy(kind = Kind.QR_LINK)
        }
        if (v.startsWith("WIFI:", ignoreCase = true)) {
            val fields = v.removePrefix("WIFI:").removePrefix("wifi:").split(";").filter { it.contains(':') }
                .associate { it.substringBefore(':').uppercase() to it.substringAfter(':') }
            val details = listOf("Network" to fields["S"].orEmpty(), "Security" to fields["T"].orEmpty().ifBlank { "Open" }, "Password" to fields["P"].orEmpty().ifBlank { "—" })
            val f = ArrayList<Finding>()
            if (fields["T"].orEmpty().isBlank() || fields["T"].equals("nopass", true)) f.add(Finding("Open network", "No password means anyone nearby can see your traffic. Fine for a café; avoid banking on it.", 1))
            return Check(Kind.QR_WIFI, v, minOf(100, f.sumOf { it.weight * 12 }), ScamAnalyzer.Verdict.LOW_RISK, f, listOf("Join from Wi-Fi settings — only if you expected this code (a menu, a host, a sign at the venue)."), null, details)
        }
        if (Regex("""^(tel:|sms:|smsto:|mailto:)""", RegexOption.IGNORE_CASE).containsMatchIn(v)) {
            val number = v.substringAfter(':').substringBefore('?').substringBefore(':')
            val c = if (v.lowercase().startsWith("mailto:")) checkMessage(v) else checkPhone(number)
            return c.copy(kind = Kind.QR_TEXT, input = v, details = listOf("Opens" to v.substringBefore(':').uppercase()))
        }
        // Plain text / vCard / anything else: show it, and run it through the message rules too.
        val c = checkMessage(v)
        return c.copy(kind = Kind.QR_TEXT, details = listOf("Content" to (if (v.startsWith("BEGIN:VCARD", true)) "Contact card" else "Text")))
    }

    // ---------------------------------------------------------------- actions

    fun shareText(c: Check): String {
        val sb = StringBuilder("Tenzy Safety check — ${c.verdict.label} (${c.score}/100)\n")
        sb.append(c.kind.label).append(": ").append(c.input.take(300)).append('\n')
        c.findings.forEach { sb.append("• ").append(it.title).append('\n') }
        if (c.findings.isEmpty()) sb.append("• No warning signs found\n")
        sb.append("\nScam texts can be forwarded to 7726 (SPAM) on most carriers. Checked on-device with Tenzy.")
        return sb.toString()
    }

    /** True when the system blocked-numbers screen opened. Otherwise the number is copied. */
    fun block(ctx: Context, number: String?): Boolean {
        if (number != null) {
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", number))
        }
        return try {
            if (!BlockedNumberContract.canCurrentUserBlockNumbers(ctx)) return false
            val tm = ctx.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
            val i: Intent = tm.createManageBlockedNumbersIntent() ?: return false
            ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) { false }
    }

    // ---------------------------------------------------------------- history (last 20)

    data class HistoryItem(val kind: Kind, val input: String, val verdict: ScamAnalyzer.Verdict, val score: Int, val timeMs: Long)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("safety_history", Context.MODE_PRIVATE)

    fun loadHistory(ctx: Context): List<HistoryItem> = try {
        val arr = JSONArray(prefs(ctx).getString("items", "[]") ?: "[]")
        (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            HistoryItem(
                runCatching { Kind.valueOf(o.getString("kind")) }.getOrDefault(Kind.MESSAGE),
                o.getString("input"),
                runCatching { ScamAnalyzer.Verdict.valueOf(o.getString("verdict")) }.getOrDefault(ScamAnalyzer.Verdict.LOW_RISK),
                o.optInt("score"), o.optLong("time"),
            )
        }
    } catch (_: Exception) { emptyList() }

    fun remember(ctx: Context, c: Check): List<HistoryItem> {
        val item = HistoryItem(c.kind, c.input, c.verdict, c.score, c.timeMs)
        val list = (listOf(item) + loadHistory(ctx).filter { it.input != c.input || it.kind != c.kind }).take(20)
        val arr = JSONArray()
        list.forEach { h ->
            arr.put(JSONObject().apply {
                put("kind", h.kind.name); put("input", h.input.take(400)); put("verdict", h.verdict.name); put("score", h.score); put("time", h.timeMs)
            })
        }
        prefs(ctx).edit().putString("items", arr.toString()).apply()
        return list
    }

    fun clearHistory(ctx: Context) { prefs(ctx).edit().remove("items").apply() }

    /** Re-run a history item with the rules for its kind. */
    fun rerun(h: HistoryItem): Check = when (h.kind) {
        Kind.MESSAGE -> checkMessage(h.input)
        Kind.LINK -> checkLink(h.input)
        Kind.PHONE -> checkPhone(h.input)
        Kind.QR_LINK, Kind.QR_WIFI, Kind.QR_TEXT -> checkQr(h.input)
    }
}
