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
    IMAGE("a photo"), TEXT("text"), FILE("a file"), PHOTO_FILE("a photo"), VIDEO("a video"),
    /** A recording or other sound file, and a PDF. Both travel as file bytes; the kind says which steps fit. */
    AUDIO("a recording"), PDF("a PDF");

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
    MAKE_TABLE("makeTable", "Text to spreadsheet", Kind.TEXT, Kind.FILE, "Turns rows of text into a spreadsheet (CSV) file."),
    SCAM_CHECK("scamCheck", "Check for scams", Kind.TEXT, Kind.TEXT, "Says if a message looks like a scam, and why."),
    CLEAN_LINKS("cleanLinks", "Clean tracking from links", Kind.TEXT, Kind.TEXT, "Strips the tracking off web links."),
    MAKE_QR("makeQr", "Make a QR code", Kind.TEXT, Kind.IMAGE, "Turns text or a link into a QR code."),
    PHOTO_PDF("photoPdf", "Make a PDF", Kind.IMAGE, Kind.PDF, "Turns the photo into a PDF."),
    WATERMARK("watermark", "Add a watermark", Kind.IMAGE, Kind.IMAGE, "Writes your words and today's date across it, so a copy can't be misused."),
    RESIZE_PHOTO("resizePhoto", "Exact pixel size", Kind.IMAGE, Kind.IMAGE, "Fits an exact size in pixels, for ID photos and upload forms."),
    EXPENSE_ROW("expenseRow", "Receipt to one expense row", Kind.TEXT, Kind.TEXT, "Date, store and total as one row."),
    ADD_TO_LIST("addToList", "Add to a running list", Kind.TEXT, Kind.FILE, "Adds the rows to the same sheet every time, one sheet a month."),
    CHAT_LINK("chatLink", "WhatsApp link for a number", Kind.TEXT, Kind.TEXT, "Opens a WhatsApp chat with a number without saving it as a contact."),
    CONTACT_QR("contactQr", "Contact as a QR code", Kind.TEXT, Kind.IMAGE, "A code another phone scans to save the contact. Only what you typed is included."),
    PRICE_COMPARE("priceCompare", "Find the best deal", Kind.TEXT, Kind.TEXT, "Ranks priced, sized items by what they really cost per unit."),
    DESCRIBE("describe", "Describe the photo", Kind.IMAGE, Kind.TEXT, "Says what the photo shows."),
    ENHANCE("enhance", "Enhance", Kind.IMAGE, Kind.IMAGE, "Balances a flat or dull photo."),
    PASSPORT_PHOTO("passportPhoto", "Passport photo", Kind.IMAGE, Kind.PHOTO_FILE, "Crops to an official ID size on a white background."),
    IDENTIFY("identify", "Identify it", Kind.IMAGE, Kind.TEXT, "Names the object or reads the barcode."),
    CUTOUT("cutout", "Cut out subject", Kind.IMAGE, Kind.IMAGE, "Lifts the main subject off its background."),
    RETURN_BY("returnBy", "Return-by reminder", Kind.TEXT, Kind.FILE, "Puts the last day to return it in your calendar, counted from the receipt's date."),
    WIFI_QR("wifiQr", "Wi-Fi join code", Kind.TEXT, Kind.IMAGE, "Finds the network name and password and makes a code guests scan to join. No typing."),
    VIDEO_SHRINK("videoShrink", "Shrink video to size", Kind.VIDEO, Kind.VIDEO, "Makes a video fit under a size you pick, and leaves its location behind."),
    VIDEO_STILL("videoStill", "Grab a still", Kind.VIDEO, Kind.IMAGE, "Takes one picture out of the video."),
    VIDEO_MUTE("videoMute", "Remove the sound", Kind.VIDEO, Kind.VIDEO, "The same video with no sound."),
    VIDEO_AUDIO("videoAudio", "Keep only the sound", Kind.VIDEO, Kind.AUDIO, "Just the sound, as an audio file."),
    STAMP("stamp", "Sign and stamp", Kind.IMAGE, Kind.IMAGE, "Puts your saved signature, your name and today's date where you placed them."),
    VIDEO_TRIM("videoTrim", "Keep the start or the end", Kind.VIDEO, Kind.VIDEO, "Keeps the first or last part, for stories and status posts with a time limit."),
    VIDEO_GIF("videoGif", "Make a GIF", Kind.VIDEO, Kind.FILE, "Turns the first few seconds into a GIF that plays anywhere."),
    VIDEO_ROTATE("videoRotate", "Turn it", Kind.VIDEO, Kind.VIDEO, "Turns a sideways or upside-down video the right way up."),
    VIDEO_VERTICAL("videoVertical", "Crop to tall (9:16)", Kind.VIDEO, Kind.VIDEO, "Crops the middle to the tall shape phones and stories use."),
    VIDEO_CAPTIONS("videoCaptions", "Add captions", Kind.VIDEO, Kind.VIDEO, "Listens to the video and writes what is said along the bottom."),
    SPEECH_TEXT("speechText", "Write out what is said", Kind.AUDIO, Kind.TEXT, "Turns a voice memo or any recording into text. The recording stays on this phone."),
    READ_ALOUD("readAloud", "Read it aloud", Kind.TEXT, Kind.AUDIO, "Reads the text into an audio file you can listen to later."),
    TRANSLATE("translate", "Translate", Kind.TEXT, Kind.TEXT, "Puts the text into the language you pick. Works out the original language itself."),
    REWRITE("rewrite", "Rewrite it", Kind.TEXT, Kind.TEXT, "Rewrites the text clearer, shorter, friendlier or more formal."),
    READ_CODE("readCode", "Read a QR or barcode", Kind.IMAGE, Kind.TEXT, "Reads what a QR code or barcode says, without opening it."),
    PAGE_TEXT("pageText", "Read the page at a link", Kind.TEXT, Kind.TEXT, "Opens the link and keeps only the words: no menus, ads or pop-ups."),
    TEXT_PDF("textPdf", "Text to PDF", Kind.TEXT, Kind.PDF, "Lays the text out as a clean PDF."),
    PDF_SHRINK("pdfShrink", "Shrink the PDF", Kind.PDF, Kind.PDF, "Makes a PDF smaller, so it fits in an email or an upload form."),
    PDF_LOCK("pdfLock", "Lock with a password", Kind.PDF, Kind.PDF, "Asks for a password before the PDF opens."),
    PDF_PAGES("pdfPages", "Keep some pages", Kind.PDF, Kind.PDF, "Keeps only the pages you list. Leave it empty to keep them all."),
    PDF_TEXT("pdfText", "Read the PDF's words", Kind.PDF, Kind.TEXT, "Pulls the words out of a PDF."),
    STICKER("sticker", "Make a sticker", Kind.IMAGE, Kind.PHOTO_FILE, "Cuts out the person, pet or object and gives it a white edge, ready for WhatsApp or Messages."),
    EMOJI_FACES("emojiFaces", "Emoji over faces", Kind.IMAGE, Kind.IMAGE, "Puts an emoji over every face. Handy for posting a photo without showing who is in it."),
    MEME("meme", "Add meme text", Kind.IMAGE, Kind.IMAGE, "Big white words across the top and bottom of the photo."),
    EMOJI_MOSAIC("emojiMosaic", "Rebuild it from emojis", Kind.IMAGE, Kind.IMAGE, "Rebuilds the photo out of hundreds of emojis. Zoom in to see them."),
    VIDEO_SPEED("videoSpeed", "Slow it down or speed it up", Kind.VIDEO, Kind.VIDEO, "Slow motion, or two or four times faster. Comes out without sound."),
    VIDEO_LOOP("videoLoop", "Boomerang GIF", Kind.VIDEO, Kind.FILE, "The first couple of seconds played forwards and back, as a GIF that loops for ever."),
    ART_FILTER("artFilter", "Sketch, comic or pop art", Kind.IMAGE, Kind.IMAGE, "Redraws the photo as a pencil sketch, a comic, black and white or pop art."),
    VOICE_CHANGE("voiceChange", "Change the voice", Kind.AUDIO, Kind.AUDIO, "Plays the recording as a chipmunk, a deep voice or a giant.");

    companion object { fun byId(id: String) = values().firstOrNull { it.id == id } }
}

/** What the person is trying to get done. The builder groups steps under these goals. Same wording as iOS. */
val Block.goal: String get() = when (this) {
    Block.SHRINK, Block.CONVERT, Block.RESIZE_PHOTO, Block.VIDEO_SHRINK, Block.VIDEO_TRIM, Block.PDF_SHRINK -> "Make it easy to send"
    Block.STRIP_LOCATION, Block.HIDE_SENSITIVE, Block.WATERMARK, Block.VIDEO_MUTE, Block.PDF_LOCK -> "Keep it private"
    Block.READ_TEXT, Block.IDENTIFY, Block.DESCRIBE, Block.READ_CODE, Block.SPEECH_TEXT, Block.PAGE_TEXT, Block.PDF_TEXT -> "Read what's in it"
    Block.CUTOUT, Block.ENHANCE, Block.VIDEO_ROTATE, Block.VIDEO_VERTICAL, Block.VIDEO_CAPTIONS -> "Make it look better"
    Block.PHOTO_PDF, Block.STAMP, Block.TEXT_PDF, Block.PDF_PAGES -> "Paperwork"
    Block.MAKE_TABLE, Block.BUSINESS_CARD, Block.CALENDAR_EVENT, Block.MAKE_QR, Block.CHAT_LINK, Block.CONTACT_QR, Block.WIFI_QR, Block.PASSPORT_PHOTO, Block.VIDEO_STILL, Block.VIDEO_AUDIO, Block.VIDEO_GIF, Block.READ_ALOUD -> "Turn it into something"
    Block.SUMMARIZE, Block.ACTION_ITEMS, Block.SCAM_CHECK, Block.TRANSLATE -> "Understand it"
    Block.CLEAN_TEXT, Block.CLEAN_LINKS, Block.PULL_DETAILS, Block.REWRITE -> "Clean it up"
    Block.PULL_RECEIPT, Block.EXPENSE_ROW, Block.ADD_TO_LIST, Block.RETURN_BY, Block.PRICE_COMPARE -> "Money"
    Block.STICKER, Block.EMOJI_FACES, Block.MEME, Block.EMOJI_MOSAIC, Block.VIDEO_SPEED, Block.VIDEO_LOOP, Block.ART_FILTER, Block.VOICE_CHANGE -> "Just for fun"
}

object BlockGoals {
    val ORDER = listOf("Paperwork", "Make it easy to send", "Keep it private", "Make it look better", "Read what's in it", "Understand it", "Clean it up", "Turn it into something", "Just for fun", "Money")
    /** The given steps under their goals, goals in a fixed order, empty goals left out. */
    fun grouped(blocks: List<Block>): List<Pair<String, List<Block>>> =
        ORDER.mapNotNull { g -> blocks.filter { it.goal == g }.takeIf { it.isNotEmpty() }?.let { g to it } }
    /** Steps that can come first when a tool starts with a photo, or with text. */
    fun starting(kind: Kind): List<Block> = Block.values().filter { kind.feeds(it.takes) }
}

data class Step(val block: Block, val settings: Map<String, String> = emptyMap())

/** The short "how this works" at the top of Build your own. Same three ideas and wording as iOS. */
object BuilderIntro {
    val PAGES = listOf(
        "1. Start with what you have" to "A photo, a scan, a PDF, a video, a recording, a link, some text, something you say, or a contact.",
        "2. Stack small steps" to "Hide private details, shrink it, read it, translate it, sign it. You only see steps that fit, and that your phone can run.",
        "3. Choose how it ends" to "Share it, open an email or WhatsApp ready to send, add a row to a sheet. Add a reminder and it comes back on schedule.",
    )
    const val DEMO_ID = "share-shield"

    /** Starters for what the person has in hand. null shows all of them. */
    fun starters(kind: Kind?, all: List<Chain> = ChainTemplates.all): List<Chain> = if (kind == null) all else all.filter { it.start == kind }
}

/** One thing "Sign and stamp" puts on a page. [x], [y] are the centre and [w] the width, all as fractions of the page. */
data class StampSpot(val mark: String, val x: Double, val y: Double, val w: Double)

/**
 * Where a tool puts your signature, your name and the date. Positions are fractions of the page, so one plan fits every
 * scan of the same form. Same text form as iOS: "sig@0.720,0.880,0.300;date@0.250,0.880,0.220".
 */
object StampPlan {
    const val SIG = "sig"; const val NAME = "name"; const val DATE = "date"
    val MARKS = listOf(SIG, NAME, DATE)
    const val STANDARD = "sig@0.720,0.880,0.300;date@0.250,0.880,0.220"

    fun title(mark: String) = when (mark) { SIG -> "My signature"; NAME -> "My name"; else -> "Today's date" }
    fun short(mark: String) = when (mark) { SIG -> "Signature"; NAME -> "Name"; else -> "Date" }

    /** Where a mark starts before it is moved: signature bottom right, date bottom left, name above the date. */
    fun home(mark: String) = when (mark) {
        SIG -> StampSpot(SIG, 0.72, 0.88, 0.30)
        NAME -> StampSpot(NAME, 0.25, 0.82, 0.30)
        else -> StampSpot(DATE, 0.25, 0.88, 0.22)
    }

    /** Anything malformed is skipped, values are kept on the page, and a mark listed twice counts once. */
    fun parse(text: String): List<StampSpot> {
        val out = ArrayList<StampSpot>()
        for (part in text.split(';')) {
            val bits = part.split('@')
            if (bits.size != 2) continue
            val mark = bits[0].trim()
            if (mark !in MARKS || out.any { it.mark == mark }) continue
            val n = bits[1].split(',').mapNotNull { it.trim().toDoubleOrNull() }
            if (n.size != 3) continue
            out.add(StampSpot(mark, n[0].coerceIn(0.0, 1.0), n[1].coerceIn(0.0, 1.0), n[2].coerceIn(0.08, 0.9)))
        }
        return out
    }

    fun text(spots: List<StampSpot>): String =
        spots.joinToString(";") { "${it.mark}@" + listOf(it.x, it.y, it.w).joinToString(",") { v -> String.format(java.util.Locale.US, "%.3f", v) } }

    fun set(spots: List<StampSpot>, mark: String, on: Boolean): List<StampSpot> = when {
        on && spots.none { it.mark == mark } -> spots + home(mark)
        !on -> spots.filter { it.mark != mark }
        else -> spots
    }

    /** The same plan with one mark moved by a fraction of the page, kept on the page. */
    fun moved(spots: List<StampSpot>, mark: String, dx: Double, dy: Double): List<StampSpot> =
        spots.map { if (it.mark == mark) it.copy(x = (it.x + dx).coerceIn(0.0, 1.0), y = (it.y + dy).coerceIn(0.0, 1.0)) else it }
}

/**
 * Where a tool's result goes when it finishes. "share" (the default) opens the share menu; "mail", "message" and
 * "whatsapp" open that app already filled in with the result attached, so sending is one tap. No app is allowed to
 * send by itself.
 */
data class Finish(val kind: String = "share", val to: String = "") {
    val recipients: List<String> get() = to.split(',', ';', '\n').map { it.trim() }.filter { it.isNotEmpty() }
    val label: String get() {
        val who = when (recipients.size) { 0 -> ""; 1 -> " to ${recipients[0]}"; else -> " to ${recipients.size} people" }
        return when (kind) { "mail" -> "Email it$who"; "message" -> "Message it$who"; "whatsapp" -> "Send on WhatsApp"; "open" -> "Open it"; else -> "Save or share" }
    }
    companion object {
        val KINDS = listOf("share", "mail", "message", "whatsapp", "open")
        fun title(kind: String) = when (kind) { "mail" -> "Email"; "message" -> "Message"; "whatsapp" -> "WhatsApp"; "open" -> "Open"; else -> "Share" }
    }
}

/**
 * When a tool should come back to you: a time of day, and the days it applies. It is a reminder: tap it and the tool
 * opens ready to run. Days are numbered as on iOS and in java.util.Calendar: 1 = Sunday ... 7 = Saturday; empty = every day.
 */
data class Schedule(val hour: Int = 9, val minute: Int = 0, val days: List<Int> = emptyList()) {
    /** Sorted, no repeats, only real weekdays. All seven is the same as every day, so it comes back empty. */
    val cleanDays: List<Int> get() = days.filter { it in 1..7 }.distinct().sorted().let { if (it.size == 7) emptyList() else it }

    /** "Every day at 9:00 AM", "Weekdays at 6:30 PM", "Mon, Thu at 8:00 AM". */
    fun label(uses24h: Boolean = false): String {
        val d = cleanDays
        val names = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        val who = when {
            d.isEmpty() -> "Every day"
            d == listOf(2, 3, 4, 5, 6) -> "Weekdays"
            d == listOf(1, 7) -> "Weekends"
            else -> (d.filter { it != 1 } + d.filter { it == 1 }).joinToString(", ") { names[it - 1] }   // week reads Mon first
        }
        return who + " at " + clock(hour, minute, uses24h)
    }

    /** The next moment this reminder is due, strictly after [from]. */
    fun next(from: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Long {
        val d = cleanDays
        val c = java.util.Calendar.getInstance(zone).apply {
            timeInMillis = from
            set(java.util.Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23)); set(java.util.Calendar.MINUTE, minute.coerceIn(0, 59))
            set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
        }
        if (c.timeInMillis <= from) c.add(java.util.Calendar.DAY_OF_YEAR, 1)
        if (d.isEmpty()) return c.timeInMillis
        repeat(7) {
            if (c.get(java.util.Calendar.DAY_OF_WEEK) in d) return c.timeInMillis
            c.add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        return c.timeInMillis
    }

    companion object {
        fun clock(hour: Int, minute: Int, uses24h: Boolean): String {
            val h = hour.coerceIn(0, 23); val mm = minute.coerceIn(0, 59).toString().padStart(2, '0')
            return if (uses24h) "$h:$mm" else "${if (h % 12 == 0) 12 else h % 12}:$mm ${if (h < 12) "AM" else "PM"}"
        }
    }
}

/**
 * A tool can offer itself when something new lands on the phone: a photo you just took, or a screenshot. Tenzy shows a
 * notification; one tap runs the tool on that picture. (Android only: an iPhone has no way to notice a new photo.)
 */
object AutoRun {
    const val OFF = ""
    const val PHOTO = "photo"
    const val SCREENSHOT = "screenshot"
    val ALL = listOf(OFF, PHOTO, SCREENSHOT)

    fun title(auto: String) = when (auto) { PHOTO -> "New photo"; SCREENSHOT -> "New screenshot"; else -> "Off" }
    fun label(auto: String) = when (auto) { PHOTO -> "Offers itself when you take a photo"; SCREENSHOT -> "Offers itself when you take a screenshot"; else -> "" }

    /** Phones keep screenshots in a Screenshots folder and name them Screenshot_...; either is enough. */
    fun isScreenshot(folder: String, name: String) = folder.contains("screenshot", ignoreCase = true) || name.startsWith("screenshot", ignoreCase = true)

    /** Should a tool set to [auto] offer itself for this new picture? Screenshots and camera photos never cross over. */
    fun wants(auto: String, folder: String, name: String): Boolean = when (auto) {
        PHOTO -> !isScreenshot(folder, name)
        SCREENSHOT -> isScreenshot(folder, name)
        else -> false
    }
}

/** @param combine when several pages or photos go in at once, put every result into one PDF instead of one file each. */
data class Chain(val id: String, val name: String, val steps: List<Step>, val finish: Finish? = null, val combine: Boolean = false,
                 /** What the result file is called, e.g. "Signed form {date}". Empty keeps the plain default. */
                 val fileName: String = "",
                 /** With [combine]: lay every photo out on a single page (both sides of an ID card) instead of a page each. */
                 val onePage: Boolean = false,
                 /** A reminder to run this tool at a set time. null: no reminder. */
                 val schedule: Schedule? = null,
                 /** One of [AutoRun.ALL]: offer this tool when a new photo or screenshot appears. */
                 val auto: String = AutoRun.OFF,
                 /** When several photos go in at once, lay the results out as one picture (a collage) instead of one file each. */
                 val collage: Boolean = false,
                 /** When several photos go in at once, play the results one after another as a single looping GIF. */
                 val gif: Boolean = false,
                 /** Before and after: the first and last of the photos side by side, each with its label. */
                 val versus: Boolean = false) {
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

    /** @param forSharing a shared tool never carries the owner's recipients (someone's email or phone number). */
    fun toJson(forSharing: Boolean = false): JSONObject = JSONObject().put("id", id).put("name", name).put("steps", JSONArray().also { a ->
        // A shared tool never carries a PDF password either.
        steps.forEach { s -> a.put(JSONObject().put("block", s.block.id).put("settings", JSONObject(if (forSharing) s.settings - "password" else s.settings))) }
    }).also { o -> if (collage) o.put("collage", true); if (gif) o.put("gif", true); if (versus) o.put("versus", true); finish?.let { f -> o.put("finish", JSONObject().put("kind", f.kind).put("to", if (forSharing) "" else f.to)) }; if (combine) o.put("combine", true); if (fileName.isNotBlank()) o.put("fileName", fileName); if (onePage) o.put("onePage", true)
        // A shared tool never carries the owner's reminder times.
        if (!forSharing) schedule?.let { w -> o.put("schedule", JSONObject().put("hour", w.hour).put("minute", w.minute).put("days", JSONArray(w.cleanDays))) }
        if (!forSharing && auto.isNotEmpty()) o.put("auto", auto) }

    /** For a one-PDF run each page keeps its picture: the steps without a trailing "Make a PDF", which the join replaces. */
    val stepsPerPage: List<Step> get() = if (combine && steps.lastOrNull()?.block == Block.PHOTO_PDF) steps.dropLast(1) else steps

    val shareText: String get() = PREFIX + toJson(forSharing = true).toString()

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
            val fin = o.optJSONObject("finish")?.let { f -> Finish(f.optString("kind", "share").takeIf { it in Finish.KINDS } ?: "share", f.optString("to", "")) }
            Chain(o.optString("id", UUID.randomUUID().toString()), o.optString("name", "My tool"), steps, fin, o.optBoolean("combine", false), o.optString("fileName", ""), o.optBoolean("onePage", false),
                o.optJSONObject("schedule")?.let { w ->
                    val a = w.optJSONArray("days")
                    Schedule(w.optInt("hour", 9), w.optInt("minute", 0), if (a == null) emptyList() else (0 until a.length()).map { a.optInt(it) })
                },
                o.optString("auto", "").takeIf { it in AutoRun.ALL } ?: AutoRun.OFF,
                o.optBoolean("collage", false), o.optBoolean("gif", false), o.optBoolean("versus", false))
        } catch (_: Exception) { null }

        /** Accepts a copied tool only if it is well formed and its steps fit together. */
        fun imported(text: String): Chain? {
            val t = text.trim()
            if (!t.startsWith(PREFIX)) return null
            val c = try { fromJson(JSONObject(t.removePrefix(PREFIX))) } catch (_: Exception) { null } ?: return null
            if (c.steps.size > 12 || c.problem() != null) return null
            return c.copy(id = UUID.randomUUID().toString(), schedule = null, auto = AutoRun.OFF)   // a pasted tool never arrives with reminders or auto-offers switched on
        }

        fun blank() = Chain(UUID.randomUUID().toString(), "", emptyList())
    }
}

/** What a shared or picked thing is, from its type: a photo, a video, a recording, a PDF, or (with no file) text. Null for a file no tool takes. */
fun kindOf(mime: String?, hasText: Boolean): Kind? = when {
    mime == null -> if (hasText) Kind.TEXT else null
    mime.startsWith("image/") -> Kind.IMAGE
    mime.startsWith("video/") -> Kind.VIDEO
    mime.startsWith("audio/") -> Kind.AUDIO
    mime == "application/pdf" -> Kind.PDF
    mime.startsWith("text/") && hasText -> Kind.TEXT
    else -> if (hasText) Kind.TEXT else null
}

/** What "Share to Tenzy" offers for a shared photo or text: the user's own tools first, then the starters, last-used on top. */
object ChainOffers {
    fun forKind(kind: Kind, mine: List<Chain>, last: String?): List<Chain> {
        val all = (mine + ChainTemplates.all).filter { it.steps.isNotEmpty() && it.steps.first().block.takes == kind && it.problem(kind) == null }.toMutableList()
        val i = all.indexOfFirst { it.id == last }
        if (i > 0) all.add(0, all.removeAt(i))
        return all
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
        Chain("scam-check", "Is this message a scam?", listOf(Step(Block.SCAM_CHECK))),
        Chain("clean-link", "Link without the tracking", listOf(Step(Block.CLEAN_LINKS))),
        Chain("photo-to-pdf", "Photo to PDF", listOf(Step(Block.PHOTO_PDF))),
        Chain("text-to-qr", "Text or link to QR code", listOf(Step(Block.MAKE_QR))),
        Chain("scan-to-pdf", "Scan pages into one PDF", listOf(Step(Block.PHOTO_PDF)), combine = true),
        Chain("sign-and-send", "Sign a form and send it", listOf(Step(Block.STAMP, mapOf("marks" to StampPlan.STANDARD)), Step(Block.PHOTO_PDF)),
            finish = Finish("mail", ""), combine = true, fileName = "Signed form {date}"),
        Chain("receipt-run", "Receipt into this month's expense sheet", listOf(Step(Block.READ_TEXT), Step(Block.EXPENSE_ROW), Step(Block.ADD_TO_LIST, mapOf("list" to TextTidy.DEFAULT_LIST)))),
        Chain("whatsapp-no-save", "WhatsApp a number without saving it", listOf(Step(Block.CHAT_LINK)), finish = Finish("open")),
        Chain("contact-qr", "My contact as a QR code", listOf(Step(Block.CONTACT_QR))),
        Chain("video-email", "Video under 25 MB for email", listOf(Step(Block.VIDEO_SHRINK, mapOf("mb" to "25"))), finish = Finish("mail", "")),
        Chain("video-chat", "Video small enough for chat (16 MB)", listOf(Step(Block.VIDEO_SHRINK, mapOf("mb" to "16")))),
        Chain("video-still", "Grab a still from a video", listOf(Step(Block.VIDEO_STILL))),
        Chain("video-quiet", "Video without its sound", listOf(Step(Block.VIDEO_MUTE))),
        Chain("return-by", "Receipt to a return-by reminder", listOf(Step(Block.READ_TEXT), Step(Block.RETURN_BY, mapOf("days" to "30")))),
        Chain("wifi-sign", "Wi-Fi sign to a code guests scan", listOf(Step(Block.READ_TEXT), Step(Block.WIFI_QR))),
        Chain("what-is-this", "What is this?", listOf(Step(Block.IDENTIFY))),
        Chain("passport-photo", "Passport photo", listOf(Step(Block.PASSPORT_PHOTO, mapOf("country" to "us")))),
        Chain("shelf-best-deal", "Shelf photo to best deal", listOf(Step(Block.READ_TEXT), Step(Block.PRICE_COMPARE))),
        Chain("sticker", "Cut out a subject", listOf(Step(Block.CUTOUT))),
        Chain("id-both-sides", "Both sides of an ID on one page", listOf(Step(Block.WATERMARK, mapOf("text" to "For verification only"))), combine = true, onePage = true),
        Chain("share-shield", "Privacy share shield", listOf(Step(Block.HIDE_SENSITIVE), Step(Block.STRIP_LOCATION), Step(Block.SHRINK, mapOf("mb" to "2")))),
        Chain("id-copy-watermarked", "ID copy with a safety watermark", listOf(Step(Block.WATERMARK, mapOf("text" to "For verification only")), Step(Block.STRIP_LOCATION))),
        Chain("portal-photo", "Portal photo: 35x45 mm under 50 KB", listOf(Step(Block.RESIZE_PHOTO, mapOf("size" to "413x531")), Step(Block.SHRINK, mapOf("mb" to "0.05")))),
        Chain("memo-to-notes", "Voice memo to written notes", listOf(Step(Block.SPEECH_TEXT), Step(Block.CLEAN_TEXT))),
        Chain("memo-to-tasks", "Meeting recording to task list", listOf(Step(Block.SPEECH_TEXT), Step(Block.ACTION_ITEMS))),
        Chain("qr-safe", "Is this QR code safe?", listOf(Step(Block.READ_CODE), Step(Block.SCAM_CHECK))),
        Chain("sign-to-english", "Sign or menu photo to English", listOf(Step(Block.READ_TEXT), Step(Block.TRANSLATE, mapOf("to" to "en")))),
        Chain("page-to-pdf", "Web page to a clean PDF", listOf(Step(Block.PAGE_TEXT), Step(Block.TEXT_PDF))),
        Chain("page-summary", "Web page to 3 sentences", listOf(Step(Block.PAGE_TEXT), Step(Block.SUMMARIZE, mapOf("sentences" to "3")))),
        Chain("listen-later", "Text to an audio file", listOf(Step(Block.READ_ALOUD))),
        Chain("pdf-email", "PDF under 5 MB for email", listOf(Step(Block.PDF_SHRINK, mapOf("mb" to "5"))), finish = Finish("mail", "")),
        Chain("pdf-join", "Join PDFs into one", listOf(Step(Block.PDF_PAGES, mapOf("pages" to ""))), combine = true),
        Chain("pdf-first-page", "Just the first page of a PDF", listOf(Step(Block.PDF_PAGES, mapOf("pages" to "1")))),
        Chain("video-story", "First 30 seconds, cropped tall", listOf(Step(Block.VIDEO_TRIM, mapOf("side" to "first", "secs" to "30")), Step(Block.VIDEO_VERTICAL))),
        Chain("video-gif", "Video to a GIF", listOf(Step(Block.VIDEO_GIF))),
        Chain("video-words", "What was said in a video", listOf(Step(Block.VIDEO_AUDIO), Step(Block.SPEECH_TEXT))),
        Chain("photo-collage", "Photos into one collage", listOf(Step(Block.STRIP_LOCATION)), collage = true),
        Chain("where-i-am", "Send where I am", listOf(Step(Block.CLEAN_TEXT)), finish = Finish("message", "")),
        Chain("photos-gif", "Photos into a GIF", listOf(Step(Block.STRIP_LOCATION)), gif = true),
        Chain("sticker-maker", "Photo to a sticker", listOf(Step(Block.STICKER))),
        Chain("emoji-faces", "Emoji over every face", listOf(Step(Block.EMOJI_FACES, mapOf("emoji" to TextTidy.FACE_EMOJIS[0])))),
        Chain("meme", "Make a meme", listOf(Step(Block.MEME, mapOf("top" to "", "bottom" to "")))),
        Chain("emoji-mosaic", "Photo made of emojis", listOf(Step(Block.EMOJI_MOSAIC))),
        Chain("video-boomerang", "Boomerang GIF from a video", listOf(Step(Block.VIDEO_LOOP, mapOf("style" to "boomerang")))),
        Chain("video-slowmo", "Slow-motion video", listOf(Step(Block.VIDEO_SPEED, mapOf("speed" to "slow")))),
        Chain("video-fast", "Speed a video up", listOf(Step(Block.VIDEO_SPEED, mapOf("speed" to "fast")))),
        Chain("photo-sketch", "Photo to a pencil sketch", listOf(Step(Block.ART_FILTER, mapOf("style" to "sketch")))),
        Chain("photo-comic", "Photo to a comic", listOf(Step(Block.ART_FILTER, mapOf("style" to "comic")))),
        Chain("voice-chipmunk", "Chipmunk voice", listOf(Step(Block.VOICE_CHANGE, mapOf("voice" to "chipmunk")))),
        Chain("voice-deep", "Deep voice", listOf(Step(Block.VOICE_CHANGE, mapOf("voice" to "deep")))),
        Chain("video-voice", "Funny voice from a video", listOf(Step(Block.VIDEO_AUDIO), Step(Block.VOICE_CHANGE, mapOf("voice" to "chipmunk")))),
        Chain("before-after", "Before and after, side by side", listOf(Step(Block.STRIP_LOCATION)), versus = true),
    )
}

/** "Describe it": a sentence in, a list of existing blocks out, checked before anyone sees it. */
object ChainPlanner {
    /** The tool a sentence asks for, whatever its spelling. Null when it names nothing Tenzy works with. */
    fun plan(ask: String): Chain? = guess(ask)?.first

    /**
     * The tool for a sentence, and whether the sentence said enough to be sure of it. When it is not sure, the tool
     * is the closest sensible one: a starter that shares a word with the request, or the most useful tool for the
     * kind of thing mentioned.
     */
    fun guess(ask: String): Pair<Chain, Boolean>? {
        val clean = PlannerWords.tidy(ask)
        val ruled = rules(clean)
        var c = ruled ?: fallback(clean) ?: return null
        val sure = ruled != null
        if (c.finish == null) c = c.copy(finish = ending(clean))
        // A short request is its own best name; a long one gets a name from what the tool does. A starter keeps its name.
        if (sure || c.name.isEmpty()) c = c.copy(name = toolName(ask, c))
        return c to sure
    }

    /** "…and email it" / "…then text it": how the tool should end, when the sentence says. Null leaves it at Save or share. */
    fun ending(clean: String): Finish? {
        val s = " $clean "
        fun has(vararg w: String) = w.any { s.contains(it) }
        if (has("email") && !has("email address", "emails", "email and phone", "find the email")) return Finish("mail", "")
        if (has("text it", "message it", "imessage", " sms", "by text", "as a message", "send a message")) return Finish("message", "")
        return null
    }

    /** When no rule fits. Null only when the request names nothing Tenzy works with. */
    fun fallback(clean: String): Chain? {
        val s = " $clean "
        fun has(vararg w: String) = w.any { s.contains(it) }
        val words = PlannerWords.words(clean).filter { it.length >= 4 && it !in PlannerWords.PLAIN }
        var best: Chain? = null; var bestScore = 0
        for (t in ChainTemplates.all) {
            val name = PlannerWords.words(t.name.lowercase())
            val score = words.count { w -> name.any { n -> n == w || (n.length >= 5 && w.length >= 5 && PlannerWords.distance(n, w, 1) <= 1) } }
            if (score > bestScore) { best = t; bestScore = score }
        }
        best?.let { return it.copy(id = UUID.randomUUID().toString()) }
        val steps = when {
            has("photo", "picture", "image", "screenshot", "selfie") -> listOf(Step(Block.STRIP_LOCATION), Step(Block.SHRINK, mapOf("mb" to "2")))
            has("http", "www.", "link", " url") -> listOf(Step(Block.CLEAN_LINKS))
            has("text", "notes", "words", "message", "paragraph", "essay", "letter") -> listOf(Step(Block.CLEAN_TEXT))
            else -> return null
        }
        return Chain(UUID.randomUUID().toString(), "", steps)
    }

    /** A short name for a tool nobody has named: a starter's name when the steps are a starter's, otherwise the steps themselves. */
    fun autoName(chain: Chain): String {
        val blocks = chain.steps.map { it.block }
        if (blocks.isEmpty()) return "My tool"
        ChainTemplates.all.firstOrNull { t -> t.steps.map { it.block } == blocks }?.let { return it.name }
        return when (blocks.size) { 1 -> blocks[0].title; 2 -> blocks[0].title + " + " + blocks[1].title; else -> blocks[0].title + " + ${blocks.size - 1} more" }
    }
    /** The name "Describe it" gives a tool: the request itself when it is short enough to read as a name, otherwise [autoName]. */
    fun toolName(ask: String, chain: Chain): String {
        val t = ask.trim().replace("\n", " ")
        return if (t.isEmpty() || t.length > 28) autoName(chain) else t.take(1).uppercase() + t.drop(1)
    }
    /** What a tool is saved as: the name typed, or [autoName] when it was left empty or as "My tool". */
    fun savedName(chain: Chain): String = chain.name.trim().let { if (it.isEmpty() || it == "My tool") autoName(chain) else it }

    /** The rules themselves, read from a sentence whose spelling has already been tidied. */
    fun rules(ask: String): Chain? {
        val s = " " + ask.lowercase() + " "
        fun has(vararg w: String) = w.any { s.contains(it) }
        val name = ask.trim().replace("\n", " ").replaceFirstChar { it.uppercase() }.let { if (it.length > 34) it.take(32) + "…" else it }
        fun made(steps: List<Step>, combine: Boolean = false): Chain? =
            Chain(UUID.randomUUID().toString(), name, steps.take(8), combine = combine).takeIf { steps.isNotEmpty() && it.problem() == null }

        // Just for fun. These requests name exactly what they want, so they are read before anything else.
        val film = has("video", " clip", "movie", "footage", "live photo")
        if (has("boomerang")) return made(listOf(Step(Block.VIDEO_LOOP, mapOf("style" to "boomerang"))))
        if (has("reverse", "backwards", "backward") && (film || has(" gif"))) return made(listOf(Step(Block.VIDEO_LOOP, mapOf("style" to "reverse"))))
        if (has("slow mo", "slow-mo", "slowmo", "slow motion", "slow it down", "slow down", "half speed")) return made(listOf(Step(Block.VIDEO_SPEED, mapOf("speed" to "slow"))))
        if (has("speed up", "speed it up", "sped up", "timelapse", "time lapse", "time-lapse", "fast forward", "double speed", " 2x", " 4x") || (film && has("faster"))) {
            return made(listOf(Step(Block.VIDEO_SPEED, mapOf("speed" to if (has(" 4x", "four times", "timelapse", "time lapse", "time-lapse")) "faster" else "fast"))))
        }
        if (has("meme")) return made(listOf(Step(Block.MEME, mapOf("top" to "", "bottom" to ""))))
        if (has("sticker")) return made(listOf(Step(Block.STICKER)))
        if (has("mosaic") || (has("emoji") && has("made of", "out of", "made from", "rebuild", " art "))) return made(listOf(Step(Block.EMOJI_MOSAIC)))
        if (has("emoji", "smiley")) return made(listOf(Step(Block.EMOJI_FACES, mapOf("emoji" to TextTidy.FACE_EMOJIS[0]))))
        if (has("before and after", "before/after", "before after", "side by side")) return made(listOf(Step(Block.STRIP_LOCATION)))?.copy(versus = true)
        if (has("chipmunk", "helium", "voice changer", "funny voice", "deep voice", "change my voice", "change the voice")) {
            return made((if (film) listOf(Step(Block.VIDEO_AUDIO)) else emptyList()) + Step(Block.VOICE_CHANGE, mapOf("voice" to if (has("deep", "giant", "low voice")) "deep" else "chipmunk")))
        }
        if (has("sketch", "pencil", "drawing", "cartoon", "comic", "pop art", "black and white", "noir")) {
            val style = if (has("cartoon", "comic")) "comic" else if (has("pop art")) "pop" else if (has("black and white", "noir")) "noir" else "sketch"
            return made(listOf(Step(Block.ART_FILTER, mapOf("style" to style))))
        }
        if (has(" gif", "slideshow", "slide show") && !has("video", " clip", "movie", "footage")) {
            // A Live Photo carries a short video; several photos play one after another.
            if (has("live photo")) return made(listOf(Step(Block.VIDEO_GIF)))
            return made(listOf(Step(Block.STRIP_LOCATION)))?.copy(gif = true)
        }

        // A recording: write out what was said, then whatever else was asked for.
        if (has("voice memo", "recording", "transcribe", "transcript", "what was said", "speech to text", "audio to text")) {
            val a = ArrayList<Step>()
            if (has("video", " clip", "movie", "footage")) a.add(Step(Block.VIDEO_AUDIO))
            a.add(Step(Block.SPEECH_TEXT))
            if (has("task", "to-do", "todo", "action item")) a.add(Step(Block.ACTION_ITEMS))
            else if (has("summar", "key points", "gist")) a.add(Step(Block.SUMMARIZE, mapOf("sentences" to "3")))
            return made(a)
        }

        // Video jobs come first: a video takes its own steps, never the photo ones.
        if (has("video", " clip", "movie", "footage")) {
            val v = ArrayList<Step>()
            when {
                has("caption", "subtitle") -> v.add(Step(Block.VIDEO_CAPTIONS))
                has(" gif") -> v.add(Step(Block.VIDEO_GIF))
                has("still", "frame", "thumbnail") -> v.add(Step(Block.VIDEO_STILL))
                has("audio only", "just the audio", "only the sound", "just the sound", "extract audio", "extract the audio", "as audio", "mp3") -> v.add(Step(Block.VIDEO_AUDIO))
                else -> {
                    if (has("trim", "seconds", " secs", "first part", "last part", "cut the")) {
                        v.add(Step(Block.VIDEO_TRIM, mapOf("side" to if (has("last ", "the end")) "last" else "first", "secs" to (number(s, "second", "sec") ?: 30).toString())))
                    }
                    if (has("rotate", "sideways", "upside down", "right way up")) {
                        v.add(Step(Block.VIDEO_ROTATE, mapOf("turn" to if (has("upside down")) "flip" else if (has(" left")) "left" else "right")))
                    }
                    if (has("vertical", "portrait", "9:16", " tall", "story", "stories", "reel", "tiktok")) v.add(Step(Block.VIDEO_VERTICAL))
                    if (has("mute", "no sound", "without sound", "without its sound", "remove the sound", "remove sound", "silent")) v.add(Step(Block.VIDEO_MUTE))
                    if (v.isEmpty() || has("shrink", "smaller", "compress", "reduce", "under ", " mb", "email", "whatsapp", "send", "size")) {
                        val mb = Regex("""(\d+)\s*(?:mb|megabyte)""").find(s)?.groupValues?.get(1)?.toIntOrNull()?.takeIf { it > 0 } ?: if (has("whatsapp", "chat")) 16 else 25
                        v.add(Step(Block.VIDEO_SHRINK, mapOf("mb" to mb.toString())))
                    }
                }
            }
            val t = ask.trim().replace("\n", " ").replaceFirstChar { it.uppercase() }
            return Chain(UUID.randomUUID().toString(), if (t.length > 34) t.take(32) + "…" else t, v)
        }
        // Jobs that start from a PDF (a photo turned into a PDF is handled further down).
        if (has("pdf") && !has("photo", "picture", "image", "scan", "screenshot", "receipt", "web page", "webpage", "article", "link", "text to", "form")) {
            if (has("words", "text from", "text out", "copy the text", "read the pdf")) return made(listOf(Step(Block.PDF_TEXT)))
            val p = ArrayList<Step>()
            val join = has("merge", "join", "combine", "into one")
            if (join || has("page ", "pages", "split", "extract")) p.add(Step(Block.PDF_PAGES, mapOf("pages" to if (!join && has("first page")) "1" else "")))
            if (has("shrink", "smaller", "compress", "reduce", "under ", " mb", "email")) p.add(Step(Block.PDF_SHRINK, mapOf("mb" to (number(s, "mb", "megabyte") ?: 5).toString())))
            if (has("password", "lock", "protect", "encrypt")) p.add(Step(Block.PDF_LOCK, mapOf("password" to "")))
            if (p.isNotEmpty()) return made(p, combine = join)
        }

        val wantsPhoto = has("photo", "picture", "image", "scan", "screenshot", "snap", "camera", "receipt", "card", "poster", "flyer", "whiteboard", "sign ")

        // Translating: read the words first when a picture is meant.
        if (has("translat")) {
            val to = TextTidy.LANGUAGES.firstOrNull { (_, n) -> s.contains(" " + n.lowercase()) && !s.contains("from " + n.lowercase()) }?.first ?: "en"
            return made((if (wantsPhoto || has("menu")) listOf(Step(Block.READ_TEXT)) else emptyList()) + Step(Block.TRANSLATE, mapOf("to" to to)))
        }
        // A web page: keep its words, then make a PDF, a summary or an audio file of them.
        if (has("web page", "webpage", "article", "website")) {
            val w = arrayListOf(Step(Block.PAGE_TEXT))
            if (has("pdf")) w.add(Step(Block.TEXT_PDF))
            else if (has("summar", "gist", "key points", "shorten")) w.add(Step(Block.SUMMARIZE, mapOf("sentences" to "3")))
            else if (has("read aloud", "listen", "audio")) w.add(Step(Block.READ_ALOUD))
            return made(w)
        }
        if (has("read aloud", " aloud", "read out", "listen to", "text to speech", "audio file")) {
            return made((if (wantsPhoto) listOf(Step(Block.READ_TEXT)) else emptyList()) + Step(Block.READ_ALOUD))
        }
        // Reading a code (making one is handled below).
        if (has("qr", "barcode") && has("read ", "scan ", "what does", "safe", "decode") && !has("wifi", "wi-fi", "make ", "create", "turn ", "into a qr", "to qr", "to a qr")) {
            return made(listOf(Step(Block.READ_CODE)) + (if (has("safe", "scam")) listOf(Step(Block.SCAM_CHECK)) else emptyList()))
        }
        if (has("rewrite", "reword", "rephrase", "more formal", "friendlier", "more polite")) {
            val style = if (has("formal", "polite", "professional")) "formal" else if (has("friendl", "warm")) "friendly" else if (has("short", "brief")) "short" else "clear"
            return made(listOf(Step(Block.REWRITE, mapOf("style" to style))))
        }

        // "Tidy up this photo" is about the picture, so tidying only means text when text is what is being talked about.
        val textish = has("text", "notes", "words", "list", "lines", "pasted", "paste")
        val wantsClean = has("tidy", "clean up", "clean the", "dedupe", "de-dupe", "duplicate line", "remove duplicates", "extra spaces", "blank lines") && (!wantsPhoto || textish)
        val job: Block? = when {
            has("scam", "phishing", "fraud", "is this real", "suspicious") -> Block.SCAM_CHECK
            has("best deal", "cheapest", "cheaper", "unit price", "per unit", "better value") -> Block.PRICE_COMPARE
            has("tracking", "clean link", "clean the link", "clean my link", "utm") -> Block.CLEAN_LINKS
            has("wifi", "wi-fi") -> Block.WIFI_QR
            has("qr") -> Block.MAKE_QR
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
        // A running sheet: each receipt becomes one row added to the same list.
        if (has("expense sheet", "expense log", "ledger", "running list", "running sheet", "monthly sheet")) {
            if (wantsPhoto || has("receipt")) steps.add(Step(Block.READ_TEXT))
            steps.add(Step(Block.EXPENSE_ROW)); steps.add(Step(Block.ADD_TO_LIST, mapOf("list" to TextTidy.DEFAULT_LIST)))
            return finish(ask, steps)
        }
        if (job != null || wantsClean) {
            val needsPhoto = wantsPhoto || job == Block.PULL_RECEIPT || job == Block.BUSINESS_CARD || job == Block.CALENDAR_EVENT
            if (needsPhoto) steps.add(Step(Block.READ_TEXT))
            // Tidying goes first so the next step sees clean text.
            if (wantsClean) steps.add(Step(Block.CLEAN_TEXT))
            if (job != null) steps.add(if (job == Block.SUMMARIZE) Step(job, mapOf("sentences" to (number(s, "sentence", "line", "point") ?: 3).toString())) else Step(job))
            return finish(ask, steps)
        }
        // Questions about a picture: the answer is words, so nothing else follows.
        if (has("identify", "what is this", "what's this", "what plant", "what bug", "what breed", "what kind of")) return finish(ask, listOf(Step(Block.IDENTIFY)))
        if (has("describe", "what's in", "what is in", "what does it show")) return finish(ask, listOf(Step(Block.DESCRIBE)))

        // Picture jobs, in the order that gives the best result.
        if (has("cut out", "cutout", "remove background", "remove the background", "background", "isolate")) steps.add(Step(Block.CUTOUT))
        if (has("enhance", "sharpen", "improve", "fix the photo", "better quality", "clearer", "brighten")) steps.add(Step(Block.ENHANCE))
        if (has("blur", "hide", "redact", "private", "faces", "face ", "anonym", "censor", "personal", "sensitive", "confidential", "identity")) steps.add(Step(Block.HIDE_SENSITIVE))
        if (has("passport", "id photo", "visa photo", "headshot size")) steps.add(Step(Block.PASSPORT_PHOTO, mapOf("country" to "us")))
        if (has("watermark")) steps.add(Step(Block.WATERMARK, mapOf("text" to "For verification only")))
        // Posting a photo, or taking the personal details out of it, also means leaving behind where it was taken.
        val posting = has(" post", "social", "instagram", "facebook", "online", "publicly")
        if (posting || has("location", "gps", "exif", "metadata", "safe to share", "safe-to-share", "strip", "personal", "sensitive", "confidential")) steps.add(Step(Block.STRIP_LOCATION))
        if (has("35x45", "35 x 45", "pixels", "pixel size", " px")) steps.add(Step(Block.RESIZE_PHOTO, mapOf("size" to if (has("35x45", "35 x 45")) "413x531" else "600x600")))
        if (has("png", "jpg", "jpeg", "convert", "format")) steps.add(Step(Block.CONVERT, mapOf("format" to if (s.contains("png")) "PNG" else "JPG")))
        if (posting || has("shrink", "smaller", "compress", "reduce", "under ", " mb", " kb", "email", "upload", "size")) {
            // "under 50 kb" is common for upload forms; a kilobyte figure wins over the megabyte default.
            val kb = number(s, "kb", "kilobyte")
            steps.add(Step(Block.SHRINK, mapOf("mb" to if (kb != null) (kb / 1000.0).toString() else (number(s, "mb", "megabyte") ?: 2).toString())))
        }
        // A PDF comes last: it takes whatever the photo has become.
        if (has("pdf")) steps.add(Step(Block.PHOTO_PDF))
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

/**
 * Makes sense of what was typed before the rules read it: fixes misspelt words it knows and expands short forms, so
 * "shrnk my foto" reads as "shrink my photo". Everything else (numbers, punctuation, words it doesn't know) is left
 * exactly as written. Pure, and the same lists and rules as iOS.
 */
object PlannerWords {
    val SHORT = mapOf("pic" to "photo", "pics" to "photos", "img" to "image", "foto" to "photo", "fotos" to "photos", "vid" to "video", "vids" to "videos", "msg" to "message", "pwd" to "password")

    /** Words the rules look for. A typed word close to exactly one of these is taken to be it. */
    val VOCAB: Set<String> = ("photo photos picture pictures image images scan screenshot camera receipt receipts card poster flyer whiteboard video videos clip movie footage still frame " +
        "thumbnail audio sound mute silent shrink smaller compress reduce under email whatsapp send size caption captions subtitle subtitles trim seconds rotate sideways " +
        "upside vertical portrait story stories reel tiktok merge join combine pages page split extract password lock protect encrypt words translate translation webpage " +
        "article website link links aloud listen speech barcode read safe decode rewrite reword rephrase formal friendlier polite professional scam phishing fraud " +
        "suspicious deal cheapest cheaper tracking wifi expense expenses invoice business contact contacts vcard calendar event invite appointment spreadsheet excel " +
        "table columns urls address number numbers task tasks todo checklist action summarize summarise summary shorten gist points tidy clean clear dedupe duplicate " +
        "duplicates spaces blank lines identify describe cutout background sticker isolate enhance sharpen improve quality clearer brighten blur hide redact private " +
        "faces anonymous censor passport visa headshot watermark location metadata strip pixels pixel convert format upload voice memo recording transcribe transcript " +
        "collage personal sensitive confidential identity details data date information post posting social instagram facebook online share remove delete signature " +
        "sign stamp text notes message messages list pasted paste sheet ledger running monthly return plant breed menu document documents file files kilobyte megabyte " +
        "sentence sentences letter paragraph essay record quiet crop tall wide turn first last start keep english spanish french german italian portuguese hindi arabic " +
        "chinese japanese korean russian turkish dutch polish indonesian vietnamese thai ukrainian boomerang reverse backwards motion slowmo speed faster timelapse meme memes stickers emoji emojis mosaic slideshow funny sketch pencil drawing cartoon comic chipmunk helium comparison black white").split(" ").toSet()

    /** Ordinary words that sit one letter away from a word above and must never be "corrected" into it. */
    val REAL: Set<String> = ("carton cosmic spend fasten notion store phone strap plane plate price point their there where which about would could should these those other after before every later thing things something anything everything people person month today tomorrow title state place right light night great small large please thanks really always never maybe while without within between through because again being doing going having making taking getting using wants wanted needs needed friend friends family client clients office house school second flame world paper print").split(" ").toSet()

    /** Words too general to tell one starter from another. */
    val PLAIN: Set<String> = ("photo photos picture pictures image images text video videos into from with that this your mine make turn want need have please some them then just only also file files thing something anything notes words page pages link links code list sheet").split(" ").toSet()

    /** The sentence in lower case with each misspelt word it recognises put right. Nothing else changes. */
    fun tidy(ask: String): String {
        val out = StringBuilder(); val word = StringBuilder()
        for (ch in ask.lowercase()) {
            if (ch in 'a'..'z') word.append(ch) else { out.append(fix(word.toString())); word.setLength(0); out.append(ch) }
        }
        return out.append(fix(word.toString())).toString()
    }

    /** The words of a sentence: runs of letters, lower case. */
    fun words(text: String): List<String> = text.lowercase().split(Regex("[^a-z]+")).filter { it.isNotEmpty() }

    /**
     * One word put right: a short form spelt out, or a word of five letters or more that is one slip (two for long
     * words) away from exactly one known word starting with the same letter. An "-ing", "-ed" or "-s" ending is tried
     * without it too. Anything else comes back unchanged.
     */
    fun fix(w: String): String {
        SHORT[w]?.let { return it }
        if (w.length < 5 || w in VOCAB || w in REAL) return w
        nearest(w)?.let { return it }
        for (ending in listOf("ing", "ed", "es", "s")) {
            if (!w.endsWith(ending) || w.length - ending.length < 5) continue
            val stem = w.dropLast(ending.length)
            if (stem in VOCAB) return w
            nearest(stem)?.let { return it }
        }
        return w
    }

    private fun nearest(w: String): String? {
        val reach = if (w.length >= 8) 2 else 1
        var best: String? = null; var bestD = reach + 1; var tie = false
        for (v in VOCAB) {
            if (v[0] != w[0] || Math.abs(v.length - w.length) > reach) continue
            val d = distance(w, v, reach)
            if (d < bestD) { best = v; bestD = d; tie = false } else if (d == bestD && d <= reach) tie = true
        }
        return if (tie) null else best
    }

    /**
     * How many slips apart two words are: a wrong, missing or extra letter, or two neighbours swapped, each count one.
     * Anything over [limit] comes back as limit + 1.
     */
    fun distance(a: String, b: String, limit: Int): Int {
        if (Math.abs(a.length - b.length) > limit) return limit + 1
        if (a.isEmpty()) return minOf(b.length, limit + 1)
        if (b.isEmpty()) return minOf(a.length, limit + 1)
        val d = Array(a.length + 1) { IntArray(b.length + 1) }
        for (i in 0..a.length) d[i][0] = i
        for (j in 0..b.length) d[0][j] = j
        for (i in 1..a.length) for (j in 1..b.length) {
            val cost = if (a[i - 1] == b[j - 1]) 0 else 1
            d[i][j] = minOf(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) d[i][j] = minOf(d[i][j], d[i - 2][j - 2] + 1)
        }
        return minOf(d[a.length][b.length], limit + 1)
    }
}

/**
 * A tool as a link or a QR code. The whole tool rides in the part of the link after "#", which a browser never sends
 * to the website, so the page that opens it learns nothing about the tool.
 */
object ToolLink {
    /** The page below is published (12 Nov 2026), so link and QR sharing are offered. Set this to false to hide them again. */
    const val LIVE = true
    const val PAGE = "https://manan99991.github.io/tenzy/t.html"

    /** The link for a tool. It never carries recipients, reminder times or a PDF password (see [Chain.shareText]). */
    fun link(chain: Chain): String =
        PAGE + "#" + java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(chain.shareText.removePrefix(Chain.PREFIX).toByteArray(Charsets.UTF_8))

    /**
     * The tool in a link from [link], in the "tenzy://import?d=..." form the page hands to the app, or in copied tool
     * text. Null for anything else, or for a tool whose steps don't fit together.
     */
    fun chain(link: String): Chain? {
        val t = link.trim()
        if (t.startsWith(Chain.PREFIX)) return Chain.imported(t)
        val packed = when {
            t.startsWith(PAGE) && t.contains('#') -> t.substringAfter('#')
            t.startsWith("tenzy://import") && t.contains("d=") -> t.substringAfter("d=")
            else -> return null
        }.substringBefore('&')
        val json = try { String(java.util.Base64.getUrlDecoder().decode(packed), Charsets.UTF_8) } catch (_: Exception) { return null }
        return Chain.imported(Chain.PREFIX + json)
    }
}
