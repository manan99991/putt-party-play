package com.handytools.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.AppShortcut
import androidx.compose.material.icons.outlined.EventNote
import androidx.compose.material.icons.outlined.ImageSearch
import androidx.compose.material.icons.outlined.Subject
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.AutoFixHigh
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.CleaningServices
import androidx.compose.material.icons.outlined.Compress
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.Contacts
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material.icons.outlined.Draw
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.FlashOn
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.PictureAsPdf
import androidx.compose.material.icons.outlined.QrCode2
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.LocalParking
import androidx.compose.material.icons.outlined.NetworkCheck
import androidx.compose.material.icons.outlined.Hearing
import androidx.compose.material.icons.outlined.MonitorHeart
import androidx.compose.material.icons.outlined.ContentCut
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Straighten
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material.icons.outlined.ZoomIn
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.handytools.app.HandyApp
import com.handytools.app.ads.BannerAd
import kotlinx.coroutines.launch

data class HTool(
    val route: String, val name: String, val blurb: String, val icon: ImageVector,
    val page: Int, val ai: Boolean = false, val keywords: List<String> = emptyList()
)

/** Tools across 3 pages, mirroring iOS. Existing Android screens reuse their routes. */
val TOOLS = listOf(
    // Page 1 · Everyday
    HTool("spaceclean", "Space Cleaner", "Free up photo space", Icons.Outlined.CleaningServices, 1, keywords = listOf("clean","storage","space","duplicate","duplicates","photos","screenshots","large","blurry","free up","delete","full")),
    HTool("storage", "Storage Map", "See what's eating space", Icons.Outlined.PieChart, 1, keywords = listOf("storage","space","full","breakdown","map","what","using","photos","videos","downloads","audio","big","large","free up")),
    HTool("contacts", "Contacts Cleanup", "Merge duplicates, back up", Icons.Outlined.Contacts, 1, keywords = listOf("contacts","duplicate","duplicates","merge","vcard","backup","phone","cleanup","incomplete")),
    HTool("flash", "Flashlight", "Patterns, SOS, strobe", Icons.Outlined.FlashOn, 1, keywords = listOf("light","torch","strobe","sos","lamp","dark")),
    HTool("qr", "QR & Barcode", "Scan & make codes", Icons.Outlined.QrCode2, 1, keywords = listOf("qr","barcode","scan","code","wifi","link")),
    HTool("myphone", "My Phone", "Battery, storage, specs", Icons.Outlined.PhoneAndroid, 1, keywords = listOf("phone","device","battery","storage","ram","memory","specs","info","model","android","ip","network","screen","health","free","space")),
    HTool("texttools", "Text Tools", "Clean up & fix text", Icons.Outlined.TextFields, 1, keywords = listOf("text","case","uppercase","lowercase","word","count","characters","clean","trim","spaces","reverse","format","remove","breaks")),
    HTool("lens", "Lens", "Read or listen to any text", Icons.Outlined.Subject, 1, keywords = listOf("lens","read","listen","aloud","tts","speak","ocr","text","copy","gist","summarize","scan")),
    HTool("translate", "Translate", "Offline, private", Icons.Outlined.Translate, 1, keywords = listOf("translate","language","spanish","french","foreign")),
    HTool("magnifier", "Magnifier", "Zoom in on small print", Icons.Outlined.ZoomIn, 1, keywords = listOf("magnifier","zoom","read","loupe","camera")),
    HTool("measure", "Measure", "Level, compass, sound", Icons.Outlined.Straighten, 1, keywords = listOf("measure","level","compass","north","decibel","sound","angle")),
    // Page 2 · Power
    HTool("scan", "Doc Scanner", "Scan pages to PDF", Icons.Outlined.DocumentScanner, 2, keywords = listOf("scan","scanner","document","pdf","paper","camera")),
    HTool("pdftools", "PDF Toolkit", "Merge, compress PDFs", Icons.Outlined.PictureAsPdf, 2, keywords = listOf("pdf","merge","combine","split","compress","images")),
    HTool("shrink", "Shrink", "Make photos & videos smaller", Icons.Outlined.Compress, 2, keywords = listOf("shrink","compress","resize","smaller","reduce","photo","image","video","clip","size","mb","send","upload","email","heic","jpg")),
    HTool("bgremove", "Background Remover", "Cut out the subject", Icons.Outlined.AutoFixHigh, 2, keywords = listOf("background","remove","cutout","subject","transparent","sticker")),
    HTool("audiotext", "Audio to Text", "Transcribe your voice", Icons.Outlined.Mic, 2, keywords = listOf("audio","text","transcribe","voice","speech","record","notes")),
    HTool("signfill", "Sign & Fill", "Sign a doc, export PDF", Icons.Outlined.Draw, 2, keywords = listOf("sign","signature","fill","document","pdf","form","contract")),
    HTool("exif", "Photo Metadata", "Strip photo location", Icons.Outlined.Info, 2, keywords = listOf("photo","metadata","exif","location","gps","strip","privacy")),
    HTool("sorted", "Sorted", "Snap a bill → calendar it", Icons.Outlined.EventNote, 2, true, listOf("bill","letter","document","appointment","form","notice","invoice","due","deadline","calendar","remind","scan","amount","pay","admin","paperwork")),
    // Page 3 · Everyday tools that work on every phone (no flagship-only AI needed)
    HTool("shield", "Scam & Safety Check", "Spot scam texts & links", Icons.Outlined.Shield, 3, keywords = listOf("scam","safety","check","phishing","fraud","text","sms","email","link","suspicious","fake","spam","protect","verify","shield","message","dm")),
    HTool("parked", "Where'd I Park", "Pin the car, walk back", Icons.Outlined.LocalParking, 3, keywords = listOf("park","parking","car","find","lot","garage","pin","location","gps","remember","where","vehicle")),
    HTool("netscout", "Network Scout", "See who's on your Wi-Fi", Icons.Outlined.NetworkCheck, 3, keywords = listOf("network","wifi","scan","devices","ip","router","signal","speed","lan","scout","who","connected")),
    HTool("hearing", "Hearing Boost", "Amplify sound to earbuds", Icons.Outlined.Hearing, 3, keywords = listOf("hearing","hear","amplify","boost","ear","loud","sound","assist","listen","volume","aid")),
    HTool("heartrate", "Heart Rate", "Pulse from your fingertip", Icons.Outlined.MonitorHeart, 3, keywords = listOf("heart","rate","pulse","bpm","fingertip","camera","health","beats","measure")),
    HTool("audiocut", "Ringtone & Audio Cutter", "Trim audio, make ringtones", Icons.Outlined.ContentCut, 3, keywords = listOf("ringtone","audio","cut","cutter","trim","music","mp3","song","clip","sound","edit","crop")),
)

fun toolsOnPage(p: Int) = TOOLS.filter { it.page == p }

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
    val pager = rememberPagerState(pageCount = { 3 })
    val scope = rememberCoroutineScope()
    val captions = listOf("Everyday essentials", "Power tools", "AI · on your phone")

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        // Header
        Row(
            Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter, vertical = HandyTokens.Space12),
            horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Tenzy", style = MaterialTheme.typography.headlineMedium)
                    Spacer(Modifier.width(HandyTokens.Space12))
                    (1..3).forEach { n ->
                        Box(
                            Modifier.padding(end = HandyTokens.Space4).size(28.dp)
                                .background(if (pager.currentPage + 1 == n) HandyColors.Accent else Handy.palette.accentSoft, CircleShape)
                                .clickable { scope.launch { pager.animateScrollToPage(n - 1) } },
                            contentAlignment = Alignment.Center
                        ) {
                            Text("$n", color = if (pager.currentPage + 1 == n) Color.White else HandyColors.Accent,
                                style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space4))
                Text(if (premium) "Pro · no ads" else captions[pager.currentPage],
                    style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            }
            Row {
                if (!premium) IconButton(onClick = { onOpen("paywall") }) { Icon(Icons.Outlined.WorkspacePremium, "Go Pro", tint = HandyColors.Accent) }
                IconButton(onClick = { onOpen("settings") }) { Icon(Icons.Outlined.Settings, "Settings", tint = Handy.palette.textSecondary) }
            }
        }

        // Search field
        TextField(
            value = query, onValueChange = { query = it },
            placeholder = { Text("Search ${TOOLS.size} tools…") },
            leadingIcon = { Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary) },
            trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Outlined.Close, "Clear") } },
            singleLine = true,
            keyboardOptions = KeyboardOptions.Default,
            shape = RoundedCornerShape(50),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent
            ),
            modifier = Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = HandyTokens.Space8)
        )

        if (query.trim().isEmpty()) {
            HorizontalPager(state = pager, modifier = Modifier.weight(1f)) { page ->
                ToolGridPage(page + 1, onOpen)
            }
        } else {
            SearchResults(query, onOpen, Modifier.weight(1f))
        }
        BannerAd()
    }
}

/** Static 2×5 grid that fills the page — no scrolling. */
@Composable
private fun ToolGridPage(page: Int, onOpen: (String) -> Unit) {
    val items = toolsOnPage(page)
    Column(
        Modifier.fillMaxSize().padding(horizontal = HandyTokens.Gutter, vertical = HandyTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)
    ) {
        if (page == 3) AiNote()
        for (row in 0 until 5) {
            Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
                for (col in 0 until 2) {
                    val idx = row * 2 + col
                    if (idx < items.size) {
                        val t = items[idx]
                        Box(Modifier.weight(1f).fillMaxSize()) { ToolCard(t.name, t.blurb, t.icon) { onOpen(t.route) } }
                    } else {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun AiNote() {
    Row(
        Modifier.fillMaxWidth().background(Handy.palette.accentSoft, RoundedCornerShape(HandyTokens.RadiusInput)).padding(HandyTokens.Space12),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Outlined.AutoAwesome, null, tint = HandyColors.Accent, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(HandyTokens.Space8))
        Text("Runs free and private on your phone — nothing is uploaded.",
            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
    }
}

@Composable
private fun SearchResults(query: String, onOpen: (String) -> Unit, modifier: Modifier = Modifier) {
    val results = searchTools(query)
    if (results.isEmpty()) {
        Column(modifier.fillMaxSize().padding(HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(HandyTokens.Space48))
            Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary, modifier = Modifier.size(36.dp))
            Spacer(Modifier.height(HandyTokens.Space8))
            Text("No tools match \"$query\"", color = Handy.palette.textSecondary)
            Text("Try \"photo\", \"pdf\", \"scan\", or \"ai\".", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
    } else {
        LazyVerticalGrid(
            columns = GridCells.Fixed(2), modifier = modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(HandyTokens.Gutter),
            horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space12),
            verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)
        ) {
            itemsIndexed(results, key = { _, t -> t.route }) { _, t ->
                ToolCard(t.name, t.blurb, t.icon) { onOpen(t.route) }
            }
        }
    }
}
