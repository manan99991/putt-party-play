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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
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
)

/** The rebuilt Android catalog — flagship first. */
val TOOLS = listOf(
    HTool("fileviewer", "File Viewer", "Open & read any file type", R.drawable.ic_fileviewer, R.drawable.card_fileviewer,
        listOf("file","files","viewer","reader","open","any","unknown","pdf","zip","archive","apk","sqlite","db","database","hex","json","csv","xml","code","text","raw","epub","book","image","binary","inspect","extension","type"),
        about = "Open almost any file right on your phone — PDFs, Office and iWork docs, images, archives, databases, APKs, code, even files with no extension. Nothing is uploaded, and Tenzy shows up in other apps' “Open with” list."),
    HTool("docs", "Docs & Capture", "Scan, OCR, sign & merge", R.drawable.tool_documents, R.drawable.card_documents,
        listOf("document","documents","capture","scan","camera","ocr","receipt","card","contact","pdf","sign","fill","merge","split","compress","word","find","search","invoice","doc","excel","text","paper","extract","table","photo"),
        about = "A full document workflow in one place: scan paper to clean PDFs, pull out text and tables with OCR, sign and fill forms, then merge, split or compress."),
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
    HTool("translate", "Translate", "Text, camera & conversation", R.drawable.tool_translate, R.drawable.card_translate,
        listOf("translate","translation","language","languages","text","camera","photo","conversation","speak","interpret","foreign","phrase"),
        about = "Translate typed text, text in a photo, or a live back-and-forth conversation between two languages — on your phone."),
    HTool("memory", "Memory", "Ask your screenshots", R.drawable.ic_memory, R.drawable.card_memory,
        listOf("memory","find","search","screenshot","screenshots","photos","wifi","password","code","confirmation","parking","where","receipt","remember","ask"),
        about = "Ask your own screenshots anything — the Wi-Fi password, a confirmation number, where you parked. Read on your phone, never uploaded."),
    HTool("sorted", "Sorted", "Snap a bill → calendar", R.drawable.ic_sorted, R.drawable.card_sorted,
        listOf("sorted","bill","letter","mail","appointment","notice","invoice","due","deadline","calendar","remind","reminder","scan","amount","pay","admin","paperwork"),
        about = "Snap a bill, letter or appointment and Sorted pulls out the due date and amount and drops a reminder on your calendar."),
    HTool("receipts", "Receipts", "Warranties & receipts", R.drawable.ic_receipts, R.drawable.card_receipts,
        listOf("receipt","receipts","warranty","warranties","proof of purchase","vault","store","expiry","expires","return","refund","appliance","guarantee"),
        about = "File receipts and never miss a warranty — snap the receipt, Tenzy keeps it and reminds you before the warranty or return window runs out."),
    HTool("scancsv", "Data Grabber", "Photo → table / CSV", R.drawable.ic_scancsv, R.drawable.card_scancsv,
        listOf("data","table","csv","spreadsheet","receipt","list","rows","columns","scan","extract","grab","ocr","excel"),
        about = "Photograph a receipt, list or simple table and turn it into a spreadsheet-ready CSV you can fix and share — read entirely on your phone."),
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
        listOf("sleep","rest","white noise","pink noise","brown noise","noise","sound","focus","relax","calm","timer","night","baby","tinnitus"),
        about = "Soft, steady sleep and focus sound — white, pink or brown noise generated on your phone so it never loops, with a sleep timer that stops it for you."),
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
    HTool("vault", "Vault", "Fingerprint-locked files", R.drawable.ic_vault, R.drawable.card_vault,
        listOf("vault","lock","locker","private","secure","hidden","encrypt","password","face id","fingerprint","biometric","safe","files","photos"),
        about = "A private locker behind your fingerprint or face. Files are encrypted with an AES-256 key held in the phone's secure hardware — unreadable without this device. Nothing is uploaded."),
)

/** Tools that aren't on the home grid but still render through PowerToolPage (e.g. opened from
 *  another tool). They need scaffold metadata so the shared page shows THEIR header, not the first
 *  grid tool's. Looked up alongside TOOLS by PowerToolPage. */
val EXTRA_TOOLS = listOf(
    HTool("flashlight", "Flashlight", "Torch, patterns, Morse & more", R.drawable.tool_flashlight, R.drawable.card_flashlight,
        about = "The real camera torch: tap on, pick a light pattern (steady, strobe, SOS, beacon, pulse), set the brightness, flash a Morse message, turn the whole screen into a light, or use the front camera as a mirror."),
)

/** Every tool's scaffold metadata, grid + folded-in, for PowerToolPage lookup. */
val ALL_TOOLS = TOOLS + EXTRA_TOOLS

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
    return TOOLS.map { it to score(it) }.filter { it.second > 0 }.sortedByDescending { it.second }.map { it.first }
}

@Composable
fun HomeScreen(onOpen: (String) -> Unit) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var query by remember { mutableStateOf("") }
    val results = if (query.trim().isEmpty()) TOOLS else searchTools(query)

    Box(Modifier.fillMaxSize()) {
        Image(
            painterResource(R.drawable.home_backdrop), null,
            modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop
        )
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            // Header
            Row(
                Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter, vertical = HandyTokens.Space12),
                horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    // The backdrop art is always dark, so the header is always light — in both themes.
                    Text("Tenzy", style = MaterialTheme.typography.headlineMedium, color = Color.White)
                    Spacer(Modifier.height(HandyTokens.Space4))
                    Text("${TOOLS.size} tools · on your phone",
                        style = MaterialTheme.typography.bodyMedium, color = Color(0xFFB8B8C8))
                }
                Row {
                    if (!premium) IconButton(onClick = { onOpen("paywall") }) { Icon(Icons.Outlined.WorkspacePremium, "Go Pro", tint = HandyColors.Accent) }
                    IconButton(onClick = { onOpen("settings") }) { Icon(Icons.Outlined.Settings, "Settings", tint = Color(0xFFC9C9D6)) }
                }
            }

            // Search
            TextField(
                value = query, onValueChange = { query = it },
                placeholder = { Text("Search ${TOOLS.size} tools") },
                leadingIcon = { Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary) },
                trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Outlined.Close, "Clear") } },
                singleLine = true, keyboardOptions = KeyboardOptions.Default, shape = RoundedCornerShape(50),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent
                ),
                modifier = Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = HandyTokens.Space8)
            )

            if (results.isEmpty()) {
                Column(Modifier.fillMaxSize().padding(HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.height(HandyTokens.Space48))
                    Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary, modifier = Modifier.size(36.dp))
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text("No tools match \"$query\"", color = Color(0xFFB8B8C8))
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
                    val cardH = fitH.coerceIn(96.dp, 168.dp)
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
            BannerAd()
        }
    }
}

/** Approved card (HTML prototype v4): the kit's 1290×440 art has its glow + line-art on the
 *  right third, so a 2-column card crops anchored to the RIGHT edge — never center — and a
 *  bottom-only scrim keeps the art visible while the name stays crisp. */
@Composable
private fun PowerToolCard(tool: HTool, height: androidx.compose.ui.unit.Dp, onClick: () -> Unit) {
    // Icon scales a little with the card so a shorter (fit-to-page) card still looks balanced.
    val iconSize = (height.value * 0.34f).coerceIn(36f, 56f).dp
    Box(
        Modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF0D0D16)).clickable(onClick = onClick)
    ) {
        Image(
            painterResource(tool.cardRes), null, modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop, alignment = Alignment.CenterEnd
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(0.30f to Color.Transparent, 1f to Color(0xD6060610))
            )
        )
        Column(Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Image(painterResource(tool.iconRes), null, modifier = Modifier.size(iconSize))
            Column {
                Text(tool.name, color = Color.White, style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                // Two lines + wrap so the description is shown in full and never chops off.
                Text(tool.blurb, color = Color(0xCCFFFFFF), style = MaterialTheme.typography.bodySmall,
                    maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
