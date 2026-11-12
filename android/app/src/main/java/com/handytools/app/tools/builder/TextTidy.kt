package com.handytools.app.tools.builder

/**
 * Plain-text helpers behind the Tidy text, Find details and Spreadsheet blocks. Pure and deterministic so they are
 * unit-tested off-device. These are the same rules as the iOS twin (`TextTidy.swift`).
 */
object TextTidy {
    private val NEWLINE = Regex("[\\n\\u000B\\u000C\\r\\u0085\\u2028\\u2029]")
    private val SPACES = Regex("[\\s\\u00A0]+")

    /** Collapses runs of spaces, trims every line, removes blank gaps and repeated lines (ignoring case). */
    fun clean(text: String): String {
        val seen = HashSet<String>()
        val out = ArrayList<String>()
        var lastBlank = true            // also drops blank lines at the very top
        for (raw in text.split(NEWLINE)) {
            val line = raw.split(SPACES).filter { it.isNotEmpty() }.joinToString(" ")
            if (line.isEmpty()) {
                if (!lastBlank) { out.add(""); lastBlank = true }
                continue
            }
            if (!seen.add(line.lowercase())) continue
            out.add(line); lastBlank = false
        }
        while (out.isNotEmpty() && out.last().isEmpty()) out.removeAt(out.size - 1)
        return out.joinToString("\n")
    }

    data class Details(val links: List<String> = emptyList(), val emails: List<String> = emptyList(), val phones: List<String> = emptyList()) {
        fun isEmpty() = links.isEmpty() && emails.isEmpty() && phones.isEmpty()
        /** One section per kind that was found, e.g. "Links\nhttps://..." */
        val text: String get() = listOf("Links" to links, "Emails" to emails, "Phones" to phones)
            .filter { it.second.isNotEmpty() }
            .joinToString("\n\n") { it.first + "\n" + it.second.joinToString("\n") }
    }

    // A phone number is 10 digits (optionally with a country code), not part of a longer digit run,
    // so a card or account number is never mistaken for one.
    private val PHONE = Regex("""(?<!\d)(?:\+?\d{1,3}[\s.-]?)?(?:\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}(?!\d)""")
    private val EMAIL = Regex("""[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)*\.[A-Z]{2,}""", RegexOption.IGNORE_CASE)
    private val LINK = Regex("""(?:https?://|www\.)[^\s<>\x22\x27]+""", RegexOption.IGNORE_CASE)

    fun details(text: String): Details = Details(
        links = unique(LINK.findAll(text).map { trimTail(it.value) }.toList()),
        emails = unique(EMAIL.findAll(text).map { it.value }.toList()),
        phones = unique(PHONE.findAll(text).map { it.value.trim() }.toList()),
    )

    /** Sentence punctuation that ends a link in running text is not part of the link. */
    private fun trimTail(s: String): String = s.trimEnd('.', ',', ';', ':', '!', '?', ')')

    private fun unique(a: List<String>): List<String> {
        val seen = HashSet<String>()
        return a.filter { seen.add(it.lowercase()) }
    }

    // MARK: spreadsheet

    /** Split a line into columns on tabs, pipes, 2+ spaces or commas (whichever the line uses). */
    fun columns(line: String): List<String> {
        if (line.contains('\t')) return line.split('\t').map { it.trim() }
        if (line.contains('|')) return line.split('|').map { it.trim() }.filter { it.isNotEmpty() }
        val bySpaces = line.split("  ").map { it.trim() }.filter { it.isNotEmpty() }
        if (bySpaces.size >= 2) return bySpaces
        if (line.contains(',')) return line.split(',').map { it.trim() }
        return listOf(line.trim())
    }

    fun csv(s: String): String =
        if (s.any { it == ',' || it == '"' || it == '\n' }) "\"" + s.replace("\"", "\"\"") + "\"" else s

    fun tableCsv(text: String): String {
        val rows = text.split(NEWLINE).filter { it.isNotBlank() }.map { columns(it) }
        val width = rows.maxOfOrNull { it.size } ?: 0
        return rows.joinToString("\n") { r -> (r + List(maxOf(0, width - r.size)) { "" }).joinToString(",") { csv(it) } }
    }

    // MARK: links without tracking (the same junk list as the iOS LinkCleaner)

    private val JUNK = setOf("fbclid", "gclid", "gclsrc", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid", "yclid", "twclid", "ttclid", "_hsenc", "_hsmi",
        "mkt_tok", "ref", "ref_", "ref_src", "ref_url", "spm", "si", "feature", "trk", "_ga", "_gl", "s_kwcid", "ncid", "cmpid", "linkid", "ascsubtag")
    private val JUNK_PREFIX = listOf("utm_", "pk_", "piwik_", "matomo_", "mtm_", "ga_", "hsa_", "oly_", "vero_", "at_")

    /** One link with its tracking parameters removed. Anything that isn't a plain http(s) link comes back unchanged. */
    fun cleanLink(raw: String): String {
        val url = if (raw.startsWith("http", ignoreCase = true)) raw else "https://$raw"
        val hash = url.indexOf('#').let { if (it < 0) url.length else it }
        val q = url.indexOf('?')
        if (q < 0 || q > hash) return url
        val kept = url.substring(q + 1, hash).split('&').filter { part ->
            val n = part.substringBefore('=').lowercase()
            part.isNotEmpty() && n !in JUNK && JUNK_PREFIX.none { n.startsWith(it) }
        }
        return url.substring(0, q) + (if (kept.isEmpty()) "" else "?" + kept.joinToString("&")) + url.substring(hash)
    }

    /** Every web link in the text with its tracking removed. Null when the text has no links. */
    fun cleanLinks(text: String): String? {
        val links = details(text).links
        if (links.isEmpty()) return null
        var out = text
        for (l in links) out = out.replace(l, cleanLink(l))
        return out.trim().takeIf { links.size > 1 || it != links[0] } ?: cleanLink(links[0])
    }

    /** The scam checker's verdict as a few plain lines: the verdict, the main reasons, and one thing to do. */
    fun scamReport(verdict: String, reasons: List<String>, linkNotes: List<String>, advice: String?): String =
        (listOf("$verdict.") + reasons.take(4).map { "• $it" } + linkNotes.map { "• $it" } + (advice?.let { listOf("", it) } ?: emptyList())).joinToString("\n")

    // MARK: size limits, pixel sizes and the watermark line (same values and wording as iOS ChainImage)

    /** Size limits a tool can pick, in megabytes. The small ones are for upload forms that demand 20, 50 or 100 KB. */
    val LIMITS = listOf(0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0)
    fun limitLabel(mb: Double): String =
        if (mb < 1) "${Math.round(mb * 1000)} KB" else "${if (mb == Math.floor(mb)) mb.toLong().toString() else mb.toString()} MB"

    /** Pixel sizes offered by "Exact pixel size". 413x531 is a 35x45 mm passport photo at 300 dpi. */
    val SIZES = listOf("35x45 mm photo (413x531)" to "413x531", "2x2 inch photo (600x600)" to "600x600", "Square 1080" to "1080x1080",
        "Portrait 4:5 (1080x1350)" to "1080x1350", "Wide 16:9 (1920x1080)" to "1920x1080")

    /** "413x531" (also "413 x 531" or "413×531") as width and height; null if it isn't two sensible numbers. */
    fun pixels(s: String): Pair<Int, Int>? {
        val parts = s.lowercase().replace("×", "x").split('x').map { it.trim() }
        if (parts.size != 2) return null
        val w = parts[0].toIntOrNull() ?: return null
        val h = parts[1].toIntOrNull() ?: return null
        return if (w in 16..8000 && h in 16..8000) w to h else null
    }

    /** The watermark line: the tool's words (or a safe default) plus the day it was made. */
    fun watermarkLine(words: String, day: java.util.Date): String =
        (words.trim().ifEmpty { "For verification only" }) + " · " + java.text.SimpleDateFormat("d MMM yyyy", java.util.Locale.US).format(day)

    // MARK: file names for results (same rules as iOS ChainName)

    /** "{date}" becomes today's date and "{tool}" the tool's name; characters a file name can't hold are dropped; several results get -1, -2... */
    fun fileName(pattern: String?, tool: String, day: java.util.Date = java.util.Date(), index: Int? = null, ext: String): String {
        val ymd = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(day)
        var base = (pattern ?: "").replace("{date}", ymd).replace("{tool}", tool).replace("{month}", ymd.take(7))
            .filter { it !in "/\\:*?\"<>|" && !it.isISOControl() }
            .trim { it.isWhitespace() || it == '.' }
        if (base.length > 80) base = base.take(80).trim()
        if (base.isEmpty()) base = if (index == null) "Tenzy-result" else "Tenzy"
        return base + (index?.let { "-$it" } ?: "") + "." + ext
    }

    // MARK: a sheet that grows (same rules as iOS RunningList)

    const val DEFAULT_LIST = "Expenses {month}"

    /** The old sheet plus the new rows. If the new rows start with the sheet's own header line it is not repeated. Blank lines are dropped. */
    fun mergedList(existing: String, incoming: String): String {
        fun rows(s: String) = s.split(NEWLINE).map { it.trim() }.filter { it.isNotEmpty() }
        val old = rows(existing)
        var new = rows(incoming)
        if (old.isNotEmpty() && new.firstOrNull() == old.first()) new = new.drop(1)
        return (old + new).joinToString("\n")
    }

    // MARK: other ways in (same rules as iOS InputText)

    /** Adds new words under what is already in the box, without piling up blank lines. */
    fun joined(existing: String, adding: String): String {
        val a = existing.trim(); val b = adding.trim()
        return when { a.isEmpty() -> b; b.isEmpty() -> a; else -> a + "\n" + b }
    }

    /** A contact as plain lines (name, company, each phone, each email), which is what the text steps read. */
    fun contactLines(name: String, company: String, phones: List<String>, emails: List<String>): String =
        (listOf(name, company) + phones + emails).map { it.trim() }.filter { it.isNotEmpty() }.joinToString("\n")

    /** Entries below the header line. A sheet with only a header has none. */
    fun sheetRows(text: String): Int = maxOf(0, text.split(NEWLINE).count { it.isNotBlank() } - 1)

    /** The sheet without its last entry (the row added by mistake). Null when there is no entry to remove. */
    fun withoutLastRow(text: String): String? {
        val lines = text.split(NEWLINE).filter { it.isNotBlank() }
        return if (lines.size > 1) lines.dropLast(1).joinToString("\n") else null
    }

    /** "12 entries · changed today". */
    fun sheetSummary(rows: Int, daysAgo: Int): String {
        val count = when (rows) { 0 -> "No entries yet"; 1 -> "1 entry"; else -> "$rows entries" }
        val whenText = when { daysAgo <= 0 -> "changed today"; daysAgo == 1 -> "changed yesterday"; else -> "changed $daysAgo days ago" }
        return "$count · $whenText"
    }

    /** One row for an expense sheet from what the receipt reader found. */
    fun expenseRow(dateMs: Long?, merchant: String, total: String): String {
        val date = dateMs?.let { java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date(it)) } ?: ""
        return "Date,Merchant,Total,Tax,Currency\n$date,${csv(merchant.trim())},${total.filter { it.isDigit() || it == '.' }},,"
    }

    // MARK: WhatsApp without saving a number (same rules as iOS ChainText.chatLink)

    /** A wa.me link for the number in the text. A number written without a country code gets [countryCode]. Null when there is no usable number. */
    fun chatLink(text: String, countryCode: String): String? {
        val raw = (details(text).phones.firstOrNull() ?: text).trim()
        var digits = raw.filter { it in '0'..'9' }
        if (digits.length !in 7..15) return null
        if (!raw.startsWith("+")) {
            if (digits.startsWith("00")) digits = digits.drop(2)
            else {
                if (digits.startsWith("0")) digits = digits.drop(1)
                if (digits.length <= 10) digits = countryCode.filter { it in '0'..'9' } + digits   // longer: it already has its country code
            }
        }
        return "https://wa.me/$digits"
    }

    /** Country calling code for a region ("US" -> "1"). Unknown regions fall back to "1"; the step lets it be changed. */
    fun callingCode(region: String?): String = mapOf("US" to "1", "CA" to "1", "IN" to "91", "GB" to "44", "AU" to "61", "DE" to "49", "FR" to "33", "ES" to "34",
        "IT" to "39", "NL" to "31", "BR" to "55", "MX" to "52", "AE" to "971", "SA" to "966", "SG" to "65", "PK" to "92", "BD" to "880", "ID" to "62", "PH" to "63",
        "NG" to "234", "ZA" to "27", "KE" to "254", "JP" to "81", "KR" to "82", "TR" to "90", "EG" to "20")[(region ?: "").uppercase()] ?: "1"

    /** What "Identify it" says: the barcode first if there is one, then each guess with how sure it is. Same wording as iOS. */
    fun identifyLines(barcode: String?, labels: List<Pair<String, Float>>): String =
        (listOfNotNull(barcode?.takeIf { it.isNotBlank() }?.let { "Barcode $it" }) +
            labels.map { (name, sure) -> "$name (${Math.round(sure * 100)}% sure)" }).joinToString("\n")

    // MARK: video size limits (same values as iOS ChainText)

    /** Size limits a video tool can pick, in megabytes: chat apps, email, and upload forms. */
    val VIDEO_LIMITS = listOf(10, 16, 25, 50, 100)
    fun videoLimit(setting: String?): Int = (setting?.toDoubleOrNull()?.toInt() ?: 25).coerceIn(1, 2000)

    /** The video bitrate that lands a clip of this length under the limit, leaving room for sound and the file's own overhead. */
    fun videoBitrate(targetBytes: Long, durationMs: Long): Int =
        if (durationMs <= 0L) 2_000_000 else ((targetBytes.toDouble() * 8.0 * 0.88) / (durationMs / 1000.0) - 128_000.0).toInt().coerceIn(200_000, 12_000_000)

    /** The tallest picture that still looks good at that bitrate. The caller never goes above the video's own height. */
    fun videoHeight(bitrate: Int): Int = when { bitrate < 900_000 -> 360; bitrate < 1_800_000 -> 480; bitrate < 4_000_000 -> 720; else -> 1080 }

    // MARK: return windows (same rules as iOS ChainText)

    val RETURN_WINDOWS = listOf(14, 30, 60, 90)
    fun returnDays(setting: String?): Int = (setting?.toIntOrNull() ?: 30).coerceIn(1, 365)

    /** 9:00 in the morning, [days] after the day it was bought (today when the receipt shows no date). */
    fun returnDeadline(purchasedMs: Long?, days: Int, now: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Long =
        java.util.Calendar.getInstance(zone).apply {
            timeInMillis = purchasedMs ?: now
            add(java.util.Calendar.DAY_OF_YEAR, days)
            set(java.util.Calendar.HOUR_OF_DAY, 9); set(java.util.Calendar.MINUTE, 0); set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis

    fun returnTitle(merchant: String): String = merchant.trim().let { if (it.isEmpty()) "Last day to return" else "Last day to return: $it" }

    // MARK: Wi-Fi details in text (same rules as iOS ChainText.wifi)

    private val WIFI_NAME_KEYS = listOf("network name", "wifi name", "wi-fi name", "ssid", "network", "wi-fi", "wifi")
    private val WIFI_PASS_KEYS = listOf("password", "passphrase", "passcode", "pass", "pwd", "pw", "key")

    private fun labelled(line: String, keys: List<String>): String? {
        val lower = line.lowercase()
        for (k in keys) {
            if (!lower.startsWith(k)) continue
            val rest = line.drop(k.length).trimStart(' ')
            if (rest.isEmpty() || (rest[0] != ':' && rest[0] != '=')) continue
            return rest.drop(1).trim()
        }
        return null
    }

    /**
     * The network name and password written in some text, or null when no name is there. Labels must be followed by
     * ":" or "=". With no labels at all, exactly two lines are read as name then password.
     */
    fun wifi(text: String): Pair<String, String>? {
        val parts = ArrayList<String>()
        for (line in text.split(NEWLINE)) {
            var pieces = listOf(line)
            for (sep in listOf(" / ", " | ", ",", "  ")) pieces = pieces.flatMap { it.split(sep) }
            parts.addAll(pieces.map { it.trim() }.filter { it.isNotEmpty() })
        }
        var name: String? = null; var pass: String? = null
        for (p in parts) {
            val n = labelled(p, WIFI_NAME_KEYS)
            if (n != null) { if (name == null && n.isNotEmpty()) name = n; continue }
            val w = labelled(p, WIFI_PASS_KEYS)
            if (w != null && pass == null) pass = w
        }
        // No labels at all: two single words are a name and a password. Anything wordier is just a sentence.
        if (name == null && pass == null && parts.size == 2 && ' ' !in parts[0] && ' ' !in parts[1]) return parts[0] to parts[1]
        return name?.let { it to (pass ?: "") }
    }

    /** The text a Wi-Fi QR code holds. A network with no password is marked open. */
    fun wifiCode(text: String): String? {
        val w = wifi(text) ?: return null
        fun esc(s: String) = buildString { s.forEach { if (it in "\\;,:\"") append('\\'); append(it) } }
        return if (w.second.isEmpty()) "WIFI:T:nopass;S:${esc(w.first)};;" else "WIFI:T:WPA;S:${esc(w.first)};P:${esc(w.second)};;"
    }

    /** Equal slots down a sheet, one per picture, separated by the margin: left, top, right, bottom. */
    fun slots(count: Int, width: Float, height: Float, margin: Float): List<FloatArray> {
        if (count <= 0) return emptyList()
        val h = (height - margin * (count + 1)) / count
        return (0 until count).map { floatArrayOf(margin, margin + it * (h + margin), width - margin, margin + it * (h + margin) + h) }
    }
}
