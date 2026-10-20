package com.handytools.app.ui

import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.R
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

object Onboarding {
    private const val PREF = "onboarding"
    fun seen(ctx: Context) = ctx.getSharedPreferences(PREF, 0).getBoolean("seen", false)
    fun markSeen(ctx: Context) = ctx.getSharedPreferences(PREF, 0).edit().putBoolean("seen", true).apply()
}

private val ILLOS = listOf(R.drawable.illo_clipboard, R.drawable.illo_alarm, R.drawable.illo_screenshot, R.drawable.illo_flashlight, R.drawable.illo_sticky, R.drawable.illo_qr)

/** Three pages, shown once. Skip on every page. Page 1 is the brand-blue hero with the illustration set cycling. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(startPage: Int = 0, onDone: () -> Unit, onSeePro: () -> Unit) {
    val pager = rememberPagerState(initialPage = startPage) { 3 }
    val scope = rememberCoroutineScope()
    val onBlue = pager.currentPage == 0

    Box(Modifier.fillMaxSize().background(if (onBlue) HandyColors.Accent else MaterialTheme.colorScheme.background)) {
        HorizontalPager(pager, Modifier.fillMaxSize()) { page ->
            when (page) {
                0 -> HeroPage()
                1 -> GridPage()
                else -> ProPage(onSeePro)
            }
        }
        // Skip
        HTextButtonOn(if (onBlue) Color.White else HandyColors.Accent, "Skip", Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(HandyTokens.Space8)) { onDone() }
        // Dots + primary
        Column(Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(horizontal = HandyTokens.Space24, vertical = HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(3) { i ->
                    val active = i == pager.currentPage
                    Box(Modifier.size(if (active) 10.dp else 8.dp).background(
                        if (onBlue) Color.White.copy(alpha = if (active) 1f else 0.4f) else if (active) HandyColors.Accent else Handy.palette.border, CircleShape))
                }
            }
            Spacer(Modifier.height(HandyTokens.Space16))
            val label = when (pager.currentPage) { 0 -> "Show me"; 1 -> "Next"; else -> "Start using Tenzy" }
            if (onBlue) {
                androidx.compose.material3.Button(
                    onClick = { scope.launch { pager.animateScrollToPage(1) } },
                    modifier = Modifier.fillMaxWidth().height(HandyTokens.PrimaryButtonHeight),
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = HandyColors.Accent)
                ) { Text(label, style = MaterialTheme.typography.labelLarge) }
            } else {
                HPrimaryButton(label) { if (pager.currentPage < 2) scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } else onDone() }
            }
        }
    }
}

@Composable
private fun HTextButtonOn(color: Color, text: String, modifier: Modifier, onClick: () -> Unit) {
    androidx.compose.material3.TextButton(onClick = onClick, modifier = modifier) { Text(text, color = color, style = MaterialTheme.typography.labelLarge) }
}

@Composable
private fun HeroPage() {
    var idx by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(2200); idx = (idx + 1) % ILLOS.size } }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(0.6f))
        AnimatedContent(idx, transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(400)) }, label = "illo") { i ->
            Image(painterResource(ILLOS[i]), null, Modifier.size(240.dp))
        }
        Spacer(Modifier.weight(0.5f))
        Text("10 tools your phone forgot.", color = Color.White, fontSize = 34.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.height(HandyTokens.Space12))
        Text("One tap each. Nothing leaves your phone.", color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyLarge,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.weight(1.2f))
    }
}

@Composable
private fun GridPage() {
    var hi by remember { mutableIntStateOf(0) }
    val highlight = listOf(0, 4, 1) // Multi-Clipboard, Alarm Pro, Screenshot+
    LaunchedEffect(Unit) { while (true) { delay(900); hi = (hi + 1) % highlight.size } }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(0.5f))
        // A non-interactive miniature of the real grid, highlighting three cards in sequence
        Column(Modifier.fillMaxWidth(0.82f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            TOOLS.take(6).chunked(2).forEachIndexed { r, pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEachIndexed { c, t ->
                        val i = r * 2 + c
                        val lit = highlight[hi] == i
                        Box(Modifier.weight(1f).height(84.dp).background(if (lit) Handy.palette.accentSoft else MaterialTheme.colorScheme.surface, MaterialTheme.shapes.medium)
                            .padding(12.dp)) {
                            Column(verticalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize()) {
                                androidx.compose.material3.Icon(t.icon, null, Modifier.size(18.dp), tint = HandyColors.Accent)
                                Text(t.name, style = MaterialTheme.typography.labelMedium, maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.weight(0.5f))
        Text("Pick a tool. It explains itself.", style = MaterialTheme.typography.headlineMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.height(HandyTokens.Space12))
        Text("Each one asks for only the permission it needs, when you turn it on.", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.weight(1.2f))
    }
}

@Composable
private fun ProPage(onSeePro: () -> Unit) {
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(0.5f))
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(HandyTokens.Space16)) {
                Row { Spacer(Modifier.weight(1.4f)); Cell("Free", true); Cell("Pro", true, accent = true) }
                listOf("Ads" to ("Yes" to "None"), "Clipboard history" to ("20" to "Unlimited"), "Alarms" to ("3" to "Unlimited"), "Price" to ("Free" to "$19.99 a year")).forEach { (k, v) ->
                    Box(Modifier.fillMaxWidth().height(1.dp).background(Handy.palette.border))
                    Row(Modifier.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(k, Modifier.weight(1.4f), style = MaterialTheme.typography.bodyLarge); Cell(v.first); Cell(v.second, accent = true)
                    }
                }
            }
        }
        Spacer(Modifier.weight(0.5f))
        Text("Free is really free.", style = MaterialTheme.typography.headlineMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.height(HandyTokens.Space12))
        Text("Pro removes ads. That's the whole pitch.", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space8))
        HTextButton("See Pro", onClick = onSeePro)
        Spacer(Modifier.weight(1.2f))
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.Cell(text: String, header: Boolean = false, accent: Boolean = false) {
    Text(text, Modifier.weight(1f), style = if (header) MaterialTheme.typography.labelMedium else MaterialTheme.typography.bodyMedium,
        color = if (accent) HandyColors.Accent else if (header) Handy.palette.textSecondary else MaterialTheme.colorScheme.onSurface,
        fontWeight = if (accent && !header) FontWeight.SemiBold else null)
}
