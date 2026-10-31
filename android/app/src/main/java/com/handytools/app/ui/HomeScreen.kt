package com.handytools.app.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
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
)

/** The rebuilt Android catalog — flagship first. */
val TOOLS = listOf(
    HTool("fileviewer", "File Viewer", "Open & read any file type", R.drawable.ic_fileviewer, R.drawable.card_fileviewer,
        listOf("file","files","viewer","reader","open","any","unknown","pdf","zip","archive","apk","sqlite","db","database","hex","json","csv","xml","code","text","raw","epub","book","image","binary","inspect","extension","type")),
    HTool("capture", "Capture", "Scan anything → act on it", R.drawable.tool_capture, R.drawable.card_capture,
        listOf("capture","scan","camera","ocr","receipt","card","contact","translate","extract","read","lens","calendar","csv","table","bill","sorted","photo")),
    HTool("documents", "Documents", "Scan, sign, merge, find", R.drawable.tool_documents, R.drawable.card_documents,
        listOf("document","documents","scan","pdf","sign","fill","merge","split","compress","ocr","searchable","word","find","search","invoice","file","doc","excel","text","paper")),
    HTool("media", "Media Studio", "Shrink, cut out, redact", R.drawable.tool_media, R.drawable.card_media,
        listOf("photo","video","shrink","compress","resize","smaller","background","remove","cutout","redact","passport","id","convert","heic","jpg","gif","metadata","exif","send","upload")),
    HTool("cleanup", "Clean Up", "Free space & tidy contacts", R.drawable.tool_cleanup, R.drawable.card_cleanup,
        listOf("clean","cleaner","space","storage","duplicate","duplicates","photos","screenshots","videos","large","big","free up","full","contacts","merge","declutter")),
    HTool("voice", "Voice Notes", "Record, transcribe, trim", R.drawable.tool_voice, R.drawable.card_voice,
        listOf("voice","record","recorder","transcribe","speech","notes","dictate","trim","audio","memo","text","meeting")),
    HTool("translate", "Translate", "Text, camera & voice", R.drawable.tool_translate, R.drawable.card_translate,
        listOf("translate","language","camera","voice","conversation","offline","foreign","spanish","french")),
    HTool("instruments", "Instruments", "Level, compass, meters", R.drawable.tool_instruments, R.drawable.card_instruments,
        listOf("measure","level","compass","north","sound","decibel","light","altitude","metal","detector","ruler","magnifier","zoom","sensor")),
    HTool("flashlight", "Flashlight+", "Strobe, SOS, screen light", R.drawable.tool_flashlight, R.drawable.card_flashlight,
        listOf("flashlight","torch","light","strobe","sos","morse","screen","mirror","brightness","lamp","dark","blink")),
    HTool("safety", "Safety", "Spot scams & bad links", R.drawable.tool_safety, R.drawable.card_safety,
        listOf("scam","safety","phishing","fraud","link","text","sms","email","qr","suspicious","check","protect","shield","fake","spam")),
    HTool("share", "Share & Connect", "QR, Wi-Fi & file transfer", R.drawable.tool_share, R.drawable.card_share,
        listOf("share","send","transfer","file","qr","barcode","wifi","nearby","network","speed","connect","airdrop","code")),
)

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
                    Text("11 power tools · on your phone",
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
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(HandyTokens.Gutter),
                    horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space12),
                    verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)
                ) {
                    items(results, key = { it.route }) { t -> PowerToolCard(t) { onOpen(t.route) } }
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
private fun PowerToolCard(tool: HTool, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().aspectRatio(1f / 1.08f).clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF0D0D16)).clickable(onClick = onClick)
    ) {
        Image(
            painterResource(tool.cardRes), null, modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop, alignment = Alignment.CenterEnd
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(0.35f to Color.Transparent, 1f to Color(0xC7070710))
            )
        )
        Column(Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Image(painterResource(tool.iconRes), null, modifier = Modifier.size(60.dp))
            Column {
                Text(tool.name, color = Color.White, style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Text(tool.blurb, color = Color(0xB8FFFFFF), style = MaterialTheme.typography.bodySmall,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
