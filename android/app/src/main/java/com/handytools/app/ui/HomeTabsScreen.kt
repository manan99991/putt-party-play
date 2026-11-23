package com.handytools.app.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.DirectionsCar
import androidx.compose.material.icons.outlined.Event
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material.icons.outlined.Work
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import java.util.Calendar

/**
 * "For you now" on Android (UX audit decision 2): a card when the day needs Tenzy, built only from what the person
 * already set up. Android starts with the parked car (shown for two days); more kinds follow the iPhone's list.
 * Pure choosing, so it's unit-tested.
 */
object ForYouAndroid {
    data class Card(val id: String, val title: String, val why: String, val button: String, val route: String, val kind: String)

    fun cards(parkedAt: Long?, now: Long, hidden: Map<String, Long>,
              invoices: List<com.handytools.app.tools.invoice.InvoiceLogic.Doc> = emptyList()): List<Card> {
        val out = mutableListOf<Card>()
        // The invoice a customer is most overdue on (Business, 23 Nov) comes before the car.
        invoices.filter { it.overdue(now) }.minByOrNull { it.due ?: now }?.let { d ->
            out += Card("invoice-${d.id}", if (d.who.isEmpty()) "${d.number} isn't paid yet" else "${d.who} hasn't paid yet",
                "${d.currency}${"%,.2f".format(d.total)} · ${d.number}", "See unpaid", "invoice", "invoice")
        }
        if (parkedAt != null && parkedAt > 0 && now - parkedAt < 48L * 3600_000) {
            val mins = ((now - parkedAt) / 60_000).toInt()
            val ago = when {
                mins < 1 -> "Parked just now"
                mins < 60 -> "Parked $mins min ago"
                mins < 24 * 60 -> "Parked ${mins / 60} h ago"
                else -> "Parked yesterday"
            }
            out += Card("car-$parkedAt", "Your car is saved", ago, "Find it", "parked", "car")
        }
        return out.filter { (hidden[it.id] ?: 0L) <= now }.take(1)
    }

    private const val PREFS = "foryou"
    fun hidden(ctx: Context): Map<String, Long> =
        ctx.getSharedPreferences(PREFS, 0).all.mapNotNull { (k, v) -> (v as? Long)?.let { k to it } }.toMap()
    /** Not now: this card stays away for a week. */
    fun notNow(ctx: Context, c: Card, now: Long = System.currentTimeMillis()) =
        ctx.getSharedPreferences(PREFS, 0).edit().putLong(c.id, now + 7L * 86_400_000).apply()
    fun parkedAt(ctx: Context): Long? = ctx.getSharedPreferences("parked_spot", 0).getLong("at", 0L).takeIf { it > 0 }
}

private fun tabIcon(id: String): ImageVector = when (id) {
    "camera" -> Icons.Outlined.CameraAlt
    "photos" -> Icons.Outlined.Image
    "files" -> Icons.Outlined.Folder
    "audio" -> Icons.Outlined.GraphicEq
    "words" -> Icons.Outlined.Translate
    "day" -> Icons.Outlined.Event
    "phone" -> Icons.Outlined.PhoneAndroid
    else -> Icons.Outlined.Work
}

/** Icons for routes that aren't in the tool catalog (they open their own screens). */
private fun routeIcon(route: String): ImageVector? = when (route) {
    "wallet" -> Icons.Outlined.CreditCard
    "alarm" -> Icons.Outlined.Alarm
    "timer" -> Icons.Outlined.Timer
    else -> ALL_TOOLS.firstOrNull { it.route == route }?.vicon
}

private fun greeting(): String = when (Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) {
    in 5..11 -> "Good morning"
    in 12..16 -> "Good afternoon"
    else -> "Good evening"
}

/**
 * Home: a greeting, a search box (typing shows every tool that does it), at most one "For you" card, the tabs — all
 * on screen at once — and the chosen tab's tools as tiles named for the job. It fits one screen; nothing scrolls
 * sideways. The Business tab appears only for people who said they run one.
 */
@Composable
fun HomeTabsScreen(onOpen: (String) -> Unit) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences(HomeShelves.PREFS, 0) }
    val business = remember { HomeShelves.businessOn(ctx) }
    val tabs = HomeShelves.tabs(business)
    var tabId by remember { mutableStateOf(prefs.getString(HomeShelves.TAB_KEY, null)?.takeIf { id -> tabs.any { it.id == id } } ?: tabs.first().id) }
    var query by remember { mutableStateOf("") }
    var cards by remember { mutableStateOf(ForYouAndroid.cards(ForYouAndroid.parkedAt(ctx), System.currentTimeMillis(), ForYouAndroid.hidden(ctx),
        com.handytools.app.tools.invoice.InvoiceStore.load(ctx))) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = HandyTokens.Gutter)) {
        Spacer(Modifier.height(HandyTokens.Space8))
        Text(I18n.t(greeting()), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground)
        Spacer(Modifier.height(HandyTokens.Space8))
        TextField(
            value = query, onValueChange = { query = it },
            placeholder = { Text(I18n.t("What do you want to do?")) },
            leadingIcon = { Icon(Icons.Outlined.Search, null, tint = Handy.palette.textSecondary) },
            trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Outlined.Close, I18n.t("Clear")) } },
            singleLine = true, shape = RoundedCornerShape(50),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
            ),
            modifier = Modifier.fillMaxWidth().testTag("home-search"),
        )
        Spacer(Modifier.height(HandyTokens.Space12))

        if (query.isNotBlank()) {
            val results = searchTools(query)
            if (results.isEmpty()) {
                Text(I18n.t("No tool does that yet."), color = Handy.palette.textSecondary, modifier = Modifier.padding(top = HandyTokens.Space24))
            } else {
                LazyColumn(Modifier.fillMaxSize()) {
                    items(results, key = { it.route }) { t -> ResultRow(t) { onOpen(t.route) } }
                }
            }
            return@Column
        }

        cards.forEach { c ->
            ForYouCard(c, onAct = { onOpen(c.route) }, onNotNow = {
                ForYouAndroid.notNow(ctx, c)
                cards = cards - c
            })
            Spacer(Modifier.height(HandyTokens.Space12))
        }

        // Every tab on screen at once: four across.
        val rows = tabs.chunked(4)
        rows.forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                row.forEach { s ->
                    TabChip(s, selected = s.id == tabId, modifier = Modifier.weight(1f)) {
                        tabId = s.id; prefs.edit().putString(HomeShelves.TAB_KEY, s.id).apply()
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
        }
        val shelf = tabs.first { it.id == tabId }
        Text(I18n.t(shelf.line), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space8))

        // The tab's tools as tiles, three across, sized so the whole tab fits what's left of the screen.
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val tiles: List<Triple<String, String, String>> = if (shelf.id == "business")
                HomeShelves.businessJobs.map { Triple("home-job-${it.id}", it.title, it.route) } + Triple("home-job-ask", "What else would help?", "")
            else shelf.tools.map { Triple("home-tool-$it", HomeShelves.jobName(it) ?: it, it) }
            val rowsN = (tiles.size + 2) / 3
            val gap = HandyTokens.Space8
            val fit = (maxHeight - gap * (rowsN - 1).coerceAtLeast(0)) / rowsN.coerceAtLeast(1)
            val h = fit.coerceIn(76.dp, 136.dp)
            val scroll = h * rowsN + gap * (rowsN - 1) > maxHeight
            Column(
                if (scroll) Modifier.fillMaxSize().verticalScroll(rememberScrollState()) else Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(gap),
            ) {
                tiles.chunked(3).forEach { r ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(gap)) {
                        r.forEach { (tag, title, route) ->
                            JobTile(tag, title, route, h, Modifier.weight(1f)) {
                                if (route.isEmpty()) askForMore(ctx) else onOpen(route)
                            }
                        }
                        repeat(3 - r.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

private fun askForMore(ctx: Context) {
    runCatching {
        ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$SUPPORT_EMAIL?subject=" + Uri.encode("Tenzy for my business: an idea")))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

@Composable
private fun TabChip(s: HomeShelves.Shelf, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val accent = MaterialTheme.colorScheme.primary
    Row(
        modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp))
            .background(if (selected) accent.copy(alpha = 0.16f) else MaterialTheme.colorScheme.surface)
            .border(1.dp, if (selected) accent else Handy.palette.border, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick).testTag("tab-${s.id}").padding(horizontal = 6.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
    ) {
        Icon(tabIcon(s.id), null, tint = if (selected) accent else Handy.palette.textSecondary, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(I18n.t(s.title), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
            color = if (selected) accent else MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun JobTile(tag: String, title: String, route: String, height: Dp, modifier: Modifier, onClick: () -> Unit) {
    val iconRes = if (route.isEmpty()) 0 else themedIconRes(route).let { if (it != 0) it else ALL_TOOLS.firstOrNull { t -> t.route == route }?.iconRes ?: 0 }
    Column(
        modifier.height(height).clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Handy.palette.border, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).testTag(tag).semantics { contentDescription = I18n.t(title) }.padding(10.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        when {
            route.isEmpty() -> Icon(Icons.Outlined.Lightbulb, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
            iconRes != 0 -> Image(painterResource(iconRes), null, Modifier.size(30.dp))
            else -> Icon(routeIcon(route) ?: Icons.Outlined.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
        }
        Text(I18n.t(title), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, lineHeight = 16.sp, maxLines = 2,
            overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun ForYouCard(c: ForYouAndroid.Card, onAct: () -> Unit, onNotNow: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Handy.palette.border, RoundedCornerShape(16.dp)).testTag("foryou-${c.kind}")
            .padding(start = 12.dp, top = 10.dp, bottom = 10.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val invoice = c.kind == "invoice"
        Box(Modifier.size(36.dp).background(if (invoice) Color(0xFF0D9488) else Color(0xFF2563EB), RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
            Icon(if (invoice) Icons.Outlined.ReceiptLong else Icons.Outlined.DirectionsCar, null, tint = Color.White, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(I18n.t(c.title), fontWeight = FontWeight.SemiBold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface)
            Text(I18n.t(c.why), fontSize = 12.sp, color = Handy.palette.textSecondary, maxLines = 1)
        }
        Text(I18n.t(c.button), fontWeight = FontWeight.SemiBold, fontSize = 13.sp, color = HandyColors.OnAccent, textAlign = TextAlign.Center,
            modifier = Modifier.clip(RoundedCornerShape(50)).background(MaterialTheme.colorScheme.primary).clickable(onClick = onAct)
                .testTag("foryou-action").heightIn(min = 34.dp).padding(horizontal = 12.dp, vertical = 8.dp))
        IconButton(onClick = onNotNow, modifier = Modifier.testTag("foryou-notnow")) {
            Icon(Icons.Outlined.Close, I18n.t("Not now"), tint = Handy.palette.textSecondary, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun ResultRow(t: HTool, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick).padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val icon = themedIconRes(t.route).let { if (it != 0) it else t.iconRes }
        if (icon != 0) Image(painterResource(icon), null, Modifier.size(36.dp))
        else Icon(t.vicon ?: Icons.Outlined.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(30.dp))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(I18n.t(HomeShelves.jobName(t.route) ?: t.name), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
            Text(I18n.t(t.blurb), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
    }
}

/** Settings › "I run a small business": adds the Business tab to Home (off by default). */
@Composable
fun BusinessSwitchRow() {
    val ctx = LocalContext.current
    var on by remember { mutableStateOf(HomeShelves.businessOn(ctx)) }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable {
            on = !on; HomeShelves.setBusiness(ctx, on)
        }.testTag("settings-business").padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.Work, null, tint = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(I18n.t("I run a small business"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onBackground)
            Text(I18n.t("Adds a Business tab to Home: invoices, expenses, customers and QR codes."),
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        androidx.compose.material3.Switch(checked = on, onCheckedChange = { on = it; HomeShelves.setBusiness(ctx, it) })
    }
}
