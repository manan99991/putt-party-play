package com.handytools.app.tools.builder

/**
 * "Find the best deal": pulls priced, sized items out of text and ranks them by true unit price. Pure and
 * deterministic, with the same rules as the iPhone version (`PriceBrain`), so both phones agree on the winner.
 */
object PriceDeal {
    enum class Base { MASS, VOLUME, COUNT }
    data class Size(val qty: Double, val base: Base)
    data class Entry(val name: String, val price: Double, val sizeText: String)
    data class Ranked(val entry: Entry, val perBase: Double?, val label: String)

    // Ounces are handled separately (troy vs standard), so they are not in this table.
    private val MASS_TO_G = mapOf("g" to 1.0, "gram" to 1.0, "grams" to 1.0, "kg" to 1000.0, "kilo" to 1000.0, "kilogram" to 1000.0, "kgs" to 1000.0,
        "lb" to 453.592, "lbs" to 453.592, "pound" to 453.592, "pounds" to 453.592)
    private const val OUNCE_G = 28.3495
    private const val TROY_OUNCE_G = 31.1035
    private val VOL_TO_ML = mapOf("ml" to 1.0, "milliliter" to 1.0, "millilitre" to 1.0, "l" to 1000.0, "liter" to 1000.0, "litre" to 1000.0, "cl" to 10.0,
        "floz" to 29.5735, "pt" to 473.176, "pint" to 473.176, "qt" to 946.353, "quart" to 946.353, "gal" to 3785.41, "gallon" to 3785.41, "cup" to 236.588, "cups" to 236.588)
    private val COUNT_WORDS = setOf("ct", "count", "pk", "pack", "packs", "pc", "pcs", "piece", "pieces", "ea", "each", "rolls", "roll", "sheets", "bars", "bar", "tabs", "capsules", "caps")

    private val MULTIPACK = Regex("""^\s*(\d+(?:\.\d+)?)\s*[x×]\s*(.+)$""")
    private val QTY_UNIT = Regex("""(\d+(?:\.\d+)?)\s*([a-z.]+)""")

    /** "1.5 L" is 1500 ml, "16 oz" is 453.6 g, "2 x 200 ml" is 400 ml. Null when there is no quantity and unit. */
    fun parseSize(raw: String): Size? {
        val s = raw.lowercase().replace("fl oz", "floz").replace("fluid ounce", "floz")
        var multiplier = 1.0
        var rest = s
        MULTIPACK.find(s)?.let { multiplier = it.groupValues[1].toDoubleOrNull() ?: 1.0; rest = it.groupValues[2] }
        val hit = QTY_UNIT.find(rest) ?: return null
        val n = hit.groupValues[1].toDoubleOrNull() ?: return null
        val unit = hit.groupValues[2].trim('.')
        val value = n * multiplier
        if (unit in listOf("oz", "ozt", "toz", "ounce", "ounces")) {
            val troy = s.contains("troy") || unit == "ozt" || unit == "toz"
            return Size(value * (if (troy) TROY_OUNCE_G else OUNCE_G), Base.MASS)
        }
        MASS_TO_G[unit]?.let { return Size(value * it, Base.MASS) }
        VOL_TO_ML[unit]?.let { return Size(value * it, Base.VOLUME) }
        if (unit in COUNT_WORDS) return Size(value, Base.COUNT)
        return null
    }

    private val SIZE = Regex("""\d+(?:\.\d+)?\s*(?:kg|kilograms?|grams?|g|ozt|oz t|oz|ounces?|lbs?|pounds?|ml|liters?|litres?|l|cl|floz|fl oz|pt|qt|gal|cups?|ct|count|packs?|pk|pcs?|pieces?|rolls?|sheets?|bars?|tabs?|capsules?|caps)\b""", RegexOption.IGNORE_CASE)
    private val PRICE = Regex("""[$€£]\s?\d{1,3}(?:,\d{3})*(?:\.\d{2})?|\d{1,3}(?:,\d{3})*\.\d{2}""")

    /** A price is paired with the most recent size seen at or above it (listings put the name and size on one line, the price on another). */
    fun extract(text: String): List<Triple<String, String, String>> {
        val out = ArrayList<Triple<String, String, String>>()
        var pendingName = ""; var pendingSize = ""
        for (line in text.split('\n')) {
            SIZE.find(line)?.value?.let { size ->
                pendingSize = size.trim()
                var name = line.replace(size, "")
                PRICE.find(name)?.value?.let { p -> name = name.replace(p, "") }
                name = name.trim(' ', '-', '•', '·', '\t', '|')
                pendingName = if (name.count { it.isLetter() } >= 2) name else ""
            }
            val price = PRICE.find(line)?.value
            if (price != null && pendingSize.isNotEmpty()) {
                out.add(Triple(pendingName, price.trim(), pendingSize))
                pendingName = ""; pendingSize = ""
            }
        }
        return out
    }

    /** Only entries sharing the most common kind of size are compared: per 100 g, per 100 ml, or each. */
    fun rank(entries: List<Entry>): List<Ranked> {
        val parsed = entries.map { it to parseSize(it.sizeText) }
        val compareBase = parsed.mapNotNull { it.second?.base }.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key
        val label = when (compareBase) { Base.MASS -> "per 100 g"; Base.VOLUME -> "per 100 ml"; Base.COUNT -> "each"; null -> "" }
        return parsed.map { (e, size) ->
            val pb = if (size != null && size.qty > 0 && size.base == compareBase) (if (size.base == Base.COUNT) e.price / size.qty else e.price / size.qty * 100) else null
            Ranked(e, pb, if (pb != null) label else "add a size to compare")
        }
    }

    fun money(v: Double, locale: java.util.Locale = java.util.Locale.getDefault()): String =
        runCatching { java.text.NumberFormat.getCurrencyInstance(locale).format(v) }.getOrDefault(String.format(java.util.Locale.US, "%.2f", v))

    fun perUnit(r: Ranked, locale: java.util.Locale = java.util.Locale.getDefault()): String =
        r.perBase?.let { money(it, locale) + " " + r.label } ?: r.label

    /** The items ranked cheapest first, one per line, the winner marked. Null when fewer than two can be compared. */
    fun bestDeal(text: String, locale: java.util.Locale = java.util.Locale.getDefault()): String? {
        val entries = extract(text).mapNotNull { (name, price, size) ->
            price.filter { it.isDigit() || it == '.' }.toDoubleOrNull()?.let { Entry(name.ifEmpty { size }, it, size) }
        }
        val ranked = rank(entries).filter { it.perBase != null }.sortedBy { it.perBase }
        if (ranked.size < 2) return null
        return (listOf("Best deal: ${ranked[0].entry.name}, ${perUnit(ranked[0], locale)}") + ranked.drop(1).map { "${it.entry.name}, ${perUnit(it, locale)}" }).joinToString("\n")
    }

    // MARK: describing a photo (Android has no on-device describer, so this is built from what the phone can detect)

    /** One or two plain sentences from what was detected: the things in it, how many people, and the first words written in it. Empty when nothing was detected. */
    fun describe(labels: List<String>, faces: Int, words: String): String {
        val things = labels.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.distinct().take(4)
        val parts = ArrayList<String>()
        if (things.isNotEmpty()) parts.add("This looks like " + when (things.size) {
            1 -> things[0]
            else -> things.dropLast(1).joinToString(", ") + " and " + things.last()
        } + ".")
        if (faces == 1) parts.add("There is one person in it.") else if (faces > 1) parts.add("There are $faces people in it.")
        val w = words.split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (w.isNotEmpty()) parts.add("It has writing that starts: \"" + w.take(12).joinToString(" ") + (if (w.size > 12) "…" else "") + "\"")
        return parts.joinToString(" ")
    }

    // MARK: enhancing a photo

    /**
     * Where the darkest and brightest real tones are in a 256-bin brightness histogram, ignoring the extreme [clip]
     * share at each end (stray black or white pixels). Stretching between them fixes flat, grey photos.
     */
    fun levels(hist: IntArray, clip: Double = 0.01): Pair<Int, Int> {
        val total = hist.sum()
        if (total <= 0) return 0 to 255
        val cut = (total * clip).toLong()
        var lo = 0; var acc = 0L
        while (lo < 255 && acc + hist[lo] <= cut) { acc += hist[lo]; lo++ }
        var hi = 255; acc = 0L
        while (hi > 0 && acc + hist[hi] <= cut) { acc += hist[hi]; hi-- }
        return if (hi - lo < 16) 0 to 255 else lo to hi      // already narrow by design (a blank page): leave it alone
    }

    /** Passport and ID photo sizes in pixels, the same list and ids as iOS. */
    val PASSPORT = listOf(Triple("us", "US 2×2 in", 600 to 600), Triple("eu", "EU / Schengen 35×45", 413 to 531), Triple("uk", "UK 35×45 mm", 413 to 531),
        Triple("in", "India 35×45 mm", 413 to 531), Triple("ca", "Canada 50×70 mm", 591 to 827))
    fun passportSize(id: String?): Pair<Int, Int> = (PASSPORT.firstOrNull { it.first == id } ?: PASSPORT[0]).third
}
