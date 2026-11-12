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
}
