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
}
