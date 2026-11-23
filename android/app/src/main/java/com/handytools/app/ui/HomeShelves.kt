package com.handytools.app.ui

import android.content.Context

/**
 * Home's tabs, the same design as the iPhone (Manan, 23 Nov: "make sure nothing is missing from the home page"; UX
 * audit decisions 1–4): a row of tabs all on screen at once (no sideways scrolling), and the tab you pick shows every
 * one of its tools as its own tile, named for the job ("Scan a document", not "Docs & Capture"), at most nine so a tab
 * always fits. Every Android tool sits in exactly one tab. Business shows only for people who say they run one.
 * Pure, so a unit test proves nothing built is missing from Home.
 */
object HomeShelves {
    data class Shelf(val id: String, val title: String, val line: String, val tools: List<String>)

    const val MAX_PER_TAB = 9

    /** Android's tabs. Same ids and words as the iPhone where the tools match; Android has its own mix of tools,
     *  so Photos and video share a tab and Files holds the file tools. */
    val all: List<Shelf> = listOf(
        Shelf("camera", "Camera", "Point your camera at something",
            listOf("docs", "identify", "procam", "codes", "scancsv", "colorvision")),
        Shelf("photos", "Photos", "Fix, shrink and share photos and videos",
            listOf("media", "scrubber", "stitch", "gifmaker", "memory")),
        Shelf("files", "Files", "Open, convert and send any file",
            listOf("fileviewer", "converter", "share")),
        Shelf("audio", "Sound", "Record, listen and sleep",
            listOf("voice", "rest", "hearing")),
        Shelf("words", "Words", "Translate, read aloud, check and plan",
            listOf("translate", "lens", "safety", "texttools", "thinking")),
        // No Alarm tile: that tool was cut on 2 Nov (Google reserves exact alarms for alarm apps), so its screen
        // can't ring. Timers runs only while open, so it isn't offered either.
        Shelf("day", "My day", "Medicines, your morning, bills, receipts and cards",
            listOf("medreminder", "brief", "sorted", "receipts", "pricecheck", "wallet")),
        Shelf("phone", "Phone", "Space, battery, network, light and your car",
            listOf("cleanup", "storage", "myphone", "network", "instruments", "flashlight", "quick", "parked", "gpsdash")),
    )

    /** What each tile says: the job, in the words people search with. Matches the iPhone's names where it can. */
    val jobNames: Map<String, String> = mapOf(
        "docs" to "Scan a document", "identify" to "What is this?", "procam" to "Take better photos",
        "codes" to "Scan a QR code", "scancsv" to "Copy a table", "colorvision" to "Tell colors apart",
        "media" to "Shrink or cut out", "scrubber" to "Hide faces and location", "stitch" to "Join screenshots",
        "gifmaker" to "Make a GIF", "memory" to "Find a photo",
        "fileviewer" to "Open any file", "converter" to "Change a file's format", "share" to "Send files nearby",
        "voice" to "Record and transcribe", "rest" to "Sleep sounds", "hearing" to "Hear better",
        "translate" to "Translate anything", "lens" to "Read it aloud", "safety" to "Is this a scam?",
        "texttools" to "Fix up text", "thinking" to "Plan my day",
        "medreminder" to "Medicine reminders", "brief" to "Morning summary", "sorted" to "Track a bill", "receipts" to "Keep receipts", "pricecheck" to "Compare prices",
        "wallet" to "Keep my cards",
        "cleanup" to "Free up space", "storage" to "See what's using space", "myphone" to "About my phone",
        "network" to "Test my internet", "instruments" to "Level, compass, meters", "flashlight" to "Flashlight and SOS",
        "quick" to "Quick buttons", "parked" to "Find my car", "gpsdash" to "Speedometer",
    )

    fun jobName(route: String): String? = jobNames[route]
    fun shelf(of: String): Shelf? = all.firstOrNull { of in it.tools }

    // ---- Business (only for people who say they run one, in Settings or on the welcome screen) ----

    const val PREFS = "home"
    const val BUSINESS_KEY = "tenzy.business"
    const val TAB_KEY = "tenzy.homeTab"

    fun businessOn(ctx: Context): Boolean = ctx.getSharedPreferences(PREFS, 0).getBoolean(BUSINESS_KEY, false)
    fun setBusiness(ctx: Context, on: Boolean) = ctx.getSharedPreferences(PREFS, 0).edit().putBoolean(BUSINESS_KEY, on).apply()

    val business = Shelf("business", "Business", "Invoices, expenses, customers and QR codes", emptyList())

    /** One Business tile: a job that opens a tool. Every one says a job no other tile says. */
    data class BusinessJob(val id: String, val title: String, val route: String)
    val businessJobs: List<BusinessJob> = listOf(
        BusinessJob("invoice", "Send an invoice", "invoice"),
        BusinessJob("expense", "Log an expense", "receipts"),
        BusinessJob("table", "Receipt to spreadsheet", "scancsv"),
        BusinessJob("customer", "Save a customer", "docs"),
        BusinessJob("reviewqr", "Make a QR code", "codes"),
        BusinessJob("product", "Product photo to sell", "media"),
    )
    /** Tools whose only tile is on the Business tab. */
    val businessTools: Set<String> get() = businessJobs.map { it.route }.toSet() - all.flatMap { it.tools }.toSet()

    fun tabs(business: Boolean): List<Shelf> = if (business) all + this.business else all
}
