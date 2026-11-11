package com.handytools.app.tools.builder

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Tenzy Builder on Android. A chain is plain data: a list of built-in blocks with settings. It is run by calling
 * the engines the app already ships, so a chain from a template, a friend or the describe-it box can never run
 * anything that isn't already in the app. The JSON matches iOS, so tools copy between the two.
 */
enum class Kind(val label: String) {
    IMAGE("a photo"), TEXT("text"), FILE("a file"), PHOTO_FILE("a photo");

    fun feeds(need: Kind) = this == need || (need == IMAGE && this == PHOTO_FILE)
}

enum class Block(val id: String, val title: String, val takes: Kind, val gives: Kind, val blurb: String) {
    READ_TEXT("readText", "Read text", Kind.IMAGE, Kind.TEXT, "Reads the words in a photo."),
    PULL_RECEIPT("pullReceipt", "Pull receipt fields", Kind.TEXT, Kind.TEXT, "Finds store, date, items and total."),
    SUMMARIZE("summarize", "Summarize", Kind.TEXT, Kind.TEXT, "Boils long text down to the key sentences."),
    SHRINK("shrinkImage", "Shrink to size", Kind.IMAGE, Kind.PHOTO_FILE, "Makes a photo fit under a size you pick."),
    STRIP_LOCATION("stripLocation", "Strip location", Kind.IMAGE, Kind.PHOTO_FILE, "Removes where and when a photo was taken."),
    CONVERT("convertImage", "Convert format", Kind.IMAGE, Kind.PHOTO_FILE, "Saves the photo as JPG or PNG."),
    BUSINESS_CARD("businessCard", "Make a contact", Kind.TEXT, Kind.FILE, "Turns card text into a contact file."),
    CALENDAR_EVENT("calendarEvent", "Make a calendar event", Kind.TEXT, Kind.FILE, "Turns event text into a calendar file."),
    ACTION_ITEMS("actionItems", "Find tasks", Kind.TEXT, Kind.TEXT, "Pulls out the things someone has to do."),
    HIDE_SENSITIVE("hideSensitive", "Hide faces and numbers", Kind.IMAGE, Kind.PHOTO_FILE, "Covers faces and personal numbers."),
    CLEAN_TEXT("cleanText", "Tidy text", Kind.TEXT, Kind.TEXT, "Removes extra spaces, blank gaps and repeated lines."),
    PULL_DETAILS("pullDetails", "Find links, emails, phones", Kind.TEXT, Kind.TEXT, "Lists every web link, email address and phone number."),
    MAKE_TABLE("makeTable", "Text to spreadsheet", Kind.TEXT, Kind.FILE, "Turns rows of text into a spreadsheet (CSV) file.");

    companion object { fun byId(id: String) = values().firstOrNull { it.id == id } }
}

data class Step(val block: Block, val settings: Map<String, String> = emptyMap())

data class Chain(val id: String, val name: String, val steps: List<Step>) {
    val start: Kind get() = steps.firstOrNull()?.block?.takes ?: Kind.IMAGE
    val end: Kind? get() = steps.lastOrNull()?.block?.gives

    /** null when the steps fit together, otherwise a plain-words reason. */
    fun problem(starting: Kind = start): String? {
        if (steps.isEmpty()) return "Add at least one step."
        var kind = starting
        steps.forEachIndexed { i, s ->
            if (!kind.feeds(s.block.takes)) return "Step ${i + 1}, ${s.block.title}, needs ${s.block.takes.label} but gets ${kind.label}."
            kind = s.block.gives
        }
        return null
    }

    fun toJson(): JSONObject = JSONObject().put("id", id).put("name", name).put("steps", JSONArray().also { a ->
        steps.forEach { s -> a.put(JSONObject().put("block", s.block.id).put("settings", JSONObject(s.settings))) }
    })

    val shareText: String get() = PREFIX + toJson().toString()

    companion object {
        const val PREFIX = "tenzy-tool:"

        fun fromJson(o: JSONObject): Chain? = try {
            val arr = o.getJSONArray("steps")
            val steps = (0 until arr.length()).map { i ->
                val s = arr.getJSONObject(i)
                val b = Block.byId(s.getString("block")) ?: return null   // a block this phone doesn't have
                val st = s.optJSONObject("settings")
                val map = HashMap<String, String>()
                st?.keys()?.forEach { k -> map[k] = st.optString(k) }
                Step(b, map)
            }
            Chain(o.optString("id", UUID.randomUUID().toString()), o.optString("name", "My tool"), steps)
        } catch (_: Exception) { null }

        /** Accepts a copied tool only if it is well formed and its steps fit together. */
        fun imported(text: String): Chain? {
            val t = text.trim()
            if (!t.startsWith(PREFIX)) return null
            val c = try { fromJson(JSONObject(t.removePrefix(PREFIX))) } catch (_: Exception) { null } ?: return null
            if (c.steps.size > 12 || c.problem() != null) return null
            return c.copy(id = UUID.randomUUID().toString())
        }

        fun blank() = Chain(UUID.randomUUID().toString(), "My tool", emptyList())
    }
}

object ChainTemplates {
    val all: List<Chain> = listOf(
        Chain("receipt-to-row", "Receipt to expense row", listOf(Step(Block.READ_TEXT), Step(Block.PULL_RECEIPT))),
        Chain("photo-under-2mb", "Photo under 2 MB", listOf(Step(Block.SHRINK, mapOf("mb" to "2")))),
        Chain("safe-to-share", "Safe-to-share photo", listOf(Step(Block.STRIP_LOCATION))),
        Chain("card-to-contact", "Business card to contact", listOf(Step(Block.READ_TEXT), Step(Block.BUSINESS_CARD))),
        Chain("poster-to-event", "Poster to calendar event", listOf(Step(Block.READ_TEXT), Step(Block.CALENDAR_EVENT))),
        Chain("whiteboard-to-tasks", "Whiteboard to task list", listOf(Step(Block.READ_TEXT), Step(Block.ACTION_ITEMS))),
        Chain("hide-sensitive", "Hide faces and numbers", listOf(Step(Block.HIDE_SENSITIVE))),
        Chain("short-summary", "Long text to 3 sentences", listOf(Step(Block.SUMMARIZE, mapOf("sentences" to "3")))),
        Chain("table-to-sheet", "Photo of a table to spreadsheet", listOf(Step(Block.READ_TEXT), Step(Block.MAKE_TABLE))),
        Chain("links-and-numbers", "Pull links, emails and phones", listOf(Step(Block.PULL_DETAILS))),
        Chain("tidy-text", "Tidy pasted text", listOf(Step(Block.CLEAN_TEXT))),
    )
}

/** "Describe it": a sentence in, a list of existing blocks out, checked before anyone sees it. */
object ChainPlanner {
    fun plan(ask: String): Chain? {
        val s = " " + ask.lowercase() + " "
        fun has(vararg w: String) = w.any { s.contains(it) }
        val wantsPhoto = has("photo", "picture", "image", "scan", "screenshot", "snap", "camera", "receipt", "card", "poster", "flyer", "whiteboard")

        // "Tidy up this photo" is about the picture, so tidying only means text when text is what is being talked about.
        val textish = has("text", "notes", "words", "list", "lines", "pasted", "paste")
        val wantsClean = has("tidy", "clean up", "clean the", "dedupe", "de-dupe", "duplicate line", "remove duplicates", "extra spaces", "blank lines") && (!wantsPhoto || textish)
        val job: Block? = when {
            has("receipt", "expense", "invoice") -> Block.PULL_RECEIPT
            has("business card", "contact", "vcard") -> Block.BUSINESS_CARD
            has("calendar", "event", "poster", "flyer", "invite", "appointment") -> Block.CALENDAR_EVENT
            has("spreadsheet", "csv", "excel", "table", "columns") -> Block.MAKE_TABLE
            has("links", "urls", "web address", "email address", "phone number") -> Block.PULL_DETAILS
            has("task", "to-do", "todo", "whiteboard", "action item", "checklist") -> Block.ACTION_ITEMS
            has("summar", "tl;dr", "tldr", "shorten", "gist", "key points") -> Block.SUMMARIZE
            else -> null
        }
        val steps = ArrayList<Step>()
        if (job != null || wantsClean) {
            val needsPhoto = wantsPhoto || job == Block.PULL_RECEIPT || job == Block.BUSINESS_CARD || job == Block.CALENDAR_EVENT
            if (needsPhoto) steps.add(Step(Block.READ_TEXT))
            // Tidying goes first so the next step sees clean text.
            if (wantsClean) steps.add(Step(Block.CLEAN_TEXT))
            if (job != null) steps.add(if (job == Block.SUMMARIZE) Step(job, mapOf("sentences" to (number(s, "sentence", "line", "point") ?: 3).toString())) else Step(job))
            return finish(ask, steps)
        }
        if (has("blur", "hide", "redact", "private", "faces", "face ", "anonym", "censor")) steps.add(Step(Block.HIDE_SENSITIVE))
        if (has("location", "gps", "exif", "metadata", "safe to share", "safe-to-share", "strip")) steps.add(Step(Block.STRIP_LOCATION))
        if (has("png", "jpg", "jpeg", "convert", "format")) steps.add(Step(Block.CONVERT, mapOf("format" to if (s.contains("png")) "PNG" else "JPG")))
        if (has("shrink", "smaller", "compress", "reduce", "under ", " mb", "email", "upload", "size")) {
            steps.add(Step(Block.SHRINK, mapOf("mb" to (number(s, "mb", "megabyte") ?: 2).toString())))
        }
        return finish(ask, steps)
    }

    private fun finish(ask: String, steps: List<Step>): Chain? {
        if (steps.isEmpty()) return null
        val ordered = steps.filter { it.block != Block.SHRINK } + steps.filter { it.block == Block.SHRINK }
        val t = ask.trim().replace('\n', ' ')
        val name = (t.take(1).uppercase() + t.drop(1)).let { if (it.length > 34) it.take(32) + "…" else it }
        val c = Chain(UUID.randomUUID().toString(), name, ordered.take(8))
        return if (c.problem() == null) c else null
    }

    /** The number written just before a unit word: "under 3 mb" gives 3. */
    internal fun number(s: String, vararg units: String): Int? {
        for (u in units) {
            val i = s.indexOf(u)
            if (i <= 0) continue
            val head = s.substring(0, i).trimEnd()
            val digits = head.takeLastWhile { it.isDigit() }
            digits.toIntOrNull()?.takeIf { it > 0 }?.let { return it }
        }
        return null
    }
}
