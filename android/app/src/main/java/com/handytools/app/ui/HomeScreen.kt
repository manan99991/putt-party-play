package com.handytools.app.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Apps
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.DirectionsCar
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material.icons.outlined.Gif
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Hearing
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.HandyApp
import com.handytools.app.R
import com.handytools.app.ads.BannerAd

/** A power tool: claymorphic icon + dark card background from the design kit. */
data class HTool(
    val route: String,
    val name: String,
    val blurb: String,
    val iconRes: Int,
    val cardRes: Int,
    val keywords: List<String> = emptyList(),
    /** A clear, plain-language line on what the tool does — shown at the top of its page. */
    val about: String = "",
    /** Fallback tile styling for tools without bespoke card art (new + brought-back ones): when
     *  cardRes/iconRes are 0 the card paints a soft gradient from [tint] with [vicon] on top. */
    val tint: Color = Color.Unspecified,
    val vicon: androidx.compose.ui.graphics.vector.ImageVector? = null,
)

/** The rebuilt Android catalog — flagship first. */
val TOOLS = listOf(
    HTool("fileviewer", "File Viewer", "Open & read any file type", R.drawable.ic_fileviewer, R.drawable.card_fileviewer,
        listOf("file","files","viewer","reader","open","any","unknown","pdf","zip","archive","apk","sqlite","db","database","hex","json","csv","xml","code","text","raw","epub","book","image","binary","inspect","extension","type"),
        about = "Open almost any file right on your phone — PDFs, Office and iWork docs, images, archives, databases, APKs, code, even files with no extension. Nothing is uploaded, and Tenzy shows up in other apps' “Open with” list."),
    HTool("docs", "Docs & Capture", "Scan, OCR, sign & merge", R.drawable.tool_documents, R.drawable.card_documents,
        listOf("document","documents","capture","scan","camera","ocr","receipt","card","contact","pdf","sign","fill","merge","split","compress","word","find","search","invoice","doc","excel","text","paper","extract","table","photo"),
        about = "A full document workflow in one place: scan paper to clean PDFs, pull out text and tables with OCR, sign and fill forms, then merge, split or compress."),
    HTool("scansort", "Scan & Sort", "Paper → table, bills & more", 0, 0,
        listOf("scan","sort","receipt","receipts","bill","bills","table","csv","spreadsheet","translate","translation","sorted","data","grab","invoice","paper","document","extract","ocr","calendar","due","warranty"),
        about = "Point your camera at paper and get something useful back — turn a receipt or table into a spreadsheet, file a receipt with its warranty, drop a bill's due date on your calendar, or translate text in a photo. All on your phone.",
        tint = Color(0xFF4F46E5), vicon = Icons.Outlined.DocumentScanner),
    HTool("media", "Media Studio", "Shrink, cut out, redact", R.drawable.tool_media, R.drawable.card_media,
        listOf("photo","video","shrink","compress","resize","smaller","background","remove","cutout","redact","passport","id","convert","heic","jpg","gif","metadata","exif","send","upload"),
        about = "Shrink photos and videos to a target size, cut out backgrounds, make passport photos, and strip location and metadata — all before you share."),
    HTool("cleanup", "Clean Up", "Free space & tidy", R.drawable.tool_cleanup, R.drawable.card_cleanup,
        listOf("clean","cleaner","space","storage","duplicate","duplicates","photos","screenshots","videos","large","big","free up","full","contacts","merge","declutter"),
        about = "Find genuine duplicate and look-alike photos, big files and old screenshots to free up space, and tidy duplicate contacts — with a recoverable trash so nothing is lost by accident."),
    HTool("converter", "Converter", "Convert anything", R.drawable.ic_converter, R.drawable.card_converter,
        listOf("convert","converter","change","format","image","png","jpg","jpeg","webp","heic","pdf","audio","video","transcode","compress","mp4","m4a","aac"),
        about = "Convert images, PDFs, audio and video between formats. Pick one file or several at once, choose the output format, and it all runs on-device."),
    HTool("instruments", "Instruments", "Sensors & meters", R.drawable.tool_instruments, R.drawable.card_instruments,
        listOf("measure","level","compass","north","sound","decibel","light","altitude","metal","detector","ruler","magnifier","zoom","sensor","flashlight","torch","strobe","sos","morse","screen","mirror"),
        about = "Your phone's sensors as a toolbox — spirit level, compass, sound and light meters, a metal detector, ruler, magnifier and torch."),
    HTool("safety", "Safety", "Spot scams & bad links", R.drawable.tool_safety, R.drawable.card_safety,
        listOf("scam","safety","phishing","fraud","link","text","sms","email","qr","suspicious","check","protect","shield","fake","spam"),
        about = "Paste a suspicious text, link, email or QR code and get a plain-language scam verdict with the reasons — before you tap."),
    HTool("share", "Share & Connect", "QR, Wi-Fi & file transfer", R.drawable.tool_share, R.drawable.card_share,
        listOf("share","send","transfer","file","wifi","nearby","connect","airdrop"),
        about = "Make QR and Wi-Fi codes, and send files to a nearby device over your local network — no account, no cloud."),
    HTool("network", "Network", "Speed, Wi-Fi & devices", R.drawable.ic_network, R.drawable.card_network,
        listOf("network","wifi","speed","internet","speedtest","signal","router","dns","ip","devices","scan","connection","ping","lan","mbps","latency","download","scout"),
        about = "Measure your real internet speed, see everything about your Wi-Fi connection — signal, IP, router, DNS — and scan the network to see who else is on it. All on your phone, nothing uploaded."),
    HTool("codes", "Codes", "Scan & make codes", R.drawable.ic_codes, R.drawable.card_codes,
        listOf("qr","barcode","code","scan","generate","create","nfc","tag","wifi","vcard","contact","url","link","payload"),
        about = "Scan any QR or barcode, or create your own for text, links, Wi-Fi, contacts and more — generated right on your phone."),
    HTool("scrubber", "Scrubber", "Blur & strip data", R.drawable.ic_scrubber, R.drawable.card_scrubber,
        listOf("scrub","scrubber","blur","hide","face","faces","plate","licence","license","redact","anonymize","privacy","metadata","exif","gps","location","strip","personal"),
        about = "Blur faces and licence plates and strip hidden location and metadata from a photo before you post it — the covered pixels are gone for good."),
    HTool("voice", "Voice", "Record, transcribe & trim", R.drawable.tool_voice, R.drawable.card_voice,
        listOf("voice","record","recorder","transcribe","transcript","speech","text","dictate","dictation","audio","trim","cut","memo","note","speak"),
        about = "Record speech and get an instant transcript you can tidy and share, or trim an audio clip down — all on your phone, no account."),
    HTool("memory", "Memory", "Ask your screenshots", R.drawable.ic_memory, R.drawable.card_memory,
        listOf("memory","find","search","screenshot","screenshots","photos","wifi","password","code","confirmation","parking","where","receipt","remember","ask"),
        about = "Ask your own screenshots anything — the Wi-Fi password, a confirmation number, where you parked. Read on your phone, never uploaded."),
    HTool("parked", "Where I Parked", "Save & find your car", 0, 0,
        listOf("park","parked","car","find","where","garage","lot","vehicle","location","walk back","pin"),
        about = "Drop a pin where you parked, then get the distance and a compass arrow back to your car later. Saved on your phone.",
        tint = Color(0xFF0284C7), vicon = Icons.Outlined.DirectionsCar),
    HTool("invoice", "Invoice", "Quick invoices to send", 0, 0,
        listOf("invoice","bill","client","charge","quote","pdf","payment","freelance","receipt","line item"),
        about = "Fill in who it's for and a few line items, and Tenzy builds a clean PDF invoice you can share — made entirely on your phone.",
        tint = Color(0xFFEA580C), vicon = Icons.Outlined.ReceiptLong),
    HTool("storage", "Storage", "See what's filling your phone", 0, 0,
        listOf("storage","space","full","breakdown","disk","gb","files","photos","videos","folders","largest","clean"),
        about = "A clear map of what's using your space — photos, videos, the biggest folders and largest files — so you know what to clear.",
        tint = Color(0xFF10B981), vicon = Icons.Outlined.PieChart),
    HTool("gifmaker", "GIF Maker", "Video → looping GIF", 0, 0,
        listOf("gif","video","animation","loop","convert","share","clip","meme"),
        about = "Pick a short video and Tenzy turns it into a smooth looping GIF, made on your phone.",
        tint = Color(0xFFDB2777), vicon = Icons.Outlined.Gif),
    HTool("texttools", "Text Tools", "Clean & change text", 0, 0,
        listOf("text","case","uppercase","lowercase","title case","trim","spaces","line breaks","reverse","word count","character count","clean","format"),
        about = "Paste text and fix it fast — change the case, strip extra spaces and line breaks, reverse it, or just count the words and characters.",
        tint = Color(0xFF0D9488), vicon = Icons.Outlined.TextFields),
    HTool("myphone", "My Phone", "Device info at a glance", 0, 0,
        listOf("phone","device","info","specs","battery","storage","ram","memory","model","android","screen","hardware","about"),
        about = "A clear read-out of your phone — battery, storage, RAM, screen, model and network — with a one-tap copy for support.",
        tint = Color(0xFF475569), vicon = Icons.Outlined.PhoneAndroid),
    HTool("hearing", "Hearing Boost", "Amplify what's around you", 0, 0,
        listOf("hearing","boost","amplify","sound","listen","ear","loud","hard of hearing","assist","mic"),
        about = "Turns your phone and earbuds into a live listening aid — it picks up the sound around you and plays it back louder, at a level you control. Best with wired or low-latency earbuds.",
        tint = Color(0xFF0891B2), vicon = Icons.Outlined.Hearing),
    HTool("quick", "Quick Buttons", "One-tap handy actions", 0, 0,
        listOf("quick","buttons","easy","flashlight","torch","brightness","camera","selfie","video","hotspot","shortcut","toggle"),
        about = "The things you reach for in a hurry on big one-tap buttons — flashlight, brightness, camera, selfie, video and hotspot.",
        tint = Color(0xFF7C3AED), vicon = Icons.Outlined.GridView),
    HTool("more", "Everything else", "The rest of the toolbox", 0, 0,
        listOf("more","everything","else","other","extra","pro camera","color vision","long screenshot","price check","rest","gps","identify","see and read","lens"),
        about = "A handful of more specialised tools, kept together here so the main grid stays tidy — tap in to find them.",
        tint = Color(0xFF64748B), vicon = Icons.Outlined.Apps),
)

/** The tools folded into the "Scan & Sort" tile — snap paper, get data/actions back. Off the main
 *  grid but reached from Scan & Sort and by search; kept here for PowerToolPage + group rendering. */
val SCANSORT_TOOLS = listOf(
    HTool("scancsv", "Data Grabber", "Photo → table / CSV", R.drawable.ic_scancsv, R.drawable.card_scancsv,
        listOf("data","table","csv","spreadsheet","receipt","list","rows","columns","scan","extract","grab","ocr","excel"),
        about = "Photograph a receipt, list or simple table and turn it into a spreadsheet-ready CSV you can fix and share — read entirely on your phone."),
    HTool("receipts", "Receipts", "Warranties & receipts", R.drawable.ic_receipts, R.drawable.card_receipts,
        listOf("receipt","receipts","warranty","warranties","proof of purchase","store","expiry","expires","return","refund","appliance","guarantee"),
        about = "File receipts and never miss a warranty — snap the receipt, Tenzy keeps it and reminds you before the warranty or return window runs out."),
    HTool("sorted", "Sorted", "Snap a bill → calendar", R.drawable.ic_sorted, R.drawable.card_sorted,
        listOf("sorted","bill","letter","mail","appointment","notice","invoice","due","deadline","calendar","remind","reminder","scan","amount","pay","admin","paperwork"),
        about = "Snap a bill, letter or appointment and Sorted pulls out the due date and amount and drops a reminder on your calendar."),
    HTool("translate", "Translate", "Text, camera & conversation", R.drawable.tool_translate, R.drawable.card_translate,
        listOf("translate","translation","language","languages","text","camera","photo","conversation","speak","interpret","foreign","phrase"),
        about = "Translate typed text, text in a photo, or a live back-and-forth conversation between two languages — on your phone."),
)

/** The tools folded into the "Everything else" tile. Reached from that tile and by search. */
val MORE_TOOLS = listOf(
    HTool("lens", "See & Read", "Read aloud & gist", R.drawable.ic_lens, R.drawable.card_lens,
        listOf("read","see","lens","ocr","text","photo","listen","read aloud","tts","speak","gist","summarize","summary","accessibility","magnify"),
        about = "Grab text from a photo or paste it, then listen to it read aloud or boil it down to the gist — all on your phone."),
    HTool("identify", "Identify", "What is this?", R.drawable.ic_identify, R.drawable.card_identify,
        listOf("identify","what is this","recognize","plant","flower","tree","animal","dog","breed","bug","insect","object","landmark","barcode","product","scan","camera","lookup"),
        about = "Point a photo at something and know what it is — everyday objects, plants, animals and products, recognised on your phone, with a one-tap web lookup."),
    HTool("gpsdash", "GPS Dashboard", "Speed, heading & altitude", R.drawable.ic_gpsdash, R.drawable.card_gpsdash,
        listOf("gps","speed","speedometer","heading","bearing","altitude","elevation","hud","trip","drive","bike","hike","mph","kph","km/h","dashboard","location"),
        about = "A live read-out of your speed, heading, altitude and GPS fix quality for a drive, ride or hike — straight from the phone's GNSS, nothing uploaded."),
    HTool("rest", "Rest", "Sleep sounds & timer", R.drawable.ic_rest, R.drawable.card_rest,
        listOf("sleep","rest","white noise","pink noise","brown noise","noise","rain","ocean","waves","fan","sound","focus","relax","calm","timer","night","baby","tinnitus"),
        about = "Soft, steady sleep and focus sound — noise (white, pink, brown) plus rain, ocean and a fan, generated on your phone so it never loops, with a sleep timer that stops it for you."),
    HTool("pricecheck", "Price Check", "Best value per unit", R.drawable.ic_pricecheck, R.drawable.card_pricecheck,
        listOf("price","unit price","compare","deal","cheaper","per 100g","per litre","per unit","budget","shopping","grocery","value","cost","bulk"),
        about = "Enter the price and size of two or more products and Tenzy works out the real cost per 100 g, per litre or per unit — so the bigger pack can't trick you."),
    HTool("stitch", "Long Screenshot", "Stitch shots into one", R.drawable.ic_stitch, R.drawable.card_stitch,
        listOf("long screenshot","stitch","scroll","combine","merge","tall","chat","thread","conversation","full page","screenshots","join"),
        about = "Stitch a set of scrolling screenshots into one tall image — Tenzy finds the overlap between each shot and joins them seamlessly, so a chat or page reads as one picture."),
    HTool("colorvision", "Color Vision", "Tell colours apart", R.drawable.ic_colorvision, R.drawable.card_colorvision,
        listOf("color","colour","blind","colorblind","colourblind","daltonize","correct","vision","red green","protan","deutan","tritan","accessibility"),
        about = "Shifts the colours a given type of colour blindness confuses into differences the eye can still tell apart — pick a photo, pick your type, and compare. All on your phone."),
    HTool("procam", "Pro Camera", "Manual ISO & shutter", R.drawable.ic_procam, R.drawable.card_procam,
        listOf("camera","pro","manual","iso","shutter","exposure","raw","long exposure","night","photography","sensor","aperture"),
        about = "Manual control of the camera sensor — ISO and shutter speed with a live preview — on phones that allow it, falling back to auto elsewhere. Photos save to your gallery."),
)

/** Tools that aren't on the home grid but still render through PowerToolPage (e.g. opened from
 *  another tool). They need scaffold metadata so the shared page shows THEIR header, not the first
 *  grid tool's. Looked up alongside TOOLS by PowerToolPage. */
val EXTRA_TOOLS = listOf(
    HTool("flashlight", "Flashlight", "Torch, patterns, Morse & more", R.drawable.tool_flashlight, R.drawable.card_flashlight,
        about = "The real camera torch: tap on, pick a light pattern (steady, strobe, SOS, beacon, pulse), set the brightness, flash a Morse message, turn the whole screen into a light, or use the front camera as a mirror."),
)

/** Every tool's scaffold metadata, grid + folded-in, for PowerToolPage lookup. */
val ALL_TOOLS = TOOLS + SCANSORT_TOOLS + MORE_TOOLS + EXTRA_TOOLS

/** Everything a user can search for and open directly — grid tiles plus the tools folded into the
 *  Scan & Sort and Everything-else groups. */
val SEARCHABLE = TOOLS + SCANSORT_TOOLS + MORE_TOOLS

/** Count of real, usable tools (excludes the two group-launcher tiles, which aren't themselves tools). */
val TENZY_TOOL_COUNT = SEARCHABLE.count { it.route != "scansort" && it.route != "more" }

/** Google-style ranked search across every tool. */
fun searchTools(raw: String): List<HTool> {
    val query = raw.lowercase().trim()
    if (query.isEmpty()) return emptyList()
    val tokens = query.split(" ").filter { it.length >= 2 }
    fun score(t: HTool): Int {
        val name = t.name.lowercase(); val blurb = t.blurb.lowercase()
        var s = 0
        if (name == query) s += 1000
        if (name.startsWith(query)) s += 500
        if (name.contains(query)) s += 250
        if (t.keywords.contains(query)) s += 200
        for (tok in tokens) {
            if (name.contains(tok)) s += 120
            for (k in t.keywords) { if (k == tok) s += 90 else if (k.contains(tok) || tok.contains(k)) s += 45 }
            if (blurb.contains(tok)) s += 25
        }
        return s
    }
    return SEARCHABLE.map { it to score(it) }.filter { it.second > 0 }.sortedByDescending { it.second }.map { it.first }
}

@Composable
fun HomeScreen(onOpen: (String) -> Unit) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var query by remember { mutableStateOf("") }
    val results = if (query.trim().isEmpty()) TOOLS else searchTools(query)
    var tab by remember { mutableStateOf(0) }   // 0 Build · 1 Search · 2 Settings

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        // A soft wash in the current theme's primary colour so the home page has some life AND follows
        // the selected theme. It used to paint a fixed dark image, which is why themes never reached it.
        Box(
            Modifier.fillMaxWidth().fillMaxHeight(0.42f).align(Alignment.TopCenter)
                .background(
                    Brush.verticalGradient(
                        0f to MaterialTheme.colorScheme.primary.copy(alpha = 0.16f),
                        1f to Color.Transparent
                    )
                )
        )
        Column(Modifier.fillMaxSize()) {
          // Build-first shell: Build (the maker) is home, Search finds standalone tools, Settings holds
          // the map + themes + plan. One screen each, no horizontal rails — the whole app from one bar.
          Box(Modifier.weight(1f).fillMaxWidth()) {
            when (tab) {
                0 -> com.handytools.app.tools.builder.BuilderScreen()
                2 -> SettingsScreen(onOpen = onOpen)
                else -> Column(Modifier.fillMaxSize().statusBarsPadding()) {
            // Search
            TextField(
                value = query, onValueChange = { query = it },
                placeholder = { Text("Search $TENZY_TOOL_COUNT tools") },
                leadingIcon = { Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary) },
                trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Outlined.Close, "Clear") } },
                singleLine = true, keyboardOptions = KeyboardOptions.Default, shape = RoundedCornerShape(50),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent
                ),
                modifier = Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = HandyTokens.Space8)
            )

            if (query.isBlank()) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = HandyTokens.Space8)
                        .clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.14f))
                        .clickable { onOpen("builder") }.padding(HandyTokens.Space12),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Outlined.Bolt, null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(HandyTokens.Space8))
                    Column(Modifier.weight(1f)) {
                        Text("Build your own tool", style = MaterialTheme.typography.titleSmall)
                        Text("Describe it or snap steps together", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                }
            }
            if (results.isEmpty()) {
                Column(Modifier.fillMaxSize().padding(HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.height(HandyTokens.Space48))
                    Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary, modifier = Modifier.size(36.dp))
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text("No tools match \"$query\"", color = Handy.palette.textSecondary)
                }
            } else {
                // Fit every tool on one page: size each card so all rows land inside the viewport (no
                // scroll for the full 10), and only fall back to scrolling if there are ever more rows
                // than fit. Cards keep a sensible min height so they never collapse to a sliver.
                BoxWithConstraints(Modifier.weight(1f)) {
                    val rows = (results.size + 1) / 2
                    val pad = HandyTokens.Gutter
                    val gap = HandyTokens.Space12
                    val fitH = (maxHeight - pad * 2 - gap * (rows - 1).coerceAtLeast(0)) / rows.coerceAtLeast(1)
                    // Floor is set so the icon, title and a full two-line blurb always fit — below this
                    // the blurb would be clipped, so we scroll instead of cramming.
                    val cardH = fitH.coerceIn(120.dp, 168.dp)
                    val scroll = cardH * rows + gap * (rows - 1).coerceAtLeast(0) + pad * 2 > maxHeight
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        modifier = Modifier.fillMaxSize(),
                        userScrollEnabled = scroll,
                        contentPadding = PaddingValues(pad),
                        horizontalArrangement = Arrangement.spacedBy(gap),
                        verticalArrangement = Arrangement.spacedBy(gap)
                    ) {
                        items(results, key = { it.route }) { t -> PowerToolCard(t, cardH) { onOpen(t.route) } }
                    }
                }
            }
                }
            }
          }
          BannerAd()
          TenzyTabBar(tab) { tab = it }
        }
    }
}

/** The one bar the whole app runs from: Build (the maker, home), Search (standalone tools),
 *  Settings (map + themes + plan). Matches the iPhone tab bar so both phones feel the same. */
@Composable
private fun TenzyTabBar(selected: Int, onSelect: (Int) -> Unit) {
    val items = listOf(
        Triple(0, Icons.Outlined.Bolt, "Build"),
        Triple(1, Icons.Outlined.Search, "Search"),
        Triple(2, Icons.Outlined.Settings, "Settings")
    )
    Row(
        Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface)
            .navigationBarsPadding().padding(top = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        items.forEach { (i, icon, label) ->
            val on = i == selected
            val tint = if (on) MaterialTheme.colorScheme.primary else Handy.palette.textSecondary
            Column(
                Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).clickable { onSelect(i) }
                    .padding(vertical = HandyTokens.Space8),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(icon, label, tint = tint)
                Spacer(Modifier.height(2.dp))
                Text(label, style = MaterialTheme.typography.labelSmall, color = tint)
            }
        }
    }
}

/** Approved card (HTML prototype v4): the kit's 1290×440 art has its glow + line-art on the
 *  right third, so a 2-column card crops anchored to the RIGHT edge — never center — and a
 *  bottom-only scrim keeps the art visible while the name stays crisp. */
// Aurora tile duotones — each tool keeps the same pair (stable by route), spread across Aurora's
// palette, so the home grid reads as one colourful set on the near-black ground. Matches iOS.
private val AURORA_TILES = listOf(
    listOf(Color(0xFF7B5CFF), Color(0xFF4F2BD6)), listOf(Color(0xFFFF4FA3), Color(0xFFB5247A)),
    listOf(Color(0xFF2BD4FF), Color(0xFF1C7FC2)), listOf(Color(0xFFBFE645), Color(0xFF7FA015)),
    listOf(Color(0xFFFF8A5C), Color(0xFFD64F2B)), listOf(Color(0xFF5CFFC2), Color(0xFF1CB98A)),
    listOf(Color(0xFFB15CFF), Color(0xFF7A24D6))
)
private fun auroraTile(route: String): List<Color> =
    AURORA_TILES[((route.hashCode() % AURORA_TILES.size) + AURORA_TILES.size) % AURORA_TILES.size]

@Composable
private fun PowerToolCard(tool: HTool, height: androidx.compose.ui.unit.Dp, onClick: () -> Unit) {
    // Icon scales a little with the card so a shorter (fit-to-page) card still looks balanced.
    val iconSize = (height.value * 0.32f).coerceIn(34f, 54f).dp
    Box(
        Modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF0D0D16)).clickable(onClick = onClick)
    ) {
        // Aurora shows flat per-tool gradient tiles (its signature look, matching iOS) instead of the
        // photographic card art, so skip the art and go straight to the gradient when it's active.
        val aurora = LocalTenzyTheme.current == TenzyTheme.AURORA
        val cardRes = if (aurora) 0 else themedCardRes(tool.route).let { if (it != 0) it else tool.cardRes }
        if (cardRes != 0) {
            Image(
                painterResource(cardRes), null, modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop, alignment = Alignment.CenterEnd
            )
        } else {
            // No bespoke card art (Aurora, or new + brought-back tools): a soft diagonal gradient — an
            // Aurora duotone when that theme is on, else the tool's own tint — so the tile still reads
            // as designed rather than a flat black box.
            val g = if (aurora) auroraTile(tool.route) else {
                val base = if (tool.tint != Color.Unspecified) tool.tint else HandyColors.Accent
                listOf(base.copy(alpha = 0.95f), base.copy(alpha = 0.5f))
            }
            Box(Modifier.fillMaxSize().background(Brush.linearGradient(g)))
        }
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(0.30f to Color.Transparent, 1f to Color(0xD6060610))
            )
        )
        // Icon pinned to the top-left. Kept in its own aligned node (not a SpaceBetween column) so it
        // can never push the text past the bottom edge. Drawable art when present, else the Material
        // fallback icon for tiles without bespoke art.
        val iconRes = themedIconRes(tool.route).let { if (it != 0) it else tool.iconRes }
        if (iconRes != 0) {
            Image(
                painterResource(iconRes), null,
                modifier = Modifier.align(Alignment.TopStart).padding(14.dp).size(iconSize)
            )
        } else if (tool.vicon != null) {
            Icon(
                tool.vicon, null, tint = Color.White,
                modifier = Modifier.align(Alignment.TopStart).padding(14.dp).size(iconSize)
            )
        }
        // Title + blurb pinned to the bottom. Anchoring here guarantees the full two-line description
        // always sits inside the card — if space is ever tight it's the gap above that shrinks, never
        // the words that get clipped.
        Column(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(14.dp)) {
            Text(tool.name, color = Color.White, style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(2.dp))
            Text(tool.blurb, color = Color(0xCCFFFFFF), style = MaterialTheme.typography.bodySmall,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** Launcher page for a group tile (Scan & Sort, Everything else): lists the group's tools as tappable
 *  rows that open the real tool. The sub-tools keep their own screens and routes — this just gathers
 *  them under one grid tile. Uses PowerToolPage so it shares the standard header + themed backdrop. */
@Composable
fun GroupScreen(route: String, entries: List<HTool>, onOpen: (String) -> Unit) {
    PowerToolPage(route) {
        entries.forEach { t ->
            HCard(Modifier.fillMaxWidth().clickable { onOpen(t.route) }) {
                Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    val rowIcon = themedIconRes(t.route).let { if (it != 0) it else t.iconRes }
                    if (rowIcon != 0) {
                        Image(painterResource(rowIcon), null, Modifier.size(40.dp))
                    } else if (t.vicon != null) {
                        Icon(t.vicon, null, tint = HandyColors.Accent, modifier = Modifier.size(30.dp))
                    }
                    Spacer(Modifier.width(HandyTokens.Space12))
                    Column(Modifier.weight(1f)) {
                        Text(t.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface)
                        Text(t.blurb, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                    Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
                }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
        }
    }
}
